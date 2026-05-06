from pydantic import BaseModel


class CrsTaxResidencyData(BaseModel):
    """Single CRS tax residency row for PDF population."""
    jurisdiction: str
    tin_status: str
    tin: str
    no_tin_reason: str
    reason_b_explanation: str


class BeneficiaryData(BaseModel):
    """Single beneficiary for PDF population (B2 form)."""
    full_name: str
    nric: str
    id_number: str
    gender: str
    dob: str
    relationship_to_settlor: str
    residential_address: str
    mailing_address: str
    email: str
    contact_number: str
    bank_account_name: str
    bank_account_number: str
    bank_name: str
    bank_swift_code: str
    bank_address: str
    share_percentage: str
    beneficiary_type: str
    same_as_settlor: bool = False


class PepDeclarationData(BaseModel):
    """PEP declaration data for PDF population (A2 form)."""
    is_pep: str
    pep_relationship: str
    pep_name: str
    pep_position: str
    pep_organisation: str


class VtbKycFormData(BaseModel):
    """Assembled data from all 5 tables, ready for PDF population.
    All string fields default to "N/A" when the source is null.
    """
    # ── From user_details ──
    name: str
    identity_card_number: str
    identity_doc_type: str
    title: str
    dob: str
    gender: str
    nationality: str
    marital_status: str
    passport_expiry: str
    residential_address: str
    mailing_address: str
    home_telephone: str
    mobile_number: str
    email: str
    employment_type: str
    occupation: str
    work_title: str
    nature_of_business: str
    employer_name: str
    employer_address: str
    employer_telephone: str
    annual_income_range: str
    estimated_net_worth: str
    source_of_trust_fund: str
    source_of_income: str
    country_of_birth: str
    physically_present: str
    main_sources_of_income: str
    has_unusual_transactions: str
    marital_history: str
    geographical_connections: str
    other_relevant_info: str
    digital_signature_key: str

    # ── From trust_orders ──
    date_of_trust_deed: str
    trust_asset_amount: str
    advisor_name: str
    advisor_nric: str

    # ── From crs_tax_residency (up to 5 rows) ──
    crs_residencies: list[CrsTaxResidencyData]

    # ── From pep_declaration ──
    pep_declaration: PepDeclarationData

    # ── From beneficiaries ──
    pre_demise_beneficiaries: list[BeneficiaryData]
    post_demise_beneficiaries: list[BeneficiaryData]


class KycFormsGenerateRequest(BaseModel):
    """Request body for KYC form generation."""
    app_user_id: int
    trust_order_id: int | None = None
    email: str | None = None  # Override recipient email for generate-and-email


class KycFormResult(BaseModel):
    """Result of a single form generation."""
    form_id: str  # "A1", "A2", "B2", "B3", "B4", "B6"
    s3_key: str
    filename: str


class KycFormsGenerateResponse(BaseModel):
    """Response for all 6 form generation."""
    forms: list[KycFormResult]