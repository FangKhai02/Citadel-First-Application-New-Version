from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel


class TransactionType(str, Enum):
    PLACEMENT = "PLACEMENT"
    DIVIDEND = "DIVIDEND"
    WITHDRAWAL = "WITHDRAWAL"
    ROLLOVER = "ROLLOVER"
    REDEMPTION = "REDEMPTION"
    REALLOCATION = "REALLOCATION"


class TransactionResponse(BaseModel):
    id: int
    transaction_type: TransactionType
    transaction_title: str
    product_name: str
    amount: Decimal | None
    trustee_fee: Decimal | None = None
    transaction_date: date | datetime | None
    bank_name: str | None = None
    reference_number: str | None = None
    status: str | None = None

    # Portfolio-specific fields (only for PLACEMENT type)
    portfolio_id: int | None = None
    trust_order_id: int | None = None

    # Dividend-specific fields (only for DIVIDEND type)
    dividend_quarter: int | None = None
    period_starting_date: date | None = None
    period_ending_date: date | None = None


class TransactionListResponse(BaseModel):
    transactions: list[TransactionResponse]