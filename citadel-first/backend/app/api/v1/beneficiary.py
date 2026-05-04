import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.api.v1.notifications import create_notification
from app.core.database import get_db
from app.models.beneficiary import Beneficiary
from app.models.user import AppUser
from app.models.user_details import UserDetails
from app.schemas.beneficiary import (
    BeneficiaryCreateRequest,
    BeneficiaryUpdateRequest,
    BeneficiaryResponse,
    BeneficiaryListResponse,
    BeneficiaryType,
    RelationshipToSettlor,
)
from app.schemas.user_details import PresignedUrlRequest, PresignedUrlResponse
from app.services.s3_service import generate_presigned_upload_url, build_identity_doc_key

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/signup", tags=["Beneficiaries"])


MAX_PRE_DEMISE = 2
MAX_POST_DEMISE = 5


async def _check_and_notify_beneficiary_status(
    db: AsyncSession, user_id: int,
) -> None:
    """Check beneficiary completion and create appropriate notification."""
    result = await db.execute(
        select(Beneficiary).where(
            Beneficiary.app_user_id == user_id,
            Beneficiary.is_deleted == False,
        )
    )
    all_bens = result.scalars().all()

    pre = [b for b in all_bens if b.beneficiary_type == "pre_demise"]
    post = [b for b in all_bens if b.beneficiary_type == "post_demise"]

    pre_total = sum(float(b.share_percentage or 0) for b in pre)
    post_total = sum(float(b.share_percentage or 0) for b in post)

    pre_complete = len(pre) > 0 and abs(pre_total - 100.0) < 0.01
    post_complete = len(post) > 0 and abs(post_total - 100.0) < 0.01

    if pre_complete and post_complete:
        await create_notification(
            db, user_id,
            title="Beneficiaries Completed",
            message="Your beneficiary details are complete. You can now proceed with trust product placement.",
            notif_type="success",
        )
    elif len(all_bens) > 0 and not (pre_complete and post_complete):
        await create_notification(
            db, user_id,
            title="Beneficiary Update",
            message="Your beneficiary details have been updated. Please review to ensure they're complete.",
            notif_type="info",
        )


