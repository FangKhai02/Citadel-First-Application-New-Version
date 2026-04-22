import asyncio
import logging
from datetime import datetime, timezone
from decimal import Decimal

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.config import settings
from app.core.security import decode_token
from app.models.signup import BankruptcyDeclaration, DisclaimerAcceptance
from app.models.user import AppUser
from app.models.user_details import UserDetails
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
)
from app.services.s3_service import build_identity_doc_key, download_object_bytes, generate_presigned_upload_url
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