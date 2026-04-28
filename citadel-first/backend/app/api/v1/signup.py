import asyncio
import base64
import logging
import time
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.config import settings
from app.core.security import decode_token
from app.services.email_service import send_verification_email
from app.models.signup import BankruptcyDeclaration, DisclaimerAcceptance
from app.models.user import AppUser
from app.models.user_details import UserDetails
from app.models.pep_declaration import PepDeclaration
from app.models.crs_tax_residency import CrsTaxResidency
from app.schemas.signup import (
    BankruptcyDeclarationRequest,
    BankruptcyDeclarationResponse,
    DisclaimerAcceptanceRequest,
    DisclaimerAcceptanceResponse,
)
from app.schemas.user_details import (
    DocumentType,
    IdentityDocumentUploadRequest,
    IdentityDocumentUploadResponse,
    OcrRequest,
    OcrResponse,
    OcrResultData,
    PresignedUrlRequest,
    PresignedUrlResponse,
    UserDetailsConfirmRequest,
    UserDetailsResponse,
    PersonalDetailsRequest,
    PersonalDetailsResponse,
    AddressContactRequest,
    AddressContactResponse,
    EmploymentDetailsRequest,
    EmploymentDetailsResponse,
    KycRequest,
    KycResponse,
    OnboardingAgreementRequest,
    OnboardingAgreementResponse,
    SignupUserDetailsResponse,
)
from app.schemas.pep_declaration import (
    PepDeclarationRequest,
    PepDeclarationResponse,
)
from app.schemas.crs_tax_residency import (
    CrsTaxResidencyRequest,
    CrsTaxResidencyResponse,
    CrsTaxResidencyListResponse,
)
from app.services.s3_service import (
    build_identity_doc_key,
    download_object_bytes,
    generate_presigned_upload_url,
    upload_bytes_to_s3,
)
from app.services.pdf_service import generate_onboarding_agreement_pdf
from app.services.ocr_service import run_ocr
from app.services.face_verification_service import compare_faces, detect_face_count
from app.models.face_verification import FaceVerification
from app.schemas.face_verification import (
    SelfiePresignedUrlRequest,
    SelfiePresignedUrlResponse,
    FaceVerifyRequest,
    FaceVerifyResponse,
    FaceDetectRequest,
    FaceDetectResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/signup", tags=["Signup"])

_signup_bearer = HTTPBearer()


async def get_current_signup_user(
    credentials: HTTPAuthorizationCredentials = Depends(_signup_bearer),
    db: AsyncSession = Depends(get_db),
) -> AppUser:
    payload = decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )
    user_id = int(payload["sub"])
    result = await db.execute(
        select(AppUser).where(AppUser.id == user_id, AppUser.is_deleted == 0)
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )
    return user


@router.post(
    "/bankruptcy-declaration",
    response_model=BankruptcyDeclarationResponse,
    summary="Submit bankruptcy declaration",
    description="Records the user's bankruptcy declaration. Must be not bankrupt to proceed.",
)
async def submit_bankruptcy_declaration(
    body: BankruptcyDeclarationRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    declared_at = datetime.now(timezone.utc)
    ip_address = request.client.host if request.client else None

    declaration = BankruptcyDeclaration(
        user_id=current_user.id,
        is_not_bankrupt=body.is_not_bankrupt,
        declared_at=declared_at,
        ip_address=ip_address,
    )
    db.add(declaration)
    await db.commit()
    await db.refresh(declaration)

    logger.info(
        "BANKRUPTCY_DECLARATION user_id=%d is_not_bankrupt=%s declared_at=%s ip=%s",
        current_user.id,
        body.is_not_bankrupt,
        declared_at.isoformat(),
        ip_address,
    )

    if not body.is_not_bankrupt:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not eligible to sign up as a declared bankrupt.",
        )

    return BankruptcyDeclarationResponse(
        id=declaration.id,
        user_id=current_user.id,
        is_not_bankrupt=declaration.is_not_bankrupt,
        declared_at=declaration.declared_at,
        message="Bankruptcy declaration submitted successfully.",
    )


