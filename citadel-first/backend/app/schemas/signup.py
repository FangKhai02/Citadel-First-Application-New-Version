from datetime import datetime

from pydantic import BaseModel


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
