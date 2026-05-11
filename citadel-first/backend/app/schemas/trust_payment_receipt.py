from datetime import datetime
from enum import Enum

from pydantic import BaseModel

from app.schemas.user_details import PresignedUrlRequest, PresignedUrlResponse


class UploadStatus(str, Enum):
    DRAFT = "DRAFT"
    UPLOADED = "UPLOADED"


class TrustPaymentReceiptUploadRequest(BaseModel):
    file_name: str
    content_type: str = "application/pdf"


class TrustPaymentReceiptResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    trust_portfolio_id: int
    file_name: str
    file_key: str
    upload_status: str
    created_at: datetime | None
    updated_at: datetime | None


class TrustPaymentReceiptConfirmRequest(BaseModel):
    receipt_id: int


class TrustPaymentReceiptListResponse(BaseModel):
    receipts: list[TrustPaymentReceiptResponse]