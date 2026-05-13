"""Vanguard-facing push endpoints — authenticated via API key.

These endpoints allow Vanguard to push status updates into Citadel.
All endpoints require the X-API-Key header matching VANGUARD_API_KEY.
"""

import logging
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.trust_order import TrustOrder
from app.models.trust_portfolio import TrustPortfolio
from app.schemas.trust_order import (
    TrustOrderUpdateRequest,
    TrustOrderResponse,
)
from app.services.kyc_automation_service import notify_trust_status
from app.services.s3_service import generate_presigned_upload_url

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/vanguard", tags=["Vanguard Push API"])


# ── API Key Authentication ──────────────────────────────────────────────────

async def verify_vanguard_api_key(x_api_key: str = Header(...)) -> str:
    if not settings.VANGUARD_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Vanguard API integration is not configured.",
        )
    if x_api_key != settings.VANGUARD_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key.",
        )
    return x_api_key


# ── 1. Trust Order Status Update ────────────────────────────────────────────

@router.patch(
    "/trust-orders/{order_id}/status",
    response_model=TrustOrderResponse,
    summary="Update trust order status (Vanguard)",
    description="Updates the case_status and related fields of a trust order. "
    "Used by Vanguard to push review results, approval details, or rejection remarks.",
)
async def vanguard_update_trust_order_status(
    order_id: int,
    body: TrustOrderUpdateRequest,
    db: AsyncSession = Depends(get_db),
    _api_key: str = Depends(verify_vanguard_api_key),
):
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.is_deleted == False,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=404, detail="Trust order not found.")

    old_status = record.case_status

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

    # Send notification to user if case_status changed
    if body.case_status is not None and body.case_status != old_status:
        await notify_trust_status(
            db=db,
            app_user_id=record.app_user_id,
            status=body.case_status,
            trust_order_id=order_id,
        )

    # Auto-create portfolio when order is approved
    if body.case_status == "APPROVED" and old_status != "APPROVED":
        existing_portfolio = await db.execute(
            select(TrustPortfolio).where(TrustPortfolio.trust_order_id == order_id)
        )
        if not existing_portfolio.scalar_one_or_none():
            maturity_date = None
            if record.commencement_date:
                from dateutil.relativedelta import relativedelta
                tenure_months = 12
                maturity_date = record.commencement_date + relativedelta(months=tenure_months)

            portfolio = TrustPortfolio(
                app_user_id=record.app_user_id,
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
                "VANGUARD_PORTFOLIO_AUTO_CREATED order_id=%d user_id=%d portfolio_id=%d",
                order_id, record.app_user_id, portfolio.id,
            )

    logger.info(
        "VANGUARD_STATUS_UPDATE order_id=%d case_status=%s->%s",
        order_id, old_status, body.case_status,
    )

    return TrustOrderResponse.model_validate(record)


# ── 2. Presigned Upload URL for Vanguard Documents ───────────────────────────

class VanguardUploadUrlRequest(BaseModel):
    filename: str
    content_type: str = "application/pdf"


class VanguardUploadUrlResponse(BaseModel):
    upload_url: str
    s3_key: str


@router.post(
    "/trust-orders/{order_id}/upload-url",
    response_model=VanguardUploadUrlResponse,
    summary="Get presigned upload URL (Vanguard)",
    description="Returns a presigned S3 URL for Vanguard to upload a document (e.g. "
    "projected yield schedule, acknowledgement receipt). After uploading, push the "
    "returned s3_key via the status endpoint.",
)
async def vanguard_get_upload_url(
    order_id: int,
    body: VanguardUploadUrlRequest,
    db: AsyncSession = Depends(get_db),
    _api_key: str = Depends(verify_vanguard_api_key),
):
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.is_deleted == False,
        )
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Trust order not found.")

    s3_key = f"vanguard-docs/{order_id}/{uuid4().hex}_{body.filename}"
    upload_url = generate_presigned_upload_url(
        key=s3_key,
        content_type=body.content_type,
        expires_in=900,
    )

    logger.info(
        "VANGUARD_UPLOAD_URL order_id=%d s3_key=%s", order_id, s3_key,
    )

    return VanguardUploadUrlResponse(upload_url=upload_url, s3_key=s3_key)


# ── 3. Payment Verification (disabled — enable when ready) ──────────────────

# @router.patch(
#     "/trust-orders/{order_id}/payment-status",
#     summary="Verify or reject payment (Vanguard)",
# )
# async def vanguard_update_payment_status(
#     order_id: int,
#     body: PaymentStatusUpdateRequest,
#     db: AsyncSession = Depends(get_db),
#     _api_key: str = Depends(verify_vanguard_api_key),
# ):
#     ...  # TODO: Enable when payment verification flow is ready


# ── 4. Dividend Recording (disabled — enable when ready) ────────────────────

# @router.post(
#     "/dividends",
#     summary="Record dividend (Vanguard)",
# )
# async def vanguard_create_dividend(
#     body: TrustDividendCreateRequest,
#     db: AsyncSession = Depends(get_db),
#     _api_key: str = Depends(verify_vanguard_api_key),
# ):
#     ...  # TODO: Enable when dividend flow is ready


# ── 5. Dividend Payment Confirmation (disabled — enable when ready) ─────────

# @router.patch(
#     "/dividends/{dividend_id}/status",
#     summary="Mark dividend as paid (Vanguard)",
# )
# async def vanguard_update_dividend_status(
#     dividend_id: int,
#     body: TrustDividendStatusUpdateRequest,
#     db: AsyncSession = Depends(get_db),
#     _api_key: str = Depends(verify_vanguard_api_key),
# ):
#     ...  # TODO: Enable when dividend flow is ready