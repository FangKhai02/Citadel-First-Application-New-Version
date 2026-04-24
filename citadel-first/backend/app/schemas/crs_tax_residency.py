from pydantic import BaseModel


class CrsTaxResidencyRow(BaseModel):
    jurisdiction: str
    tin: str | None = None
    no_tin_reason: str | None = None  # "A", "B", or "C"
    reason_b_explanation: str | None = None


class CrsTaxResidencyRequest(BaseModel):
    """Request body for PUT /signup/crs-tax-residency — replaces all rows for the user."""
    residencies: list[CrsTaxResidencyRow]


class CrsTaxResidencyResponse(BaseModel):
    id: int
    app_user_id: int
    jurisdiction: str
    tin: str | None
    no_tin_reason: str | None
    reason_b_explanation: str | None

    model_config = {"from_attributes": True}


class CrsTaxResidencyListResponse(BaseModel):
    residencies: list[CrsTaxResidencyResponse]