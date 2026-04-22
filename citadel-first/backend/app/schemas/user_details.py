from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class DocumentType(str, Enum):
    MYKAD = "MYKAD"
    IKAD = "IKAD"
    PASSPORT = "PASSPORT"
    MYTENTERA = "MYTENTERA"


class IdentityDocumentUploadRequest(BaseModel):
    doc_type: DocumentType
    front_image_key: str | None = None
    back_image_key: str | None = None


class IdentityDocumentUploadResponse(BaseModel):
    front_image_key: str
    back_image_key: str | None = None
    message: str


class PresignedUrlRequest(BaseModel):
    filename: str
    content_type: str = "image/jpeg"


class PresignedUrlResponse(BaseModel):
    upload_url: str
    key: str


class OcrRequest(BaseModel):
    image_key: str
    doc_type: DocumentType


class OcrResultData(BaseModel):
    model_config = {"from_attributes": True}

    full_name: str | None = None
    identity_number: str | None = None
    date_of_birth: date | None = None
    gender: str | None = None
    nationality: str | None = None
    address: str | None = None
    confidence: float = Field(ge=0.0, le=1.0, default=0.0)
    raw_text: str | None = None


class OcrResponse(BaseModel):
    data: OcrResultData
    doc_type: DocumentType


class UserDetailsConfirmRequest(BaseModel):
    name: str | None = None
    identity_card_number: str | None = None
    dob: date | None = None
    gender: str | None = None
    nationality: str | None = None


class UserDetailsResponse(BaseModel):
    id: int
    app_user_id: int
    name: str | None
    identity_card_number: str | None
    identity_doc_type: str | None
    ocr_confidence: Decimal | None

    model_config = {"from_attributes": True}
