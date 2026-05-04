from datetime import date, datetime

from pydantic import BaseModel, EmailStr


class MeResponse(BaseModel):
    id: int
    email: str
    user_type: str  # CLIENT | AGENT | CORPORATE | ADMIN
    name: str | None = None
    signup_completed: bool = True
    email_verified: bool = True
    has_beneficiaries: bool = False
    unread_notification_count: int = 0
    created_at: datetime | None = None

    model_config = {"from_attributes": True}


class SettlorProfileResponse(BaseModel):
    """Full settlor profile for 'Same as Settlor' beneficiary auto-population."""
    name: str | None = None
    identity_card_number: str | None = None
    identity_doc_type: str | None = None  # MYKAD, IKAD, PASSPORT, MYTENTERA
    gender: str | None = None
    dob: date | None = None
    nationality: str | None = None
    residential_address: str | None = None
    mailing_address: str | None = None
    mailing_same_as_residential: bool | None = None
    email: str | None = None
    mobile_number: str | None = None

    model_config = {"from_attributes": True}