@router.post(
    "/beneficiaries",
    response_model=BeneficiaryResponse,
    summary="Create a beneficiary",
    description="Adds a pre-demise or post-demise beneficiary for the current user. "
    f"Max {MAX_PRE_DEMISE} pre-demise and {MAX_POST_DEMISE} post-demise beneficiaries.",
)
async def create_beneficiary(
    body: BeneficiaryCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    max_count = MAX_PRE_DEMISE if body.beneficiary_type == BeneficiaryType.PRE_DEMISE else MAX_POST_DEMISE
    result = await db.execute(
        select(Beneficiary).where(
            Beneficiary.app_user_id == current_user.id,
            Beneficiary.beneficiary_type == body.beneficiary_type.value,
            Beneficiary.is_deleted == False,
        )
    )
    existing = result.scalars().all()
    if len(existing) >= max_count:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Maximum {max_count} {body.beneficiary_type.value} beneficiaries allowed.",
        )

    if body.relationship_to_settlor is not None:
        valid = [r.value for r in RelationshipToSettlor]
        if body.relationship_to_settlor not in valid:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"Invalid relationship. Must be one of: {', '.join(valid)}",
            )

    if body.share_percentage is not None:
        existing_total = sum(float(b.share_percentage or 0) for b in existing)
        if existing_total + float(body.share_percentage) > 100.01:
            remaining = round(100.0 - existing_total, 2)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Share percentage exceeds remaining allocation. Only {remaining}% available.",
            )

    # When same_as_settlor is True, populate personal details from user_details
    full_name = body.full_name
    nric = body.nric
    id_number = body.id_number
    gender = body.gender
    dob = body.dob
    relationship_to_settlor = body.relationship_to_settlor
    residential_address = body.residential_address
    mailing_address = body.mailing_address
    email = body.email
    contact_number = body.contact_number

    if body.same_as_settlor:
        ud_result = await db.execute(
            select(UserDetails).where(UserDetails.app_user_id == current_user.id)
        )
        user_details = ud_result.scalar_one_or_none()
        if user_details:
            full_name = user_details.name
            identity_doc_type = user_details.identity_doc_type
            identity_card_number = user_details.identity_card_number
            if identity_doc_type in ("MYKAD", "MYTENTERA"):
                nric = identity_card_number
            elif identity_doc_type == "PASSPORT":
                id_number = identity_card_number
            else:
                nric = identity_card_number or body.nric
            gender = user_details.gender
            dob = user_details.dob
            relationship_to_settlor = "SELF"
            residential_address = user_details.residential_address
            if user_details.mailing_same_as_residential:
                mailing_address = user_details.residential_address
            else:
                mailing_address = user_details.mailing_address
            email = user_details.email
            contact_number = user_details.mobile_number

    record = Beneficiary(
        app_user_id=current_user.id,
        beneficiary_type=body.beneficiary_type.value,
        same_as_settlor=body.same_as_settlor,
        full_name=full_name,
        nric=nric,
        id_number=id_number,
        gender=gender,
        dob=dob,
        relationship_to_settlor=relationship_to_settlor,
        residential_address=residential_address,
        mailing_address=mailing_address,
        email=email,
        contact_number=contact_number,
        bank_account_name=body.bank_account_name,
        bank_account_number=body.bank_account_number,
        bank_name=body.bank_name,
        bank_swift_code=body.bank_swift_code,
        bank_address=body.bank_address,
        share_percentage=body.share_percentage,
        settlor_nric_key=body.settlor_nric_key,
        proof_of_address_key=body.proof_of_address_key,
        beneficiary_id_key=body.beneficiary_id_key,
        bank_statement_key=body.bank_statement_key,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info(
        "BENEFICIARY_CREATED user_id=%d type=%s name=%s",
        current_user.id,
        record.beneficiary_type,
        record.full_name,
    )
    await _check_and_notify_beneficiary_status(db, current_user.id)
    return BeneficiaryResponse.model_validate(record)


@router.get(
    "/beneficiaries",
    response_model=BeneficiaryListResponse,
    summary="List beneficiaries",
    description="Returns all non-deleted beneficiaries for the current user, grouped by type.",
)
async def list_beneficiaries(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(Beneficiary).where(
            Beneficiary.app_user_id == current_user.id,
            Beneficiary.is_deleted == False,
        ).order_by(Beneficiary.beneficiary_type, Beneficiary.id)
    )
    beneficiaries = result.scalars().all()

    has_pre = any(b.beneficiary_type == "pre_demise" for b in beneficiaries)
    has_post = any(b.beneficiary_type == "post_demise" for b in beneficiaries)

    return BeneficiaryListResponse(
        beneficiaries=[BeneficiaryResponse.model_validate(b) for b in beneficiaries],
        has_pre_demise=has_pre,
        has_post_demise=has_post,
    )


@router.patch(
    "/beneficiaries/{beneficiary_id}",
    response_model=BeneficiaryResponse,
    summary="Update a beneficiary",
    description="Updates fields on an existing beneficiary record.",
)
async def update_beneficiary(
    beneficiary_id: int,
    body: BeneficiaryUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(Beneficiary).where(
            Beneficiary.id == beneficiary_id,
            Beneficiary.app_user_id == current_user.id,
            Beneficiary.is_deleted == False,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Beneficiary not found.",
        )

    update_data = body.model_dump(exclude_unset=True)

    if "share_percentage" in update_data and update_data["share_percentage"] is not None:
        others_result = await db.execute(
            select(Beneficiary).where(
                Beneficiary.app_user_id == current_user.id,
                Beneficiary.beneficiary_type == record.beneficiary_type,
                Beneficiary.is_deleted == False,
                Beneficiary.id != beneficiary_id,
            )
        )
        others = others_result.scalars().all()
        others_total = sum(float(b.share_percentage or 0) for b in others)
        if others_total + float(update_data["share_percentage"]) > 100.01:
            remaining = round(100.0 - others_total, 2)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Share percentage exceeds remaining allocation. Only {remaining}% available.",
            )
    for field, value in update_data.items():
        setattr(record, field, value)

    # If same_as_settlor is being set to True, populate personal details from user_details
    if body.same_as_settlor is True:
        ud_result = await db.execute(
            select(UserDetails).where(UserDetails.app_user_id == current_user.id)
        )
        user_details = ud_result.scalar_one_or_none()
        if user_details:
            record.full_name = user_details.name
            identity_doc_type = user_details.identity_doc_type
            identity_card_number = user_details.identity_card_number
            if identity_doc_type in ("MYKAD", "MYTENTERA"):
                record.nric = identity_card_number
                record.id_number = None
            elif identity_doc_type == "PASSPORT":
                record.id_number = identity_card_number
                record.nric = None
            else:
                record.nric = identity_card_number
            record.gender = user_details.gender
            record.dob = user_details.dob
            record.relationship_to_settlor = "SELF"
            record.residential_address = user_details.residential_address
            if user_details.mailing_same_as_residential:
                record.mailing_address = user_details.residential_address
            else:
                record.mailing_address = user_details.mailing_address
            record.email = user_details.email
            record.contact_number = user_details.mobile_number

    await db.commit()
    await db.refresh(record)

    logger.info("BENEFICIARY_UPDATED user_id=%d beneficiary_id=%d", current_user.id, record.id)
    await _check_and_notify_beneficiary_status(db, current_user.id)
    return BeneficiaryResponse.model_validate(record)


@router.delete(
    "/beneficiaries/{beneficiary_id}",
    summary="Delete a beneficiary",
    description="Soft-deletes a beneficiary record.",
)
async def delete_beneficiary(
    beneficiary_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(Beneficiary).where(
            Beneficiary.id == beneficiary_id,
            Beneficiary.app_user_id == current_user.id,
            Beneficiary.is_deleted == False,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Beneficiary not found.",
        )

    record.is_deleted = True
    await db.commit()

    logger.info("BENEFICIARY_DELETED user_id=%d beneficiary_id=%d", current_user.id, record.id)
    await _check_and_notify_beneficiary_status(db, current_user.id)
    return {"message": "Beneficiary deleted."}


@router.post(
    "/beneficiaries/presigned-url",
    response_model=PresignedUrlResponse,
    summary="Generate presigned URL for beneficiary document upload",
    description="Returns a presigned S3 PUT URL for uploading a beneficiary attachment.",
)
async def beneficiary_presigned_url(
    body: PresignedUrlRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    key = build_identity_doc_key(
        app_user_id=current_user.id,
        doc_type="BENEFICIARY",
        side="front",
        filename=body.filename,
    )
    upload_url = generate_presigned_upload_url(
        key=key,
        content_type=body.content_type,
    )
    logger.info("BENEFICIARY_PRESIGNED_URL user_id=%d key=%s", current_user.id, key)
    return PresignedUrlResponse(upload_url=upload_url, key=key)