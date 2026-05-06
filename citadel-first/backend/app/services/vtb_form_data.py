"""Assemble VTB KYC form data from all database tables.

Queries user_details, trust_orders, crs_tax_residency, pep_declaration,
and beneficiaries tables, then applies null→N/A logic for PDF population.
"""

import logging
from datetime import date, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.beneficiary import Beneficiary
from app.models.crs_tax_residency import CrsTaxResidency
from app.models.pep_declaration import PepDeclaration
from app.models.trust_order import TrustOrder
from app.models.user_details import UserDetails
from app.schemas.vtb_kyc import (
    BeneficiaryData,
    CrsTaxResidencyData,
    PepDeclarationData,
    VtbKycFormData,
)

logger = logging.getLogger(__name__)

NA = "N/A"


def na(value: str | None) -> str:
    """Replace None or empty string with N/A."""
    if value is None or value.strip() == "":
        return NA
    return value


def na_date(value: date | datetime | None) -> str:
    """Format a date as DD/MM/YYYY or N/A."""
    if value is None:
        return NA
    if isinstance(value, datetime):
        return value.strftime("%d/%m/%Y")
    return value.strftime("%d/%m/%Y")


def na_bool(value: bool | None) -> str:
    """Format a boolean as Yes/No or N/A."""
    if value is None:
        return NA
    return "Yes" if value else "No"


def na_currency(value) -> str:
    """Format a decimal amount as RM currency or N/A."""
    if value is None:
        return NA
    try:
        amount = float(value)
        return f"RM {amount:,.2f}"
    except (TypeError, ValueError):
        return NA


def _na_pct(value) -> str:
    """Format a share percentage value as 'X%' or N/A.

    Handles input formats: 70, 70.0, 70%, 'RM 70.00', None.
    """
    if value is None:
        return NA
    s = str(value).strip().rstrip("%")
    s = s.replace("RM", "").replace(",", "").strip()
    try:
        num = float(s)
        return f"{num:.0f}%"
    except (TypeError, ValueError):
        return NA


