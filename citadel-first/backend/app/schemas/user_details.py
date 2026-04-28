from datetime import date
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class DocumentType(str, Enum):
    MYKAD = "MYKAD"
    IKAD = "IKAD"
    PASSPORT = "PASSPORT"
    MYTENTERA = "MYTENTERA"


# ── Identity Document (existing) ──────────────────────────────────────────────


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


# ── Onboarding Agreement (E-Sign) ────────────────────────────────────────────


class OnboardingAgreementRequest(BaseModel):
    signature_base64: str
    full_name: str
    ic_number: str


class OnboardingAgreementResponse(BaseModel):
    id: int
    app_user_id: int
    digital_signature_key: str | None = None
    onboarding_agreement_key: str | None = None
    message: str

    model_config = {"from_attributes": True}


class SignupUserDetailsResponse(BaseModel):
    name: str | None = None
    identity_card_number: str | None = None

    model_config = {"from_attributes": True}


# ── Personal Details (Page 1: Title, Marital Status, Passport Expiry) ─────────


class PersonalDetailsRequest(BaseModel):
    title: str | None = None
    marital_status: str | None = None
    passport_expiry: date | None = None


class PersonalDetailsResponse(BaseModel):
    id: int
    app_user_id: int
    title: str | None
    marital_status: str | None
    passport_expiry: date | None

    model_config = {"from_attributes": True}


# ── Address & Contact (Page 2) ─────────────────────────────────────────────────


class AddressContactRequest(BaseModel):
    residential_address: str | None = None
    mailing_address: str | None = None
    mailing_same_as_residential: bool | None = None
    home_telephone: str | None = None
    mobile_number: str | None = None
    email: str | None = None


class AddressContactResponse(BaseModel):
    id: int
    app_user_id: int
    residential_address: str | None
    mailing_address: str | None
    mailing_same_as_residential: bool | None
    home_telephone: str | None
    mobile_number: str | None
    email: str | None

    model_config = {"from_attributes": True}


# ── Employment & Financial Details (Page 3) ────────────────────────────────────


class EmploymentDetailsRequest(BaseModel):
    employment_type: str | None = None
    occupation: str | None = None
    work_title: str | None = None
    nature_of_business: str | None = None
    nature_of_business_other: str | None = None
    employer_name: str | None = None
    employer_address: str | None = None
    employer_telephone: str | None = None
    annual_income_range: str | None = None
    estimated_net_worth: str | None = None


class EmploymentDetailsResponse(BaseModel):
    id: int
    app_user_id: int
    employment_type: str | None
    occupation: str | None
    work_title: str | None
    nature_of_business: str | None
    nature_of_business_other: str | None
    employer_name: str | None
    employer_address: str | None
    employer_telephone: str | None
    annual_income_range: str | None
    estimated_net_worth: str | None

    model_config = {"from_attributes": True}


# ── KYC (Page 4 — CRS tax residencies moved to separate table/endpoint) ────────


class KycRequest(BaseModel):
    source_of_trust_fund: str | None = None
    source_of_income: str | None = None
    country_of_birth: str | None = None
    physically_present: bool | None = None
    main_sources_of_income: str | None = None
    has_unusual_transactions: bool | None = None
    marital_history: str | None = None
    geographical_connections: str | None = None
    other_relevant_info: str | None = None


class KycResponse(BaseModel):
    id: int
    app_user_id: int
    source_of_trust_fund: str | None
    source_of_income: str | None
    country_of_birth: str | None
    physically_present: bool | None
    main_sources_of_income: str | None
    has_unusual_transactions: bool | None
    marital_history: str | None
    geographical_connections: str | None
    other_relevant_info: str | None

    model_config = {"from_attributes": True}