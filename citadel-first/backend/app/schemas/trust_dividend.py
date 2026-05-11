from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class DividendPaymentStatus(str, Enum):
    PENDING = "PENDING"
    PAID = "PAID"


# ── Dividend Create (admin/Vanguard) ────────────────────────────

class TrustDividendCreateRequest(BaseModel):
    trust_portfolio_id: int
    dividend_amount: Decimal = Field(gt=0, max_digits=15, decimal_places=2)
    trustee_fee_amount: Decimal = Field(default=Decimal("0"), ge=0, max_digits=15, decimal_places=2)
    period_starting_date: date | None = None
    period_ending_date: date | None = None
    dividend_quarter: int = Field(default=0, ge=0, le=4)


# ── Dividend Status Update ──────────────────────────────────────

class TrustDividendStatusUpdateRequest(BaseModel):
    payment_status: DividendPaymentStatus
    payment_date: date | None = None


# ── Dividend Response ───────────────────────────────────────────

class TrustDividendResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    trust_portfolio_id: int
    reference_number: str
    dividend_amount: Decimal
    trustee_fee_amount: Decimal
    period_starting_date: date | None
    period_ending_date: date | None
    dividend_quarter: int
    payment_status: str
    payment_date: date | None
    created_at: datetime | None
    updated_at: datetime | None


class TrustDividendListResponse(BaseModel):
    dividends: list[TrustDividendResponse]