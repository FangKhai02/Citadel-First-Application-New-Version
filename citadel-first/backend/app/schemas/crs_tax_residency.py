from pydantic import BaseModel, field_validator


class CrsTaxResidencyRow(BaseModel):
    jurisdiction: str
    tin_status: str  # "have_tin" or "no_tin"
    tin: str | None = None
    no_tin_reason: str | None = None  # "A", "B", or "C"
    reason_b_explanation: str | None = None

    @field_validator("tin_status")
    @classmethod
    def validate_tin_status(cls, v: str) -> str:
        if v not in ("have_tin", "no_tin"):
            raise ValueError("tin_status must be 'have_tin' or 'no_tin'")
        return v

    @field_validator("no_tin_reason")
    @classmethod
    def validate_no_tin_reason(cls, v: str | None, info) -> str | None:
        # no_tin_reason is required when tin_status is "no_tin"
        return v


class CrsTaxResidencyRequest(BaseModel):
    """Request body for PUT /signup/crs-tax-residency — replaces all rows for the user."""
    residencies: list[CrsTaxResidencyRow]


class CrsTaxResidencyResponse(BaseModel):
    id: int
    app_user_id: int
    jurisdiction: str
    tin_status: str | None
    tin: str | None
    no_tin_reason: str | None
    reason_b_explanation: str | None

    model_config = {"from_attributes": True}


class CrsTaxResidencyListResponse(BaseModel):
    residencies: list[CrsTaxResidencyResponse]