@router.post(
    "/disclaimer-acceptance",
    response_model=DisclaimerAcceptanceResponse,
    summary="Submit disclaimer acceptance",
    description="Records the user's agreement to the platform disclaimer and terms.",
)
async def submit_disclaimer_acceptance(
    body: DisclaimerAcceptanceRequest,
    request: Request,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    agreed_at = datetime.now(timezone.utc)
    ip_address = request.client.host if request.client else None

    acceptance = DisclaimerAcceptance(
        user_id=current_user.id,
        agreed=body.agreed,
        agreed_at=agreed_at,
        ip_address=ip_address,
    )
    db.add(acceptance)
    await db.commit()
    await db.refresh(acceptance)

    logger.info(
        "DISCLAIMER_ACCEPTANCE user_id=%d agreed=%s agreed_at=%s ip=%s",
        current_user.id,
        body.agreed,
        agreed_at.isoformat(),
        ip_address,
    )

    if not body.agreed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You must agree to the disclaimer to proceed with signup.",
        )

    return DisclaimerAcceptanceResponse(
        id=acceptance.id,
        user_id=current_user.id,
        agreed=acceptance.agreed,
        agreed_at=acceptance.agreed_at,
        message="Disclaimer accepted successfully.",
    )


# ── Identity Document Endpoints ───────────────────────────────────────────────


