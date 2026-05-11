import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.bank_details import BankDetails
from app.models.user import AppUser
from app.schemas.bank_details import (
    BankDetailsCreateRequest,
    BankDetailsListResponse,
    BankDetailsProofUploadRequest,
    BankDetailsResponse,
    BankDetailsUpdateRequest,
)
from app.schemas.user_details import PresignedUrlResponse
from app.services.s3_service import generate_presigned_upload_url, generate_presigned_download_url

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/bank-details", tags=["Bank Details"])


@router.post(
    "",
    response_model=BankDetailsResponse,
    summary="Create a bank account",
    description="Adds a new bank account for the current user.",
)
async def create_bank_details(
    body: BankDetailsCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = BankDetails(
        app_user_id=current_user.id,
        bank_name=body.bank_name,
        account_holder_name=body.account_holder_name,
        account_number=body.account_number,
        bank_address=body.bank_address,
        postcode=body.postcode,
        city=body.city,
        state=body.state,
        country=body.country,
        swift_code=body.swift_code,
        bank_account_proof_key=body.bank_account_proof_key,
        is_deleted=0,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info("BANK_DETAILS_CREATED user_id=%d bank_id=%d", current_user.id, record.id)

    return BankDetailsResponse.model_validate(record)


@router.get(
    "/me",
    response_model=BankDetailsListResponse,
    summary="List my bank accounts",
    description="Returns all non-deleted bank accounts for the current user.",
)
async def list_my_bank_details(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(BankDetails)
        .where(
            BankDetails.app_user_id == current_user.id,
            BankDetails.is_deleted == 0,
        )
        .order_by(BankDetails.created_at.desc())
    )
    banks = result.scalars().all()
    return BankDetailsListResponse(banks=[BankDetailsResponse.model_validate(b) for b in banks])


@router.post(
    "/proof-upload-url",
    response_model=PresignedUrlResponse,
    summary="Generate presigned URL for bank account proof upload",
    description="Returns a presigned S3 URL to upload a bank account proof document.",
)
async def get_bank_proof_upload_url(
    body: BankDetailsProofUploadRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    key = f"bank-proofs/{current_user.id}/{body.file_name}"
    upload_url = generate_presigned_upload_url(key=key, content_type=body.content_type)

    logger.info("BANK_PROOF_UPLOAD_URL user_id=%d key=%s", current_user.id, key)

    return PresignedUrlResponse(upload_url=upload_url, key=key)


@router.get(
    "/{bank_id}/proof-download-url",
    response_model=PresignedUrlResponse,
    summary="Get presigned download URL for bank account proof",
    description="Returns a presigned S3 URL to download a bank account proof document.",
)
async def get_bank_proof_download_url(
    bank_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(BankDetails).where(
            BankDetails.id == bank_id,
            BankDetails.app_user_id == current_user.id,
            BankDetails.is_deleted == 0,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found.")

    if not record.bank_account_proof_key:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No proof document uploaded for this bank account.")

    download_url = generate_presigned_download_url(key=record.bank_account_proof_key, expires_in=300)

    return PresignedUrlResponse(upload_url=download_url, key=record.bank_account_proof_key)


@router.patch(
    "/{bank_id}",
    response_model=BankDetailsResponse,
    summary="Update a bank account",
    description="Updates a bank account. Only non-deleted accounts can be updated.",
)
async def update_bank_details(
    bank_id: int,
    body: BankDetailsUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(BankDetails).where(
            BankDetails.id == bank_id,
            BankDetails.app_user_id == current_user.id,
            BankDetails.is_deleted == 0,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found.")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None:
            setattr(record, field, value)

    await db.commit()
    await db.refresh(record)

    logger.info("BANK_DETAILS_UPDATED bank_id=%d user_id=%d", bank_id, current_user.id)

    return BankDetailsResponse.model_validate(record)


@router.delete(
    "/{bank_id}",
    summary="Soft delete a bank account",
    description="Marks a bank account as deleted.",
)
async def delete_bank_details(
    bank_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(BankDetails).where(
            BankDetails.id == bank_id,
            BankDetails.app_user_id == current_user.id,
            BankDetails.is_deleted == 0,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found.")

    record.is_deleted = 1
    await db.commit()

    logger.info("BANK_DETAILS_DELETED bank_id=%d user_id=%d", bank_id, current_user.id)

    return {"message": "Bank account deleted successfully."}