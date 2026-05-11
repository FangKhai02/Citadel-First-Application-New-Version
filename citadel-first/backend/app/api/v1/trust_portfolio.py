import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.trust_order import TrustOrder
from app.models.trust_portfolio import TrustPortfolio
from app.models.bank_details import BankDetails
from app.models.user import AppUser
from app.schemas.trust_portfolio import (
    LinkBankRequest,
    PortfolioStatus,
    TrustPortfolioCreateRequest,
    TrustPortfolioDetailResponse,
    TrustPortfolioListResponse,
    TrustPortfolioResponse,
    TrustPortfolioUpdateRequest,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/portfolios", tags=["Trust Portfolios"])


@router.get(
    "/me",
    response_model=TrustPortfolioListResponse,
    summary="List my portfolios",
    description="Returns all portfolios for the current user with enriched order and bank details.",
)
async def list_my_portfolios(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustPortfolio)
        .where(
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
        .order_by(TrustPortfolio.created_at.desc())
    )
    portfolios = result.scalars().all()

    items = []
    for p in portfolios:
        order = None
        bank = None

        if p.trust_order_id:
            order_result = await db.execute(
                select(TrustOrder).where(TrustOrder.id == p.trust_order_id)
            )
            order = order_result.scalar_one_or_none()

        if p.bank_details_id:
            bank_result = await db.execute(
                select(BankDetails).where(BankDetails.id == p.bank_details_id)
            )
            bank = bank_result.scalar_one_or_none()

        items.append(
            TrustPortfolioDetailResponse(
                portfolio=TrustPortfolioResponse.model_validate(p),
                trust_asset_amount=order.trust_asset_amount if order else None,
                trust_reference_id=order.trust_reference_id if order else None,
                case_status=order.case_status if order else None,
                commencement_date=order.commencement_date if order else None,
                trust_period_ending_date=order.trust_period_ending_date if order else None,
                advisor_name=order.advisor_name if order else None,
                advisor_code=order.advisor_code if order else None,
                bank_name=bank.bank_name if bank else None,
                bank_account_holder_name=bank.account_holder_name if bank else None,
                bank_account_number=bank.account_number if bank else None,
                bank_swift_code=bank.swift_code if bank else None,
            )
        )

    return TrustPortfolioListResponse(portfolios=items)


@router.get(
    "/{portfolio_id}",
    response_model=TrustPortfolioDetailResponse,
    summary="Get portfolio detail",
    description="Returns a single portfolio with enriched order and bank details.",
)
async def get_portfolio_detail(
    portfolio_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    order = None
    bank = None

    if portfolio.trust_order_id:
        order_result = await db.execute(
            select(TrustOrder).where(TrustOrder.id == portfolio.trust_order_id)
        )
        order = order_result.scalar_one_or_none()

    if portfolio.bank_details_id:
        bank_result = await db.execute(
            select(BankDetails).where(BankDetails.id == portfolio.bank_details_id)
        )
        bank = bank_result.scalar_one_or_none()

    return TrustPortfolioDetailResponse(
        portfolio=TrustPortfolioResponse.model_validate(portfolio),
        trust_asset_amount=order.trust_asset_amount if order else None,
        trust_reference_id=order.trust_reference_id if order else None,
        case_status=order.case_status if order else None,
        commencement_date=order.commencement_date if order else None,
        trust_period_ending_date=order.trust_period_ending_date if order else None,
        advisor_name=order.advisor_name if order else None,
        advisor_code=order.advisor_code if order else None,
        bank_name=bank.bank_name if bank else None,
        bank_account_holder_name=bank.account_holder_name if bank else None,
        bank_account_number=bank.account_number if bank else None,
        bank_swift_code=bank.swift_code if bank else None,
    )


@router.post(
    "",
    response_model=TrustPortfolioResponse,
    summary="Create a portfolio",
    description="Creates a trust portfolio. Typically called automatically when a trust order is approved, but can also be called directly by admin.",
)
async def create_portfolio(
    body: TrustPortfolioCreateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify the trust order exists and belongs to the user
    order_result = await db.execute(
        select(TrustOrder).where(TrustOrder.id == body.trust_order_id)
    )
    order = order_result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Trust order not found.")

    # Check if portfolio already exists for this order
    existing = await db.execute(
        select(TrustPortfolio).where(TrustPortfolio.trust_order_id == body.trust_order_id)
    )
    if existing.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Portfolio already exists for this trust order.",
        )

    # Calculate maturity date if not provided
    maturity_date = body.maturity_date
    if not maturity_date and order.commencement_date and body.investment_tenure_months:
        from dateutil.relativedelta import relativedelta
        maturity_date = order.commencement_date + relativedelta(months=body.investment_tenure_months)

    portfolio = TrustPortfolio(
        app_user_id=order.app_user_id,
        trust_order_id=body.trust_order_id,
        product_name=body.product_name,
        product_code=body.product_code,
        dividend_rate=body.dividend_rate,
        investment_tenure_months=body.investment_tenure_months,
        maturity_date=maturity_date,
        payout_frequency=body.payout_frequency.value if hasattr(body.payout_frequency, 'value') else body.payout_frequency,
        is_prorated=body.is_prorated,
        status=PortfolioStatus.PENDING_PAYMENT.value,
        payment_status="PENDING",
    )
    db.add(portfolio)
    await db.commit()
    await db.refresh(portfolio)

    logger.info(
        "PORTFOLIO_CREATED user_id=%d order_id=%d portfolio_id=%d",
        order.app_user_id,
        body.trust_order_id,
        portfolio.id,
    )

    return TrustPortfolioResponse.model_validate(portfolio)


@router.patch(
    "/{portfolio_id}",
    response_model=TrustPortfolioResponse,
    summary="Update a portfolio",
    description="Updates portfolio fields such as status, payment info, and agreement status.",
)
async def update_portfolio(
    portfolio_id: int,
    body: TrustPortfolioUpdateRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    update_data = body.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if value is not None:
            # Convert enums to their string values
            if hasattr(value, "value"):
                value = value.value
            setattr(portfolio, field, value)

    await db.commit()
    await db.refresh(portfolio)

    logger.info("PORTFOLIO_UPDATED portfolio_id=%d user_id=%d", portfolio_id, current_user.id)

    return TrustPortfolioResponse.model_validate(portfolio)


@router.delete(
    "/{portfolio_id}",
    summary="Soft delete a portfolio",
    description="Marks a portfolio as deleted.",
)
async def delete_portfolio(
    portfolio_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    # Only allow deletion of DRAFT/PENDING_PAYMENT portfolios
    if portfolio.status not in (PortfolioStatus.PENDING_PAYMENT.value,):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Cannot delete a portfolio that is already active or matured.",
        )

    portfolio.is_deleted = True
    await db.commit()

    logger.info("PORTFOLIO_DELETED portfolio_id=%d user_id=%d", portfolio_id, current_user.id)

    return {"message": "Portfolio deleted successfully."}


@router.post(
    "/{portfolio_id}/link-bank",
    response_model=TrustPortfolioDetailResponse,
    summary="Link a bank account to a portfolio",
    description="Links a bank account to the portfolio for dividend and maturity payouts. Only allowed when portfolio status is PENDING_PAYMENT.",
)
async def link_bank_account(
    portfolio_id: int,
    body: LinkBankRequest,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify portfolio belongs to user
    result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    # Only allow linking during PENDING_PAYMENT status
    if portfolio.status != PortfolioStatus.PENDING_PAYMENT.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bank account can only be linked when the portfolio is pending payment.",
        )

    # Verify the bank account belongs to the user and is not deleted
    bank_result = await db.execute(
        select(BankDetails).where(
            BankDetails.id == body.bank_details_id,
            BankDetails.app_user_id == current_user.id,
            BankDetails.is_deleted == 0,
        )
    )
    bank = bank_result.scalar_one_or_none()
    if not bank:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Bank account not found.")

    # Link the bank account
    portfolio.bank_details_id = body.bank_details_id
    await db.commit()
    await db.refresh(portfolio)

    logger.info("BANK_LINKED portfolio_id=%d bank_details_id=%d user_id=%d", portfolio_id, body.bank_details_id, current_user.id)

    # Build enriched response
    order = None
    if portfolio.trust_order_id:
        order_result = await db.execute(
            select(TrustOrder).where(TrustOrder.id == portfolio.trust_order_id)
        )
        order = order_result.scalar_one_or_none()

    return TrustPortfolioDetailResponse(
        portfolio=TrustPortfolioResponse.model_validate(portfolio),
        trust_asset_amount=order.trust_asset_amount if order else None,
        trust_reference_id=order.trust_reference_id if order else None,
        case_status=order.case_status if order else None,
        commencement_date=order.commencement_date if order else None,
        trust_period_ending_date=order.trust_period_ending_date if order else None,
        advisor_name=order.advisor_name if order else None,
        advisor_code=order.advisor_code if order else None,
        bank_name=bank.bank_name,
        bank_account_holder_name=bank.account_holder_name,
        bank_account_number=bank.account_number,
        bank_swift_code=bank.swift_code,
    )


@router.delete(
    "/{portfolio_id}/unlink-bank",
    response_model=TrustPortfolioDetailResponse,
    summary="Unlink bank account from a portfolio",
    description="Removes the linked bank account from the portfolio. Only allowed when portfolio status is PENDING_PAYMENT.",
)
async def unlink_bank_account(
    portfolio_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    # Verify portfolio belongs to user
    result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.id == portfolio_id,
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
        )
    )
    portfolio = result.scalar_one_or_none()
    if not portfolio:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Portfolio not found.")

    # Only allow unlinking during PENDING_PAYMENT status
    if portfolio.status != PortfolioStatus.PENDING_PAYMENT.value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Bank account can only be unlinked when the portfolio is pending payment.",
        )

    if portfolio.bank_details_id is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No bank account is currently linked to this portfolio.",
        )

    # Unlink the bank account
    portfolio.bank_details_id = None
    await db.commit()
    await db.refresh(portfolio)

    logger.info("BANK_UNLINKED portfolio_id=%d user_id=%d", portfolio_id, current_user.id)

    # Build enriched response
    order = None
    if portfolio.trust_order_id:
        order_result = await db.execute(
            select(TrustOrder).where(TrustOrder.id == portfolio.trust_order_id)
        )
        order = order_result.scalar_one_or_none()

    return TrustPortfolioDetailResponse(
        portfolio=TrustPortfolioResponse.model_validate(portfolio),
        trust_asset_amount=order.trust_asset_amount if order else None,
        trust_reference_id=order.trust_reference_id if order else None,
        case_status=order.case_status if order else None,
        commencement_date=order.commencement_date if order else None,
        trust_period_ending_date=order.trust_period_ending_date if order else None,
        advisor_name=order.advisor_name if order else None,
        advisor_code=order.advisor_code if order else None,
        bank_name=None,
        bank_account_holder_name=None,
        bank_account_number=None,
    )