@router.post(
    "/presigned-url",
    response_model=PresignedUrlResponse,
    summary="Generate S3 presigned upload URL",
    description="Returns a presigned S3 PUT URL for the mobile app to upload an image directly.",
)
async def get_presigned_url(
    body: PresignedUrlRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    key = build_identity_doc_key(
        app_user_id=current_user.id,
        doc_type="DOC",
        side="front",
        filename=body.filename,
    )
    upload_url = generate_presigned_upload_url(
        key=key,
        content_type=body.content_type,
    )
    logger.info("PRESIGNED_URL user_id=%d key=%s", current_user.id, key)
    return PresignedUrlResponse(upload_url=upload_url, key=key)


@router.post(
    "/identity-document",
    response_model=IdentityDocumentUploadResponse,
    summary="Submit identity document S3 keys",
    description="Records the S3 keys for uploaded identity document images against the current signup session.",
)
async def upload_identity_document(
    body: IdentityDocumentUploadRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == current_user.id)
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = UserDetails(app_user_id=current_user.id)
        db.add(record)

    record.identity_doc_type = body.doc_type.value
    if body.front_image_key:
        record.identity_card_front_image_key = body.front_image_key
    if body.back_image_key:
        record.identity_card_back_image_key = body.back_image_key

    await db.commit()
    await db.refresh(record)

    logger.info(
        "IDENTITY_DOCUMENT user_id=%d doc_type=%s front=%s back=%s",
        current_user.id,
        body.doc_type.value,
        body.front_image_key,
        body.back_image_key,
    )

    return IdentityDocumentUploadResponse(
        front_image_key=record.identity_card_front_image_key or "",
        back_image_key=record.identity_card_back_image_key,
        message="Identity document keys recorded.",
    )


@router.post(
    "/ocr",
    response_model=OcrResponse,
    summary="Run OCR on an identity document image",
    description="Accepts an S3 image key, downloads the image, runs the appropriate OCR engine, and returns extracted fields.",
)
async def run_ocr_endpoint(
    body: OcrRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    try:
        image_bytes = await asyncio.to_thread(download_object_bytes, body.image_key)
    except Exception as e:
        logger.error("OCR failed to download image %s: %s", body.image_key, e)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to fetch image: {e}")

    try:
        ocr_result = run_ocr(image_bytes=image_bytes, doc_type=body.doc_type.value)
    except Exception as e:
        logger.error("OCR processing failed for %s: %s", body.image_key, e)
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"OCR processing failed: {e}")

    logger.info(
        "OCR completed user_id=%d doc_type=%s name=%s ic=%s confidence=%.2f",
        current_user.id,
        body.doc_type.value,
        ocr_result.full_name,
        ocr_result.identity_number,
        ocr_result.confidence,
    )

    return OcrResponse(
        data=OcrResultData.model_validate(ocr_result, from_attributes=True),
        doc_type=body.doc_type,
    )


@router.patch(
    "/identity-document",
    response_model=UserDetailsResponse,
    summary="Confirm and save identity document details",
    description="Updates user_details with the confirmed (or user-corrected) OCR fields.",
)
async def confirm_identity_document(
    body: UserDetailsConfirmRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == current_user.id)
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = UserDetails(app_user_id=current_user.id)
        db.add(record)

    if body.name is not None:
        record.name = body.name
    if body.identity_card_number is not None:
        record.identity_card_number = body.identity_card_number
    if body.dob is not None:
        record.dob = body.dob
    if body.gender is not None:
        record.gender = body.gender
    if body.nationality is not None:
        record.nationality = body.nationality

    await db.commit()
    await db.refresh(record)

    logger.info(
        "IDENTITY_DOCUMENT_CONFIRMED user_id=%d name=%s ic=%s",
        current_user.id,
        record.name,
        record.identity_card_number,
    )

    return UserDetailsResponse.model_validate(record)


# ── Face Verification (eKYC) Endpoints ──────────────────────────────────────


@router.post(
    "/selfie-presigned-url",
    response_model=SelfiePresignedUrlResponse,
    summary="Generate presigned URL for selfie upload",
    description="Returns a presigned S3 PUT URL for the mobile app to upload a selfie image directly.",
)
async def get_selfie_presigned_url(
    body: SelfiePresignedUrlRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    key = build_identity_doc_key(
        app_user_id=current_user.id,
        doc_type="SELFIE",
        side="front",
        filename=body.filename,
    )
    upload_url = generate_presigned_upload_url(
        key=key,
        content_type=body.content_type,
    )
    logger.info("SELFIE_PRESIGNED_URL user_id=%d key=%s", current_user.id, key)
    return SelfiePresignedUrlResponse(upload_url=upload_url, key=key)


@router.post(
    "/face-detect",
    response_model=FaceDetectResponse,
    summary="Check if a face is present in a selfie image",
    description="Downloads the selfie from S3 and runs MTCNN face detection.",
)
async def detect_face_endpoint(
    body: FaceDetectRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    try:
        image_bytes = await asyncio.to_thread(download_object_bytes, body.selfie_image_key)
    except Exception as e:
        logger.error("Face detect failed to download image %s: %s", body.selfie_image_key, e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to fetch image: {e}",
        )

    try:
        count = await asyncio.to_thread(detect_face_count, image_bytes)
    except Exception as e:
        logger.error("Face detect processing failed for %s: %s", body.selfie_image_key, e)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Face detection failed: {e}",
        )

    detected = count > 0
    message = f"Detected {count} face(s)." if detected else "No face detected in the image."
    return FaceDetectResponse(face_detected=detected, face_count=count, message=message)


@router.post(
    "/face-verify",
    response_model=FaceVerifyResponse,
    summary="Verify selfie face matches ID document face",
    description="Compares a selfie against the front of the identity document using FaceNet. "
    "Downloads both images from S3, extracts face embeddings, computes similarity, "
    "and stores the verification result.",
)
async def verify_face(
    body: FaceVerifyRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Download both images concurrently
    try:
        selfie_bytes, doc_bytes = await asyncio.gather(
            asyncio.to_thread(download_object_bytes, body.selfie_image_key),
            asyncio.to_thread(download_object_bytes, body.doc_image_key),
        )
    except Exception as e:
        logger.error("Face verify failed to download images: %s", e)
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Failed to fetch images: {e}",
        )

    # Run FaceNet comparison
    try:
        result = await asyncio.to_thread(
            compare_faces,
            selfie_bytes,
            doc_bytes,
            settings.FACE_MATCH_THRESHOLD,
        )
    except Exception as e:
        logger.error("Face verification processing failed: %s", e)
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Face verification failed: {e}",
        )

    # Store result in faceid_image_validate table
    verification = FaceVerification(
        app_user_id=current_user.id,
        selfie_image_key=body.selfie_image_key,
        doc_image_key=body.doc_image_key,
        is_match=result.is_match,
        confidence=Decimal(str(round(result.confidence, 4))),
        distance=Decimal(str(round(result.distance, 4))) if result.distance else None,
        selfie_face_detected=result.selfie_face_detected,
        doc_face_detected=result.doc_face_detected,
        threshold_used=Decimal(str(round(settings.FACE_MATCH_THRESHOLD, 4))),
    )
    db.add(verification)

    # Update UserDetails.selfie_image_key
    user_result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == current_user.id)
    )
    record = user_result.scalar_one_or_none()
    if record is None:
        record = UserDetails(app_user_id=current_user.id)
        db.add(record)
    record.selfie_image_key = body.selfie_image_key

    await db.commit()
    await db.refresh(verification)

    # Build response message
    if not result.selfie_face_detected:
        message = "No face detected in the selfie image."
    elif not result.doc_face_detected:
        message = "No face detected in the ID document image."
    elif result.is_match:
        message = "Face verification passed."
    else:
        message = "Face verification failed. The selfie does not match the ID document."

    logger.info(
        "FACE_VERIFY user_id=%d is_match=%s confidence=%.4f selfie_key=%s doc_key=%s",
        current_user.id,
        result.is_match,
        result.confidence,
        body.selfie_image_key,
        body.doc_image_key,
    )

    return FaceVerifyResponse(
        id=verification.id,
        app_user_id=current_user.id,
        is_match=result.is_match,
        confidence=result.confidence,
        distance=result.distance,
        selfie_face_detected=result.selfie_face_detected,
        doc_face_detected=result.doc_face_detected,
        message=message,
    )


