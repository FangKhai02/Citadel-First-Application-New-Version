import logging
import random
import time

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.trust_dividend_history import TrustDividendHistory
from app.models.trust_portfolio import TrustPortfolio
from app.models.user import AppUser
from app.schemas.trust_dividend import (
    TrustDividendCreateRequest,
    TrustDividendListResponse,
    TrustDividendResponse,
    TrustDividendStatusUpdateRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/dividends", tags=["Dividends"])


@router.post(
    "",
    response_model=TrustDividendResponse,
    summary="Create a dividend record",
    description="Creates a dividend payout record for a portfolio. Used by admin or Vanguard to record dividend payments.",
)
async def create_dividend(
    body: TrustDividendCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify portfolio exists
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.id == body.trust_portfolio_id)
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    # Generate reference number
    ref_number = f"DIV{int(time.time() * 1000)}{random.randint(100, 999)}"

    record = TrustDividendHistory(
        trust_portfolio_id=body.trust_portfolio_id,
        reference_number=ref_number,
        dividend_amount=body.dividend_amount,
        trustee_fee_amount=body.trustee_fee_amount,
        period_starting_date=body.period_starting_date,
        period_ending_date=body.period_ending_date,
        dividend_quarter=body.dividend_quarter,
        payment_status="PENDING",
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)

    logger.info(
        "DIVIDEND_CREATED portfolio_id=%d dividend_id=%d ref=%s amount=%s",
        body.trust_portfolio_id,
        record.id,
        ref_number,
        str(body.dividend_amount),
    )

    return TrustDividendResponse.model_validate(record)


@router.get(
    "/portfolio/{portfolio_id}",
    response_model=TrustDividendListResponse,
    summary="List dividends for a portfolio",
    description="Returns all dividend records for a specific portfolio.",
)
async def list_portfolio_dividends(
    portfolio_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify portfolio belongs to user
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = portfolio_result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    result = await db.execute(
        select(TrustDividendHistory)
        .where(TrustDividendHistory.trust_portfolio_id == portfolio_id)
        .order_by(TrustDividendHistory.dividend_quarter.desc())
    )
    dividends = result.scalars().all()

    return TrustDividendListResponse(
        dividends=[TrustDividendResponse.model_validate(d) for d in dividends]
    )


@router.patch(
    "/{dividend_id}/status",
    response_model=TrustDividendResponse,
    summary="Update dividend payment status",
    description="Updates the payment status of a dividend record. Used by admin to mark dividends as PAID.",
)
async def update_dividend_status(
    dividend_id: int,
    body: TrustDividendStatusUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustDividendHistory).where(TrustDividendHistory.id == dividend_id)
    )
    record = result.scalar_one_or_none()
    if not record:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dividend record not found.")

    record.payment_status = body.payment_status.value
    if body.payment_date:
        record.payment_date = body.payment_date
    elif body.payment_status.value == "PAID":
        from datetime import date as date_type
        record.payment_date = date_type.today()

    await db.commit()
    await db.refresh(record)

    logger.info("DIVIDEND_STATUS_UPDATED dividend_id=%d status=%s", dividend_id, body.payment_status.value)

    return TrustDividendResponse.model_validate(record)