async def assemble_kyc_form_data(
    db: AsyncSession,
    app_user_id: int,
    trust_order_id: int | None = None,
) -> VtbKycFormData:
    """Query all 5 tables and assemble VtbKycFormData with null→N/A logic.

    Args:
        db: Async database session.
        app_user_id: The app_user_id to look up.
        trust_order_id: Optional specific trust order. If None, uses the latest.

    Raises:
        KycFormDataError: If user_details row is not found.
    """
    # ── 1. user_details ──
    ud_result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == app_user_id)
    )
    ud = ud_result.scalar_one_or_none()
    if ud is None:
        raise KycFormDataError(f"user_details not found for app_user_id={app_user_id}")

    # ── 2. trust_orders ──
    if trust_order_id is not None:
        to_result = await db.execute(
            select(TrustOrder).where(
                TrustOrder.id == trust_order_id,
                TrustOrder.app_user_id == app_user_id,
                TrustOrder.is_deleted == False,
            )
        )
        to = to_result.scalar_one_or_none()
    else:
        to_result = await db.execute(
            select(TrustOrder)
            .where(
                TrustOrder.app_user_id == app_user_id,
                TrustOrder.is_deleted == False,
            )
            .order_by(TrustOrder.created_at.desc())
        )
        to = to_result.scalar_one_or_none()

    # ── 3. crs_tax_residency ──
    crs_result = await db.execute(
        select(CrsTaxResidency)
        .where(CrsTaxResidency.app_user_id == app_user_id)
        .order_by(CrsTaxResidency.id)
    )
    crs_rows = list(crs_result.scalars().all())

    # ── 4. pep_declaration ──
    pep_result = await db.execute(
        select(PepDeclaration).where(PepDeclaration.app_user_id == app_user_id)
    )
    pep = pep_result.scalar_one_or_none()

    # ── 5. beneficiaries ──
    ben_result = await db.execute(
        select(Beneficiary)
        .where(
            Beneficiary.app_user_id == app_user_id,
            Beneficiary.is_deleted == False,
        )
        .order_by(Beneficiary.id)
    )
    ben_rows = list(ben_result.scalars().all())

    # ── Assemble CRS data ──
    crs_residencies = [
        CrsTaxResidencyData(
            jurisdiction=na(row.jurisdiction),
            tin_status=na(row.tin_status),
            tin=na(row.tin),
            no_tin_reason=na(row.no_tin_reason),
            reason_b_explanation=na(row.reason_b_explanation),
        )
        for row in crs_rows
    ]

    # ── Assemble PEP data ──
    pep_data = PepDeclarationData(
        is_pep=na_bool(pep.is_pep) if pep else NA,
        pep_relationship=na(pep.pep_relationship) if pep else NA,
        pep_name=na(pep.pep_name) if pep else NA,
        pep_position=na(pep.pep_position) if pep else NA,
        pep_organisation=na(pep.pep_organisation) if pep else NA,
    )

    # ── Assemble beneficiary data ──
    def build_beneficiary(b: Beneficiary) -> BeneficiaryData:
        return BeneficiaryData(
            full_name=na(b.full_name),
            nric=na(b.nric),
            id_number=na(b.id_number),
            gender=na(b.gender),
            dob=na_date(b.dob),
            relationship_to_settlor=na(b.relationship_to_settlor),
            residential_address=na(b.residential_address),
            mailing_address=na(b.mailing_address),
            email=na(b.email),
            contact_number=na(b.contact_number),
            bank_account_name=na(b.bank_account_name),
            bank_account_number=na(b.bank_account_number),
            bank_name=na(b.bank_name),
            bank_swift_code=na(b.bank_swift_code),
            bank_address=na(b.bank_address),
            share_percentage=_na_pct(b.share_percentage),
            beneficiary_type=b.beneficiary_type,
            same_as_settlor=b.same_as_settlor if b.same_as_settlor is not None else False,
        )

    pre_demise = [build_beneficiary(b) for b in ben_rows if b.beneficiary_type == "pre_demise"]
    post_demise = [build_beneficiary(b) for b in ben_rows if b.beneficiary_type == "post_demise"]

    # ── Assemble final data ──
    return VtbKycFormData(
        # user_details fields
        name=na(ud.name),
        identity_card_number=na(ud.identity_card_number),
        identity_doc_type=na(ud.identity_doc_type),
        title=na(ud.title),
        dob=na_date(ud.dob),
        gender=na(ud.gender),
        nationality=na(ud.nationality),
        marital_status=na(ud.marital_status),
        passport_expiry=na_date(ud.passport_expiry),
        residential_address=na(ud.residential_address),
        mailing_address=na(ud.mailing_address),
        home_telephone=na(ud.home_telephone),
        mobile_number=na(ud.mobile_number),
        email=na(ud.email),
        employment_type=na(ud.employment_type),
        occupation=na(ud.occupation),
        work_title=na(ud.work_title),
        nature_of_business=na(ud.nature_of_business),
        employer_name=na(ud.employer_name),
        employer_address=na(ud.employer_address),
        employer_telephone=na(ud.employer_telephone),
        annual_income_range=na(ud.annual_income_range),
        estimated_net_worth=na(ud.estimated_net_worth),
        source_of_trust_fund=na(ud.source_of_trust_fund),
        source_of_income=na(ud.source_of_income),
        country_of_birth=na(ud.country_of_birth),
        physically_present=na_bool(ud.physically_present),
        main_sources_of_income=na(ud.main_sources_of_income),
        has_unusual_transactions=na_bool(ud.has_unusual_transactions),
        marital_history=na(ud.marital_history),
        geographical_connections=na(ud.geographical_connections),
        other_relevant_info=na(ud.other_relevant_info),
        digital_signature_key=na(ud.digital_signature_key),
        # trust_order fields
        date_of_trust_deed=na_date(to.date_of_trust_deed) if to else NA,
        trust_asset_amount=na_currency(to.trust_asset_amount) if to else NA,
        advisor_name=na(to.advisor_name) if to else NA,
        advisor_nric=na(to.advisor_nric) if to else NA,
        # related data
        crs_residencies=crs_residencies,
        pep_declaration=pep_data,
        pre_demise_beneficiaries=pre_demise,
        post_demise_beneficiaries=post_demise,
    )


class KycFormDataError(Exception):
    """Raised when required data is missing for KYC form generation."""
    pass