"""Generate two A1 forms (LEE WEI KANG + AHMAD BIN ISHAK) with signatures
and email both to fangkhai.foo@citadelgroup.com.my for validation.

Usage:
    cd backend
    python test_a1_forms.py
"""

import asyncio
import sys
from datetime import date
from io import BytesIO
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.schemas.vtb_kyc import (
    VtbKycFormData,
    BeneficiaryData,
    CrsTaxResidencyData,
    PepDeclarationData,
)
from app.services.vtb_pdf_service import build_form_a1
from app.services.email_service import send_kyc_forms_email


def _generate_signature_png(name: str) -> bytes:
    """Generate a simple handwritten-style signature PNG for testing."""
    from PIL import Image, ImageDraw

    img = Image.new("RGBA", (300, 50), (255, 255, 255, 0))
    draw = ImageDraw.Draw(img)

    # Draw a cursive-style signature curve (no name text)
    draw.line([(20, 35), (50, 15), (80, 38), (120, 18), (160, 32), (200, 20), (240, 35)], fill=(0, 0, 50), width=2)
    # Underline flourish
    draw.line([(100, 38), (200, 38)], fill=(0, 0, 50), width=1)

    buf = BytesIO()
    img.save(buf, format="PNG")
    return buf.getvalue()


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


def make_ahmad_bin_ishak() -> VtbKycFormData:
    return VtbKycFormData(
        name="AHMAD BIN ISHAK",
        identity_card_number="850615-14-5432",
        identity_doc_type="MYKAD",
        title="Mr",
        dob="15/06/1985",
        gender="Male",
        nationality="Malaysian",
        marital_status="Married",
        residential_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
        mailing_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
        home_telephone="03-7876 5432",
        mobile_number="+6019-876 5432",
        email="ahmad.ishak@example.com.my",
        employment_type="Self-Employed",
        occupation="Business Owner",
        work_title="Managing Director",
        nature_of_business="Property Development",
        employer_name="Ishak Properties Sdn. Bhd.",
        employer_address="22, Persiaran Surian, 47810 Petaling Jaya, Selangor",
        employer_telephone="03-7876 5400",
        annual_income_range="RM250,001 - RM500,000",
        estimated_net_worth="RM1,000,001 - RM5,000,000",
        source_of_trust_fund="Business income",
        source_of_income="Self-employment",
        country_of_birth="Malaysia",
        physically_present="Yes",
        main_sources_of_income="Business profits and rental income",
        has_unusual_transactions="No",
        marital_history="Married with 3 children",
        geographical_connections="Malaysia and Singapore",
        other_relevant_info="None",
        date_of_trust_deed="15/03/2026",
        trust_asset_amount="RM 2,500,000.00",
        pre_demise_beneficiaries=[
            BeneficiaryData(
                full_name="NOR AIN BINTI MOHAMED",
                nric="880822-14-6789",
                id_number="N/A",
                gender="Female",
                dob="22/08/1988",
                relationship_to_settlor="SPOUSE",
                residential_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                mailing_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                email="nor.ain@example.com.my",
                contact_number="+6012-345 6789",
                bank_account_name="NOR AIN BINTI MOHAMED",
                bank_account_number="987654321098",
                bank_name="CIMB Bank Berhad",
                bank_swift_code="CIBBMYKL",
                bank_address="CIMB Tower, Kuala Lumpur",
                share_percentage="100%",
                beneficiary_type="pre_demise",
            ),
        ],
        post_demise_beneficiaries=[
            BeneficiaryData(
                full_name="AHMAD AMIR",
                nric="110505-10-4321",
                id_number="N/A",
                gender="Male",
                dob="05/05/2011",
                relationship_to_settlor="CHILD",
                residential_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                mailing_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                email="N/A",
                contact_number="N/A",
                bank_account_name="N/A",
                bank_account_number="N/A",
                bank_name="N/A",
                bank_swift_code="N/A",
                bank_address="N/A",
                share_percentage="50%",
                beneficiary_type="post_demise",
            ),
            BeneficiaryData(
                full_name="AHMAD SURI",
                nric="130808-14-3210",
                id_number="N/A",
                gender="Female",
                dob="08/08/2013",
                relationship_to_settlor="CHILD",
                residential_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                mailing_address="45, Jalan SS 2/24, 47300 Petaling Jaya, Selangor",
                email="N/A",
                contact_number="N/A",
                bank_account_name="N/A",
                bank_account_number="N/A",
                bank_name="N/A",
                bank_swift_code="N/A",
                bank_address="N/A",
                share_percentage="50%",
                beneficiary_type="post_demise",
            ),
        ],
        crs_residencies=[
            CrsTaxResidencyData(
                jurisdiction="Malaysia",
                tin_status="have_tin",
                tin="IG88061514",
                no_tin_reason="N/A",
                reason_b_explanation="N/A",
            ),
        ],
        crs_residencies_text="Malaysia (TIN: IG88061514)",
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
    data1 = make_lee_wei_kang()
    data2 = make_ahmad_bin_ishak()

    # Generate test signature PNGs
    sig1_bytes = _generate_signature_png("LEE WEI KANG")
    sig2_bytes = _generate_signature_png("AHMAD BIN ISHAK")

    print("Generating A1 form for LEE WEI KANG...")
    pdf1 = build_form_a1(data1, signature_bytes=sig1_bytes)
    print(f"  Generated: {len(pdf1)} bytes")

    print("Generating A1 form for AHMAD BIN ISHAK...")
    pdf2 = build_form_a1(data2, signature_bytes=sig2_bytes)
    print(f"  Generated: {len(pdf2)} bytes")

    # Save locally for quick verification
    out_dir = Path(__file__).resolve().parent / "test_output"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "A1_LEE_WEI_KANG.pdf").write_bytes(pdf1)
    (out_dir / "A1_AHMAD_BIN_ISHAK.pdf").write_bytes(pdf2)
    print(f"\nSaved locally to {out_dir}/")

    # Email both forms
    print("\nEmailing both A1 forms to fangkhai.foo@citadelgroup.com.my...")
    attachments = [
        {
            "form_id": "A1",
            "filename": f"VTB_A1_{data1.name.replace(' ', '_')}.pdf",
            "content_type": "application/pdf",
            "content_bytes": pdf1,
        },
        {
            "form_id": "A1",
            "filename": f"VTB_A1_{data2.name.replace(' ', '_')}.pdf",
            "content_type": "application/pdf",
            "content_bytes": pdf2,
        },
    ]
    await send_kyc_forms_email(
        to_email="fangkhai.foo@citadelgroup.com.my",
        client_name=f"{data1.name} & {data2.name}",
        attachments=attachments,
    )
    print("SUCCESS! Both A1 forms emailed.")


if __name__ == "__main__":
    asyncio.run(main())