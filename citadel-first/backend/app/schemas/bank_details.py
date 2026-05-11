from datetime import datetime

from pydantic import BaseModel


class BankDetailsCreateRequest(BaseModel):
    bank_name: str
    account_holder_name: str
    account_number: str
    bank_address: str | None = None
    postcode: str | None = None
    city: str | None = None
    state: str | None = None
    country: str | None = None
    swift_code: str | None = None
    bank_account_proof_key: str | None = None


class BankDetailsUpdateRequest(BaseModel):
    bank_name: str | None = None
    account_holder_name: str | None = None
    account_number: str | None = None
    bank_address: str | None = None
    postcode: str | None = None
    city: str | None = None
    state: str | None = None
    country: str | None = None
    swift_code: str | None = None
    bank_account_proof_key: str | None = None


class BankDetailsProofUploadRequest(BaseModel):
    file_name: str
    content_type: str = "image/jpeg"


class BankDetailsResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    app_user_id: int | None
    bank_name: str | None
    account_holder_name: str | None
    account_number: str | None
    bank_address: str | None
    postcode: str | None
    city: str | None
    state: str | None
    country: str | None
    swift_code: str | None
    bank_account_proof_key: str | None = None
    is_deleted: int | None
    created_at: datetime | None
    updated_at: datetime | None


class BankDetailsListResponse(BaseModel):
    banks: list[BankDetailsResponse]