# ── Post-eKYC Information Capture Endpoints ─────────────────────────────────────

async def _get_or_create_user_details(
    db: AsyncSession, user_id: int
) -> UserDetails:
    """Get existing UserDetails row or create a new one for the user."""
    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == user_id)
    )
    record = result.scalar_one_or_none()
    if record is None:
        record = UserDetails(app_user_id=user_id)
        db.add(record)
        await db.flush()
    return record


@router.patch(
    "/personal-details",
    response_model=PersonalDetailsResponse,
    summary="Save personal details (title, marital status, passport expiry)",
    description="Updates user_details with personal information after eKYC verification.",
)
async def save_personal_details(
    body: PersonalDetailsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)

    if body.title is not None:
        record.title = body.title
    if body.marital_status is not None:
        record.marital_status = body.marital_status
    if body.passport_expiry is not None:
        record.passport_expiry = body.passport_expiry

    await db.commit()
    await db.refresh(record)

    logger.info(
        "PERSONAL_DETAILS user_id=%d title=%s marital=%s",
        current_user.id,
        record.title,
        record.marital_status,
    )
    return PersonalDetailsResponse.model_validate(record)


@router.patch(
    "/address-contact",
    response_model=AddressContactResponse,
    summary="Save address and contact details",
    description="Updates user_details with residential/mailing address and contact information.",
)
async def save_address_contact(
    body: AddressContactRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)

    if body.residential_address is not None:
        record.residential_address = body.residential_address
    if body.mailing_address is not None:
        record.mailing_address = body.mailing_address
    if body.mailing_same_as_residential is not None:
        record.mailing_same_as_residential = body.mailing_same_as_residential
    if body.home_telephone is not None:
        record.home_telephone = body.home_telephone
    if body.mobile_number is not None:
        record.mobile_number = body.mobile_number
    if body.email is not None:
        record.email = body.email
        # Sync email to app_users if it differs from the login email
        if body.email.lower() != current_user.email_address.lower():
            # Check uniqueness before updating
            existing = await db.execute(
                select(AppUser).where(
                    AppUser.email_address == body.email,
                    AppUser.id != current_user.id,
                )
            )
            if existing.scalars().first() is not None:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="This email is already registered to another account.",
                )
            current_user.email_address = body.email

    await db.commit()
    await db.refresh(record)

    logger.info(
        "ADDRESS_CONTACT user_id=%d email=%s login_email=%s",
        current_user.id,
        record.email,
        current_user.email_address,
    )
    return AddressContactResponse.model_validate(record)


@router.patch(
    "/employment-details",
    response_model=EmploymentDetailsResponse,
    summary="Save employment and financial details",
    description="Updates user_details with employment type, occupation, employer info, and income ranges.",
)
async def save_employment_details(
    body: EmploymentDetailsRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)

    if body.employment_type is not None:
        record.employment_type = body.employment_type
    if body.occupation is not None:
        record.occupation = body.occupation
    if body.work_title is not None:
        record.work_title = body.work_title
    if body.nature_of_business is not None:
        record.nature_of_business = body.nature_of_business
    if body.employer_name is not None:
        record.employer_name = body.employer_name
    if body.employer_address is not None:
        record.employer_address = body.employer_address
    if body.employer_telephone is not None:
        record.employer_telephone = body.employer_telephone
    if body.annual_income_range is not None:
        record.annual_income_range = body.annual_income_range
    if body.estimated_net_worth is not None:
        record.estimated_net_worth = body.estimated_net_worth

    await db.commit()
    await db.refresh(record)

    logger.info(
        "EMPLOYMENT_DETAILS user_id=%d employment_type=%s",
        current_user.id,
        record.employment_type,
    )
    return EmploymentDetailsResponse.model_validate(record)


