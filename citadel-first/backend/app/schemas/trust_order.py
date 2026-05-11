from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field


class TrustOrderCreateRequest(BaseModel):
    # Trust Information
    date_of_trust_deed: date | None = None
    trust_asset_amount: Decimal | None = Field(default=None, gt=0, max_digits=15, decimal_places=2)
    advisor_name: str | None = None
    advisor_nric: str | None = None

    # Attachment S3 keys (set after upload)
    projected_yield_schedule_key: str | None = None
    acknowledgement_receipt_key: str | None = None


class TrustOrderUpdateRequest(BaseModel):
    date_of_trust_deed: date | None = None
    trust_asset_amount: Decimal | None = Field(default=None, gt=0, max_digits=15, decimal_places=2)
    advisor_name: str | None = None
    advisor_nric: str | None = None

    # Vanguard-side fields (updatable by admin)
    trust_reference_id: str | None = None
    case_status: str | None = None
    kyc_status: str | None = None
    deferment_remark: str | None = None
    advisor_code: str | None = None
    commencement_date: date | None = None
    trust_period_ending_date: date | None = None
    irrevocable_termination_notice_date: date | None = None
    auto_renewal_date: date | None = None

    projected_yield_schedule_key: str | None = None
    acknowledgement_receipt_key: str | None = None


class TrustOrderResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    app_user_id: int

    date_of_trust_deed: date | None
    trust_asset_amount: Decimal | None
    advisor_name: str | None
    advisor_nric: str | None

    trust_reference_id: str | None
    case_status: str
    kyc_status: str | None
    deferment_remark: str | None
    advisor_code: str | None
    commencement_date: date | None
    trust_period_ending_date: date | None
    irrevocable_termination_notice_date: date | None
    auto_renewal_date: date | None

    projected_yield_schedule_key: str | None
    acknowledgement_receipt_key: str | None

    created_at: datetime | None
    updated_at: datetime | None


class TrustOrderListResponse(BaseModel):
    orders: list[TrustOrderResponse]


class PaymentStatusUpdateRequest(BaseModel):
    payment_status: str  # "SUCCESS" or "FAILED"