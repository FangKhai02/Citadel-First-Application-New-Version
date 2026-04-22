from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, field_validator


class BankruptcyDeclarationRequest(BaseModel):
    is_not_bankrupt: bool

    model_config = {
        "json_schema_extra": {"example": {"is_not_bankrupt": True}}
    }


class BankruptcyDeclarationResponse(BaseModel):
    id: int
    user_id: int
    is_not_bankrupt: bool
    declared_at: datetime
    message: str

    model_config = {"from_attributes": True}


class DisclaimerAcceptanceRequest(BaseModel):
    agreed: bool

    model_config = {
        "json_schema_extra": {"example": {"agreed": True}}
    }


class DisclaimerAcceptanceResponse(BaseModel):
    id: int
    user_id: int
    agreed: bool
    agreed_at: datetime
    message: str

    model_config = {"from_attributes": True}


class TrustFormB6Request(BaseModel):
    trust_deed_date: date
    trust_asset_amount: Decimal
    advisor_name: str
    advisor_nric: str

    @field_validator("trust_asset_amount")
    @classmethod
    def amount_must_be_positive(cls, v: Decimal) -> Decimal:
        if v <= 0:
            raise ValueError("trust_asset_amount must be greater than zero")
        return v

    @field_validator("advisor_name")
    @classmethod
    def name_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("advisor_name must not be empty")
        return v.strip()

    @field_validator("advisor_nric")
    @classmethod
    def nric_not_empty(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("advisor_nric must not be empty")
        return v.strip()

    model_config = {
        "json_schema_extra": {
            "example": {
                "trust_deed_date": "2024-01-15",
                "trust_asset_amount": "500000.00",
                "advisor_name": "Ahmad bin Abdullah",
                "advisor_nric": "801231-14-5678",
            }
        }
    }


class TrustFormB6Response(BaseModel):
    id: int
    user_id: int
    trust_deed_date: date
    trust_asset_amount: Decimal
    advisor_name: str
    advisor_nric: str
    created_at: datetime
    message: str

    model_config = {"from_attributes": True}