@router.patch(
    "/kyc-crs",
    response_model=KycResponse,
    summary="Save KYC details",
    description="Updates user_details with KYC information. CRS tax residency rows are saved separately via PUT /signup/crs-tax-residency.",
)
async def save_kyc(
    body: KycRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)

    if body.source_of_trust_fund is not None:
        record.source_of_trust_fund = body.source_of_trust_fund
    if body.source_of_income is not None:
        record.source_of_income = body.source_of_income
    if body.country_of_birth is not None:
        record.country_of_birth = body.country_of_birth
    if body.physically_present is not None:
        record.physically_present = body.physically_present
    if body.main_sources_of_income is not None:
        record.main_sources_of_income = body.main_sources_of_income
    if body.has_unusual_transactions is not None:
        record.has_unusual_transactions = body.has_unusual_transactions
    if body.marital_history is not None:
        record.marital_history = body.marital_history
    if body.geographical_connections is not None:
        record.geographical_connections = body.geographical_connections
    if body.other_relevant_info is not None:
        record.other_relevant_info = body.other_relevant_info

    await db.commit()
    await db.refresh(record)

    logger.info(
        "KYC user_id=%d source_of_trust=%s",
        current_user.id,
        record.source_of_trust_fund,
    )
    return KycResponse.model_validate(record)


@router.put(
    "/crs-tax-residency",
    response_model=CrsTaxResidencyListResponse,
    summary="Replace CRS tax residency rows",
    description="Deletes all existing CRS tax residency rows for the user and creates new ones. Accepts 1-5 jurisdictions.",
)
async def save_crs_tax_residency(
    body: CrsTaxResidencyRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Validate row count
    if len(body.residencies) < 1 or len(body.residencies) > 5:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Must provide between 1 and 5 tax residency jurisdictions.",
        )

    # Validate tin_status rules
    for row in body.residencies:
        if row.tin_status == "have_tin":
            if not row.tin or not row.tin.strip():
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"TIN number is required for jurisdiction '{row.jurisdiction}' when tin_status is 'have_tin'.",
                )
        elif row.tin_status == "no_tin":
            if not row.no_tin_reason:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"A reason for not possessing a TIN is required for jurisdiction '{row.jurisdiction}'.",
                )
            if row.no_tin_reason == "B" and not row.reason_b_explanation:
                raise HTTPException(
                    status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                    detail=f"Reason B explanation is required for jurisdiction '{row.jurisdiction}'.",
                )

    # Delete existing rows
    await db.execute(
        CrsTaxResidency.__table__.delete().where(
            CrsTaxResidency.app_user_id == current_user.id
        )
    )

    # Create new rows
    new_rows = []
    for row in body.residencies:
        record = CrsTaxResidency(
            app_user_id=current_user.id,
            jurisdiction=row.jurisdiction,
            tin_status=row.tin_status,
            tin=row.tin,
            no_tin_reason=row.no_tin_reason,
            reason_b_explanation=row.reason_b_explanation,
        )
        db.add(record)
        new_rows.append(record)

    await db.commit()
    for r in new_rows:
        await db.refresh(r)

    logger.info(
        "CRS_TAX_RESIDENCY user_id=%d rows=%d",
        current_user.id,
        len(new_rows),
    )
    return CrsTaxResidencyListResponse(
        residencies=[CrsTaxResidencyResponse.model_validate(r) for r in new_rows]
    )


