"""Generate A2 form for LEE WEI KANG and email for review.

Usage:
    cd backend
    python test_a2_form.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.schemas.vtb_kyc import (
    VtbKycFormData,
    BeneficiaryData,
    CrsTaxResidencyData,
    PepDeclarationData,
)
from app.services.vtb_pdf_service import build_form_a2
from app.services.email_service import send_kyc_forms_email


def make_lee_wei_kang() -> VtbKycFormData:
    return VtbKycFormData(
        name="LEE WEI KANG",
        identity_card_number="900101-10-5678",
        identity_doc_type="MYKAD",
        title="Mr",
        dob="01/01/1990",
        gender="Male",
        nationality="Malaysian",
        marital_status="Single",
        residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
        mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
        home_telephone="03-2694 1888",
        mobile_number="+6012-345 6789",
        email="lee.weikang@test.com.my",
        employment_type="Employed",
        occupation="Senior Analyst",
        work_title="Senior Analyst",
        nature_of_business="Financial Services",
        employer_name="Citadel Group Sdn. Bhd.",
        employer_address="Level 8, Menara MAA, 12, Jalan Meru, 55100 Kuala Lumpur",
        employer_telephone="03-2694 1888",
        annual_income_range="RM100,001 - RM250,000",
        estimated_net_worth="RM500,001 - RM1,000,000",
        source_of_trust_fund="Salary",
        source_of_income="Employment",
        country_of_birth="Malaysia",
        physically_present="Yes",
        main_sources_of_income="Employment salary",
        has_unusual_transactions="No",
        marital_history="Single, never married",
        geographical_connections="None",
        other_relevant_info="None",
        date_of_trust_deed="01/04/2026",
        trust_asset_amount="RM 1,000,000.00",
        pre_demise_beneficiaries=[
            BeneficiaryData(
                full_name="LIM MEI LING",
                nric="920505-14-5678",
                id_number="N/A",
                gender="Female",
                dob="05/05/1992",
                relationship_to_settlor="SPOUSE",
                residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                email="lim.meiling@test.com.my",
                contact_number="+6016-789 0123",
                bank_account_name="LIM MEI LING",
                bank_account_number="123456789012",
                bank_name="Maybank Berhad",
                bank_swift_code="MBBEMYKL",
                bank_address="Maybank Tower, Kuala Lumpur",
                share_percentage="100%",
                beneficiary_type="pre_demise",
            ),
        ],
        post_demise_beneficiaries=[
            BeneficiaryData(
                full_name="LEE JUN WEI",
                nric="150101-10-1234",
                id_number="N/A",
                gender="Male",
                dob="01/01/2015",
                relationship_to_settlor="CHILD",
                residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                email="N/A",
                contact_number="N/A",
                bank_account_name="N/A",
                bank_account_number="N/A",
                bank_name="N/A",
                bank_swift_code="N/A",
                bank_address="N/A",
                share_percentage="60%",
                beneficiary_type="post_demise",
            ),
            BeneficiaryData(
                full_name="LEE XIAO YI",
                nric="170303-14-5678",
                id_number="N/A",
                gender="Female",
                dob="03/03/2017",
                relationship_to_settlor="CHILD",
                residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
                email="N/A",
                contact_number="N/A",
                bank_account_name="N/A",
                bank_account_number="N/A",
                bank_name="N/A",
                bank_swift_code="N/A",
                bank_address="N/A",
                share_percentage="40%",
                beneficiary_type="post_demise",
            ),
        ],
        crs_residencies=[
            CrsTaxResidencyData(
                jurisdiction="Malaysia",
                tin_status="have_tin",
                tin="IG55012309",
                no_tin_reason="N/A",
                reason_b_explanation="N/A",
            ),
            CrsTaxResidencyData(
                jurisdiction="Singapore",
                tin_status="have_tin",
                tin="S1234567X",
                no_tin_reason="N/A",
                reason_b_explanation="N/A",
            ),
        ],
        crs_residencies_text="Malaysia (TIN: IG55012309), Singapore (TIN: S1234567X)",
        pep_declaration=PepDeclarationData(
            is_pep="No",
            pep_relationship="N/A",
            pep_name="N/A",
            pep_position="N/A",
            pep_organisation="N/A",
        ),
        digital_signature_key="N/A",
        advisor_name="N/A",
        advisor_nric="N/A",
        passport_expiry="N/A",
    )


async def main() -> None:
    data = make_lee_wei_kang()

    print("Generating A2 form for LEE WEI KANG...")
    pdf = build_form_a2(data)
    print(f"  Generated: {len(pdf)} bytes")

    # Save locally
    out_dir = Path(__file__).resolve().parent / "test_output"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "A2_LEE_WEI_KANG.pdf").write_bytes(pdf)
    print(f"  Saved to {out_dir / 'A2_LEE_WEI_KANG.pdf'}")

    # Email
    print("\nEmailing A2 form to fangkhai.foo@citadelgroup.com.my...")
    attachments = [
        {
            "form_id": "A2",
            "filename": "VTB_A2_LEE_WEI_KANG.pdf",
            "content_type": "application/pdf",
            "content_bytes": pdf,
        },
    ]
    await send_kyc_forms_email(
        to_email="fangkhai.foo@citadelgroup.com.my",
        client_name=data.name,
        attachments=attachments,
    )
    print("SUCCESS! A2 form emailed.")


if __name__ == "__main__":
    asyncio.run(main())