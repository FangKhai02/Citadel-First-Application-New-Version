import logging
from datetime import date, datetime

from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.trust_dividend_history import TrustDividendHistory
from app.models.trust_order import TrustOrder
from app.models.trust_portfolio import TrustPortfolio
from app.models.bank_details import BankDetails
from app.models.user import AppUser
from app.schemas.transaction import TransactionListResponse, TransactionResponse, TransactionType

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/transactions", tags=["Transactions"])


@router.get(
    "/me",
    response_model=TransactionListResponse,
    summary="List my transactions",
    description="Returns a combined list of placement and dividend transactions, sorted by date descending. Optional ?type=PLACEMENT or ?type=DIVIDEND filter.",
)
async def list_my_transactions(
    type: Optional[str] = Query(None, description="Filter by transaction type: PLACEMENT or DIVIDEND"),
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    transactions = []

    # 1. PLACEMENT transactions — portfolios with payment_status=SUCCESS
    portfolio_result = await db.execute(
        select(TrustPortfolio).where(
            TrustPortfolio.app_user_id == current_user.id,
            TrustPortfolio.is_deleted == False,
            TrustPortfolio.payment_status == "SUCCESS",
        ).order_by(TrustPortfolio.created_at.desc())
    )
    portfolios = portfolio_result.scalars().all()

    for p in portfolios:
        bank = None
        if p.bank_details_id:
            bank_result = await db.execute(
                select(BankDetails).where(BankDetails.id == p.bank_details_id)
            )
            bank = bank_result.scalar_one_or_none()

        # Read amount from linked trust_order
        amount = None
        if p.trust_order_id:
            order_result = await db.execute(
                select(TrustOrder).where(TrustOrder.id == p.trust_order_id)
            )
            order = order_result.scalar_one_or_none()
            if order and order.trust_asset_amount is not None:
                amount = order.trust_asset_amount

        transactions.append(TransactionResponse(
            id=p.id,
            transaction_type=TransactionType.PLACEMENT,
            transaction_title="Placement",
            product_name=p.product_name,
            amount=amount,
            trustee_fee=None,
            transaction_date=p.created_at,
            bank_name=bank.bank_name if bank else None,
            reference_number=None,
            status=p.payment_status,
            portfolio_id=p.id,
            trust_order_id=p.trust_order_id,
        ))

    # 2. DIVIDEND transactions — dividend history with payment_status=PAID
    dividend_result = await db.execute(
        select(TrustDividendHistory).where(
            TrustDividendHistory.trust_portfolio_id.in_([p.id for p in portfolios]),
            TrustDividendHistory.payment_status == "PAID",
        ).order_by(TrustDividendHistory.payment_date.desc())
    )
    dividends = dividend_result.scalars().all()

    for d in dividends:
        # Get portfolio for product name and bank
        portfolio = next((p for p in portfolios if p.id == d.trust_portfolio_id), None)
        bank = None
        if portfolio and portfolio.bank_details_id:
            bank_result = await db.execute(
                select(BankDetails).where(BankDetails.id == portfolio.bank_details_id)
            )
            bank = bank_result.scalar_one_or_none()

        quarter_label = f"Q{d.dividend_quarter} Profit Sharing Earned" if d.dividend_quarter else "Profit Sharing Earned"

        transactions.append(TransactionResponse(
            id=d.id,
            transaction_type=TransactionType.DIVIDEND,
            transaction_title=quarter_label,
            product_name=portfolio.product_name if portfolio else "Trust Product",
            amount=d.dividend_amount,
            trustee_fee=d.trustee_fee_amount,
            transaction_date=d.payment_date or d.created_at,
            bank_name=bank.bank_name if bank else None,
            reference_number=d.reference_number,
            status=d.payment_status,
            portfolio_id=d.trust_portfolio_id,
            trust_order_id=portfolio.trust_order_id if portfolio else None,
            dividend_quarter=d.dividend_quarter,
            period_starting_date=d.period_starting_date,
            period_ending_date=d.period_ending_date,
        ))

    # Sort all transactions by transaction_date descending
    def _sort_key(t):
        td = t.transaction_date
        if td is None:
            return ""
        # Normalize date to datetime for consistent comparison
        if isinstance(td, date) and not isinstance(td, datetime):
            return datetime.combine(td, datetime.min.time()).isoformat()
        return td.isoformat() if hasattr(td, "isoformat") else str(td)

    transactions.sort(key=_sort_key, reverse=True)

    # Apply type filter if provided
    if type:
        try:
            filter_type = TransactionType(type.upper())
            transactions = [t for t in transactions if t.transaction_type == filter_type]
        except ValueError:
            pass  # Invalid type value — return all

    return TransactionListResponse(transactions=transactions)