@router.patch(
    "/pep-declaration",
    response_model=PepDeclarationResponse,
    summary="Save PEP declaration",
    description="Creates or updates the PEP (Politically Exposed Person) declaration for the current user. Stored in the user_pep_declaration table.",
)
async def save_pep_declaration(
    body: PepDeclarationRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Get existing PEP declaration or prepare a new one
    result = await db.execute(
        select(PepDeclaration).where(PepDeclaration.app_user_id == current_user.id)
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = PepDeclaration(app_user_id=current_user.id, is_pep=body.is_pep)
        db.add(record)
    else:
        record.is_pep = body.is_pep

    if body.is_pep:
        # Update PEP detail fields only when declaring as PEP
        if body.pep_relationship is not None:
            record.pep_relationship = body.pep_relationship
        if body.pep_name is not None:
            record.pep_name = body.pep_name
        if body.pep_position is not None:
            record.pep_position = body.pep_position
        if body.pep_organisation is not None:
            record.pep_organisation = body.pep_organisation
        if body.pep_supporting_doc_key is not None:
            record.pep_supporting_doc_key = body.pep_supporting_doc_key
    else:
        # If not PEP, clear all PEP-related fields
        record.pep_relationship = None
        record.pep_name = None
        record.pep_position = None
        record.pep_organisation = None
        record.pep_supporting_doc_key = None

    await db.commit()
    await db.refresh(record)

    logger.info(
        "PEP_DECLARATION user_id=%d is_pep=%s relationship=%s",
        current_user.id,
        record.is_pep,
        record.pep_relationship,
    )
    return PepDeclarationResponse.model_validate(record)


# ── Onboarding Agreement (E-Sign) Endpoints ────────────────────────────────────


@router.get(
    "/user-details",
    response_model=SignupUserDetailsResponse,
    summary="Get current user's name and identity card number",
    description="Returns the user's name and IC number from user_details for auto-populating the onboarding agreement.",
)
async def get_signup_user_details(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)
    return SignupUserDetailsResponse.model_validate(record)


@router.patch(
    "/onboarding-agreement",
    response_model=OnboardingAgreementResponse,
    summary="Sign and store onboarding agreement",
    description="Accepts a base64-encoded signature, uploads the signature image and generated "
    "agreement PDF to S3, and stores both S3 keys in user_details.",
)
async def sign_onboarding_agreement(
    body: OnboardingAgreementRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = await _get_or_create_user_details(db, current_user.id)

    ts = int(time.time())
    sig_key = f"signatures/{current_user.id}/{ts}_signature.png"
    pdf_key = f"agreements/{current_user.id}/{ts}_onboarding_agreement.pdf"

    # Decode and upload signature image
    try:
        sig_bytes = base64.b64decode(body.signature_base64)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Invalid base64 signature data.",
        )

    await asyncio.to_thread(
        upload_bytes_to_s3, sig_key, sig_bytes, "image/png"
    )

    # Generate agreement PDF with embedded signature
    date_str = datetime.now(timezone.utc).strftime("%d %B %Y")
    try:
        pdf_bytes = await asyncio.to_thread(
            generate_onboarding_agreement_pdf,
            body.full_name,
            body.ic_number,
            date_str,
            body.signature_base64,
        )
    except RuntimeError as e:
        logger.error("PDF generation failed for user_id=%d: %s", current_user.id, e)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to generate onboarding agreement PDF.",
        )

    # Upload PDF to S3
    await asyncio.to_thread(
        upload_bytes_to_s3, pdf_key, pdf_bytes, "application/pdf"
    )

    # Store both S3 keys
    record.digital_signature_key = sig_key
    record.onboarding_agreement_key = pdf_key

    # Mark signup as complete
    current_user.signup_completed_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(record)

    # Send verification email now that signup is complete
    if current_user.email_verification_token and current_user.email_verified_at is None:
        try:
            await send_verification_email(
                current_user.email_address, current_user.email_verification_token
            )
            logger.info("Verification email sent to %s", current_user.email_address)
        except Exception:
            logger.exception("Failed to send verification email to %s", current_user.email_address)

    logger.info(
        "ONBOARDING_AGREEMENT user_id=%d sig_key=%s pdf_key=%s",
        current_user.id,
        sig_key,
        pdf_key,
    )

    return OnboardingAgreementResponse(
        id=record.id,
        app_user_id=current_user.id,
        digital_signature_key=record.digital_signature_key,
        onboarding_agreement_key=record.onboarding_agreement_key,
        message="Onboarding agreement signed successfully.",
    )