from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class PortfolioStatus(str, Enum):
    PENDING_PAYMENT = "PENDING_PAYMENT"
    ACTIVE = "ACTIVE"
    MATURED = "MATURED"
    WITHDRAWN = "WITHDRAWN"


class PaymentMethod(str, Enum):
    MANUAL_TRANSFER = "MANUAL_TRANSFER"
    ONLINE_BANKING = "ONLINE_BANKING"


class PaymentStatus(str, Enum):
    PENDING = "PENDING"
    IN_REVIEW = "IN_REVIEW"
    SUCCESS = "SUCCESS"
    FAILED = "FAILED"


class PayoutFrequency(str, Enum):
    MONTHLY = "MONTHLY"
    QUARTERLY = "QUARTERLY"
    ANNUALLY = "ANNUALLY"


class AgreementStatus(str, Enum):
    PENDING = "PENDING"
    SUCCESS = "SUCCESS"
    REJECTED = "REJECTED"


# ── Portfolio Create (admin/Vanguard) ──────────────────────────

class TrustPortfolioCreateRequest(BaseModel):
    trust_order_id: int
    product_name: str = "CWD Trust"
    product_code: str = "CWD"
    dividend_rate: Decimal | None = Field(default=None, max_digits=5, decimal_places=2)
    investment_tenure_months: int | None = None
    maturity_date: date | None = None
    payout_frequency: PayoutFrequency = PayoutFrequency.QUARTERLY
    is_prorated: bool = False


# ── Portfolio Update ────────────────────────────────────────────

class TrustPortfolioUpdateRequest(BaseModel):
    product_name: str | None = None
    product_code: str | None = None
    dividend_rate: Decimal | None = Field(default=None, max_digits=5, decimal_places=2)
    investment_tenure_months: int | None = None
    maturity_date: date | None = None
    payout_frequency: PayoutFrequency | None = None
    is_prorated: bool | None = None
    status: PortfolioStatus | None = None
    payment_method: PaymentMethod | None = None
    payment_status: PaymentStatus | None = None
    bank_details_id: int | None = None
    agreement_file_name: str | None = None
    agreement_key: str | None = None
    agreement_date: date | None = None
    client_agreement_status: AgreementStatus | None = None


# ── Portfolio Response ──────────────────────────────────────────

class TrustPortfolioResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    app_user_id: int
    trust_order_id: int | None
    product_name: str
    product_code: str
    dividend_rate: Decimal | None
    investment_tenure_months: int | None
    maturity_date: date | None
    payout_frequency: str
    is_prorated: bool
    status: str
    payment_method: str | None
    payment_status: str
    bank_details_id: int | None
    agreement_file_name: str | None
    agreement_key: str | None
    agreement_date: date | None
    client_agreement_status: str | None
    is_deleted: bool
    created_at: datetime | None
    updated_at: datetime | None


# ── Portfolio Detail (includes order + bank info) ───────────────

class TrustPortfolioDetailResponse(BaseModel):
    portfolio: TrustPortfolioResponse
    trust_asset_amount: Decimal | None = None
    trust_reference_id: str | None = None
    case_status: str | None = None
    commencement_date: date | None = None
    trust_period_ending_date: date | None = None
    advisor_name: str | None = None
    advisor_code: str | None = None
    bank_name: str | None = None
    bank_account_holder_name: str | None = None
    bank_account_number: str | None = None
    bank_swift_code: str | None = None


class LinkBankRequest(BaseModel):
    bank_details_id: int


class TrustPortfolioListResponse(BaseModel):
    portfolios: list[TrustPortfolioDetailResponse]