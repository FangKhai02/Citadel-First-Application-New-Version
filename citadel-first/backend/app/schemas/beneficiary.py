from datetime import date, datetime
from decimal import Decimal
from enum import Enum

from pydantic import BaseModel, Field


class BeneficiaryType(str, Enum):
    PRE_DEMISE = "pre_demise"
    POST_DEMISE = "post_demise"


class RelationshipToSettlor(str, Enum):
    SELF = "SELF"
    SPOUSE = "SPOUSE"
    CHILD = "CHILD"
    PARENT = "PARENT"
    SIBLING = "SIBLING"
    PARENTS = "PARENTS"
    GRANDPARENT = "GRANDPARENT"
    GRAND_SON = "GRAND_SON"
    GRAND_DAUGHTER = "GRAND_DAUGHTER"
    NIECE = "NIECE"
    NEPHEW = "NEPHEW"
    PARTNER = "PARTNER"
    FIANCE = "FIANCE"
    FRIEND = "FRIEND"
    GUARDIAN = "GUARDIAN"
    GOD_PARENT = "GOD_PARENT"
    MOTHER_IN_LAW = "MOTHER_IN_LAW"
    FATHER_IN_LAW = "FATHER_IN_LAW"
    SON_IN_LAW = "SON_IN_LAW"
    DAUGHTER_IN_LAW = "DAUGHTER_IN_LAW"
    ASSOCIATE = "ASSOCIATE"
    ADMINISTRATOR = "ADMINISTRATOR"


class BeneficiaryCreateRequest(BaseModel):
    beneficiary_type: BeneficiaryType
    same_as_settlor: bool = False

    # Personal details
    full_name: str | None = None
    nric: str | None = None
    id_number: str | None = None
    gender: str | None = None
    dob: date | None = None
    relationship_to_settlor: str | None = None

    # Address & Contact
    residential_address: str | None = None
    mailing_address: str | None = None
    email: str | None = None
    contact_number: str | None = None

    # Bank details
    bank_account_name: str | None = None
    bank_account_number: str | None = None
    bank_name: str | None = None
    bank_swift_code: str | None = None
    bank_address: str | None = None

    # Share percentage
    share_percentage: Decimal | None = Field(default=None, gt=0, le=100, max_digits=5, decimal_places=2)

    # Attachment S3 keys (set after upload)
    settlor_nric_key: str | None = None
    proof_of_address_key: str | None = None
    beneficiary_id_key: str | None = None
    bank_statement_key: str | None = None


class BeneficiaryUpdateRequest(BaseModel):
    same_as_settlor: bool | None = None
    full_name: str | None = None
    nric: str | None = None
    id_number: str | None = None
    gender: str | None = None
    dob: date | None = None
    relationship_to_settlor: str | None = None
    residential_address: str | None = None
    mailing_address: str | None = None
    email: str | None = None
    contact_number: str | None = None
    bank_account_name: str | None = None
    bank_account_number: str | None = None
    bank_name: str | None = None
    bank_swift_code: str | None = None
    bank_address: str | None = None
    share_percentage: Decimal | None = Field(default=None, gt=0, le=100, max_digits=5, decimal_places=2)
    settlor_nric_key: str | None = None
    proof_of_address_key: str | None = None
    beneficiary_id_key: str | None = None
    bank_statement_key: str | None = None


class BeneficiaryResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    app_user_id: int
    beneficiary_type: str
    same_as_settlor: bool

    full_name: str | None
    nric: str | None
    id_number: str | None
    gender: str | None
    dob: date | None
    relationship_to_settlor: str | None

    residential_address: str | None
    mailing_address: str | None
    email: str | None
    contact_number: str | None

    bank_account_name: str | None
    bank_account_number: str | None
    bank_name: str | None
    bank_swift_code: str | None
    bank_address: str | None

    share_percentage: Decimal | None

    settlor_nric_key: str | None
    proof_of_address_key: str | None
    beneficiary_id_key: str | None
    bank_statement_key: str | None

    created_at: datetime | None
    updated_at: datetime | None


class BeneficiaryListResponse(BaseModel):
    beneficiaries: list[BeneficiaryResponse]
    has_pre_demise: bool
    has_post_demise: bool


# Fix forward reference
from datetime import datetime  # noqa: E402

BeneficiaryResponse.model_rebuild()