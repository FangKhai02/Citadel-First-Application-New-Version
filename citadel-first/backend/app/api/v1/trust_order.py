import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.trust_order import TrustOrder
from app.models.trust_portfolio import TrustPortfolio
from app.models.user import AppUser
from app.schemas.trust_order import (
    PaymentStatusUpdateRequest,
    TrustOrderCreateRequest,
    TrustOrderListResponse,
    TrustOrderResponse,
    TrustOrderUpdateRequest,
)
from app.schemas.user_details import PresignedUrlRequest, PresignedUrlResponse
from app.services.s3_service import generate_presigned_download_url, generate_presigned_upload_url
from app.services.kyc_automation_service import generate_and_email_kyc_forms, notify_trust_status

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/trust-orders", tags=["Trust Orders"])

CWD_DECK_S3_KEY = "trust-products/cwd-trust-deck.pdf"


@router.post(
    "",
    response_model=TrustOrderResponse,
    summary="Create a trust order",
    description="Submits a trust product purchase application.",
)
async def create_trust_order(
    body: TrustOrderCreateRequest,
    background_tasks: BackgroundTasks,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    record = TrustOrder(
        app_user_id=current_user.id,
        date_of_trust_deed=body.date_of_trust_deed,
        trust_asset_amount=body.trust_asset_amount,
        advisor_name=body.advisor_name,
        advisor_nric=body.advisor_nric,
        projected_yield_schedule_key=body.projected_yield_schedule_key,
        acknowledgement_receipt_key=body.acknowledgement_receipt_key,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info(
        "TRUST_ORDER_CREATED user_id=%d order_id=%d",
        current_user.id,
        record.id,
    )

    # Schedule KYC form generation and email as a background task
    background_tasks.add_task(
        generate_and_email_kyc_forms,
        app_user_id=current_user.id,
        trust_order_id=record.id,
    )

    return TrustOrderResponse.model_validate(record)


@router.get(
    "/me",
    response_model=TrustOrderListResponse,
    summary="List my trust orders",
    description="Returns all non-deleted trust orders for the current user.",
)
async def list_my_trust_orders(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustOrder)
        .where(
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
        .order_by(TrustOrder.id.desc())
    )
    orders = result.scalars().all()
    return TrustOrderListResponse(
        orders=[TrustOrderResponse.model_validate(o) for o in orders],
    )


@router.get(
    "/{order_id}",
    response_model=TrustOrderResponse,
    summary="Get a trust order",
    description="Returns a single trust order by ID.",
)
async def get_trust_order(
    order_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")
    return TrustOrderResponse.model_validate(record)


@router.post(
    "/presigned-url",
    response_model=PresignedUrlResponse,
    summary="Generate presigned URL for trust order attachment upload",
)
async def trust_order_presigned_url(
    body: PresignedUrlRequest,
    current_user: AppUser = Depends(get_current_signup_user),
):
    key = f"trust-orders/{current_user.id}/{body.filename}"
    upload_url = generate_presigned_upload_url(key=key, content_type=body.content_type)
    logger.info("TRUST_ORDER_PRESIGNED_URL user_id=%d key=%s", current_user.id, key)
    return PresignedUrlResponse(upload_url=upload_url, key=key)


@router.get(
    "/products/cwd-deck-url",
    summary="Get CWD Trust Deck PDF download URL",
    description="Returns a presigned S3 URL to download the CWD Trust Presentation Deck PDF.",
)
async def get_cwd_deck_url(
    current_user: AppUser = Depends(get_current_signup_user),
):
    download_url = generate_presigned_download_url(key=CWD_DECK_S3_KEY, expires_in=600)
    return {"download_url": download_url}


@router.patch(
    "/{order_id}/status",
    response_model=TrustOrderResponse,
    summary="Update trust order status",
    description="Updates the case_status of a trust order and notifies the user. Used by Vanguard vendor to push status updates.",
)
async def update_trust_order_status(
    order_id: int,
    body: TrustOrderUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    old_status = record.case_status

    # Apply updates
    if body.case_status is not None:
        record.case_status = body.case_status
    if body.kyc_status is not None:
        record.kyc_status = body.kyc_status
    if body.trust_reference_id is not None:
        record.trust_reference_id = body.trust_reference_id
    if body.deferment_remark is not None:
        record.deferment_remark = body.deferment_remark
    if body.advisor_code is not None:
        record.advisor_code = body.advisor_code
    if body.commencement_date is not None:
        record.commencement_date = body.commencement_date
    if body.trust_period_ending_date is not None:
        record.trust_period_ending_date = body.trust_period_ending_date
    if body.irrevocable_termination_notice_date is not None:
        record.irrevocable_termination_notice_date = body.irrevocable_termination_notice_date
    if body.auto_renewal_date is not None:
        record.auto_renewal_date = body.auto_renewal_date

    await db.commit()
    await db.refresh(record)

    # If case_status changed, send notification to user
    if body.case_status is not None and body.case_status != old_status:
        await notify_trust_status(
            db=db,
            app_user_id=current_user.id,
            status=body.case_status,
            trust_order_id=order_id,
        )

    # Auto-create portfolio when order is approved
    if body.case_status == "APPROVED" and old_status != "APPROVED":
        existing_portfolio = await db.execute(
            select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
        )
        if not existing_portfolio.scalar_one_or_none():
            # Calculate maturity date from commencement + tenure if available
            maturity_date = None
            if record.commencement_date:
                from dateutil.relativedelta import relativedelta
                # Default tenure of 12 months if not specified
                tenure_months = 12
                maturity_date = record.commencement_date + relativedelta(months=tenure_months)

            portfolio = TrustPortfolio(
                app_user_id=current_user.id,
                trust_order_id=order_id,
                product_name="CWD Trust",
                product_code="CWD",
                status="PENDING_PAYMENT",
                payment_status="PENDING",
            )
            if maturity_date:
                portfolio.maturity_date = maturity_date
            db.add(portfolio)
            await db.commit()
            logger.info(
                "PORTFOLIO_AUTO_CREATED order_id=%d user_id=%d portfolio_id=%d",
                order_id,
                current_user.id,
                portfolio.id,
            )

    return TrustOrderResponse.model_validate(record)


@router.patch(
    "/{order_id}/payment-status",
    summary="Update payment status",
    description="Updates the payment_status of the portfolio linked to this order. Used by Vanguard to verify or reject payment. When payment_status is set to SUCCESS, the portfolio status automatically changes to ACTIVE.",
)
async def update_payment_status(
    order_id: int,
    body: PaymentStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order exists and belongs to the user
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Find the portfolio for this order
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No portfolio found for this trust order.",
        )

    new_status = body.payment_status.upper()
    if new_status not in ("SUCCESS", "FAILED"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="payment_status must be SUCCESS or FAILED.",
        )

    portfolio.payment_status = new_status

    # When payment is verified, activate the portfolio
    if new_status == "SUCCESS":
        portfolio.status = "ACTIVE"

    await db.commit()
    await db.refresh(portfolio)

    logger.info(
        "PAYMENT_STATUS_UPDATED order_id=%d portfolio_id=%d payment_status=%s status=%s",
        order_id, portfolio.id, new_status, portfolio.status,
    )

    return {
        "message": f"Payment status updated to {new_status}.",
        "payment_status": new_status,
        "portfolio_status": portfolio.status,
    }