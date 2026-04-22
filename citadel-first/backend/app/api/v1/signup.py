import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.responses import Response
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.signup import BankruptcyDeclaration, DisclaimerAcceptance, TrustFormB6
from app.models.user_details import UserDetails
from app.schemas.signup import (
    BankruptcyDeclarationRequest,
    BankruptcyDeclarationResponse,
    DisclaimerAcceptanceRequest,
    DisclaimerAcceptanceResponse,
    TrustFormB6Request,
    TrustFormB6Response,
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
from app.services.pdf_service import generate_b6_pdf
from app.services.s3_service import build_identity_doc_key, generate_presigned_download_url, generate_presigned_upload_url
from app.services.ocr_service import run_ocr

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/signup", tags=["Signup"])

# Signup endpoints are public — no JWT required during the onboarding flow.
_ANON_USER_ID = 0


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
):
    declared_at = datetime.now(timezone.utc)
    ip_address = request.client.host if request.client else None

    declaration = BankruptcyDeclaration(
        user_id=_ANON_USER_ID,
        is_not_bankrupt=body.is_not_bankrupt,
        declared_at=declared_at,
        ip_address=ip_address,
    )
    db.add(declaration)
    await db.commit()
    await db.refresh(declaration)

    logger.info(
        "BANKRUPTCY_DECLARATION is_not_bankrupt=%s declared_at=%s ip=%s",
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
        user_id=_ANON_USER_ID,
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
):
    agreed_at = datetime.now(timezone.utc)
    ip_address = request.client.host if request.client else None

    acceptance = DisclaimerAcceptance(
        user_id=_ANON_USER_ID,
        agreed=body.agreed,
        agreed_at=agreed_at,
        ip_address=ip_address,
    )
    db.add(acceptance)
    await db.commit()
    await db.refresh(acceptance)

    logger.info(
        "DISCLAIMER_ACCEPTANCE agreed=%s agreed_at=%s ip=%s",
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
        user_id=_ANON_USER_ID,
        agreed=acceptance.agreed,
        agreed_at=acceptance.agreed_at,
        message="Disclaimer accepted successfully.",
    )


@router.post(
    "/trust-form-b6",
    response_model=TrustFormB6Response,
    summary="Submit B6 Asset Allocation Direction Form",
    description=(
        "Records trust information and B6 form details, generates a populated PDF, "
        "and stores it in the database for review."
    ),
)
async def submit_trust_form_b6(
    body: TrustFormB6Request,
    db: AsyncSession = Depends(get_db),
):
    pdf_bytes = generate_b6_pdf(
        trust_deed_date=body.trust_deed_date,
        trust_asset_amount=body.trust_asset_amount,
        advisor_name=body.advisor_name,
        advisor_nric=body.advisor_nric,
    )

    record = TrustFormB6(
        user_id=_ANON_USER_ID,
        trust_deed_date=body.trust_deed_date,
        trust_asset_amount=body.trust_asset_amount,
        advisor_name=body.advisor_name,
        advisor_nric=body.advisor_nric,
        pdf_data=pdf_bytes,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info(
        "TRUST_FORM_B6 record_id=%d advisor=%s deed_date=%s",
        record.id,
        body.advisor_name,
        body.trust_deed_date.isoformat(),
    )

    return TrustFormB6Response(
        id=record.id,
        user_id=_ANON_USER_ID,
        trust_deed_date=record.trust_deed_date,
        trust_asset_amount=record.trust_asset_amount,
        advisor_name=record.advisor_name,
        advisor_nric=record.advisor_nric,
        created_at=record.created_at,
        message="B6 form submitted successfully. PDF generated and stored for review.",
    )


@router.get(
    "/trust-form-b6/{record_id}/pdf",
    summary="Retrieve B6 form PDF",
    description="Returns the stored B6 Asset Allocation Direction Form PDF for the given record.",
)
async def get_trust_form_b6_pdf(
    record_id: int,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(TrustFormB6).where(TrustFormB6.id == record_id)
    )
    record = result.scalar_one_or_none()

    if record is None or record.pdf_data is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PDF not found.")

    logger.info("TRUST_FORM_B6_PDF_FETCH record_id=%d", record_id)

    return Response(
        content=bytes(record.pdf_data),
        media_type="application/pdf",
        headers={"Content-Disposition": f"inline; filename=b6_form_{record_id}.pdf"},
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
):
    # Build key: identity-docs/{user_id}/{filename}
    # For anonymous signup flow we use _ANON_USER_ID as placeholder
    key = build_identity_doc_key(
        app_user_id=_ANON_USER_ID,
        doc_type="DOC",
        side="front",
        filename=body.filename,
    )
    upload_url = generate_presigned_upload_url(
        key=key,
        content_type=body.content_type,
    )
    logger.info("PRESIGNED_URL generated key=%s", key)
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
):
    # Upsert user_details record
    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == _ANON_USER_ID)
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = UserDetails(app_user_id=_ANON_USER_ID)
        db.add(record)

    record.identity_doc_type = body.doc_type.value
    if body.front_image_key:
        record.identity_card_front_image_key = body.front_image_key
    if body.back_image_key:
        record.identity_card_back_image_key = body.back_image_key

    await db.commit()
    await db.refresh(record)

    logger.info(
        "IDENTITY_DOCUMENT uploaded doc_type=%s front=%s back=%s",
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
):
    # Download image from S3
    try:
        import boto3
        from app.core.config import settings

        s3_client = boto3.client(
            "s3",
            aws_access_key_id=settings.AWS_ACCESS_KEY_ID,
            aws_secret_access_key=settings.AWS_SECRET_ACCESS_KEY,
            region_name=settings.AWS_REGION,
            endpoint_url=settings.AWS_ENDPOINT or None,
        )
        response = s3_client.get_object(Bucket=settings.AWS_S3_BUCKET, Key=body.image_key)
        image_bytes = response["Body"].read()
    except Exception as e:
        logger.error("OCR failed to download image %s: %s", body.image_key, e)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Failed to fetch image: {e}")

    # Run OCR
    try:
        ocr_result = run_ocr(image_bytes=image_bytes, doc_type=body.doc_type.value)
    except Exception as e:
        logger.error("OCR processing failed for %s: %s", body.image_key, e)
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=f"OCR processing failed: {e}")

    logger.info(
        "OCR completed doc_type=%s name=%s ic=%s confidence=%.2f",
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
):
    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == _ANON_USER_ID)
    )
    record = result.scalar_one_or_none()

    if record is None:
        record = UserDetails(app_user_id=_ANON_USER_ID)
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
        _ANON_USER_ID,
        record.name,
        record.identity_card_number,
    )

    return UserDetailsResponse.model_validate(record)
