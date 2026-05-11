"""One-time script to create a test user with realistic Malaysian data
across all tables, generate all 6 VTB KYC form PDFs, and email them
to fangkhai.foo@citadelgroup.com.my for validation.

Usage:
    cd backend
    python seed_kyc_test_data.py

This script:
1. Creates an AppUser + UserDetails row
2. Creates CRS tax residency rows (Malaysia + Singapore)
3. Creates a PEP declaration (not a PEP)
4. Creates pre-demise and post-demise beneficiaries
5. Creates a trust order (RM 1,000,000)
6. Generates all 6 VTB KYC form PDFs
7. Uploads PDFs to S3
8. Emails PDFs to the validation address
"""

import asyncio
import sys
from datetime import date
from pathlib import Path

# Ensure project root is on the path
sys.path.insert(0, str(Path(__file__).resolve().parent))

from decimal import Decimal


async def main() -> None:
    from app.core.database import AsyncSessionLocal
    from app.models.user import AppUser
    from app.models.user_details import UserDetails
    from app.models.crs_tax_residency import CrsTaxResidency
    from app.models.pep_declaration import PepDeclaration
    from app.models.beneficiary import Beneficiary
    from app.models.trust_order import TrustOrder
    from app.services.vtb_form_data import assemble_kyc_form_data
    from app.services.vtb_pdf_service import generate_all_vtb_pdfs
    from app.services.vtb_form_data import NA
    from app.services.s3_service import upload_bytes_to_s3
    from app.services.email_service import send_kyc_forms_email

    async with AsyncSessionLocal() as db:
        # ── 1. Create AppUser ──
        from sqlalchemy import select

        # Check if test user already exists
        existing = await db.execute(
            select(AppUser).where(AppUser.email_address == "lee.weikang@test.com.my")
        )
        app_user = existing.scalar_one_or_none()

        if app_user is None:
            from app.core.security import hash_password
            from datetime import datetime, timezone, timedelta
            app_user = AppUser(
                email_address="lee.weikang@test.com.my",
                password=hash_password("Test@1234"),
                user_type="CLIENT",
                email_verified_at=datetime(2026, 4, 1, tzinfo=timezone(timedelta(hours=8))),
            )
            db.add(app_user)
            await db.flush()
            print(f"Created AppUser id={app_user.id}")
        else:
            print(f"AppUser already exists id={app_user.id}")

        user_id = app_user.id

        # ── 2. Create/Update UserDetails ──
        existing_ud = await db.execute(
            select(UserDetails).where(UserDetails.app_user_id == user_id)
        )
        ud = existing_ud.scalar_one_or_none()

        if ud is None:
            ud = UserDetails(app_user_id=user_id)
            db.add(ud)
            await db.flush()
            print(f"Created UserDetails id={ud.id}")

        # Update with test data
        ud.name = "LEE WEI KANG"
        ud.identity_card_number = "900101-10-5678"
        ud.identity_doc_type = "MYKAD"
        ud.title = "Mr"
        ud.dob = date(1990, 1, 1)
        ud.gender = "Male"
        ud.nationality = "Malaysian"
        ud.marital_status = "Single"
        ud.residential_address = "12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia"
        ud.mailing_address = "12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia"
        ud.mailing_same_as_residential = True
        ud.home_telephone = "03-2694 1888"
        ud.mobile_number = "+6012-345 6789"
        ud.email = "lee.weikang@test.com.my"
        ud.employment_type = "Employed"
        ud.occupation = "Senior Analyst"
        ud.work_title = "Senior Analyst"
        ud.nature_of_business = "Financial Services"
        ud.employer_name = "Citadel Group Sdn. Bhd."
        ud.employer_address = "Level 8, Menara MAA, 12, Jalan Meru, 55100 Kuala Lumpur"
        ud.employer_telephone = "03-2694 1888"
        ud.annual_income_range = "RM100,001 - RM250,000"
        ud.estimated_net_worth = "RM500,001 - RM1,000,000"
        ud.source_of_trust_fund = "Salary"
        ud.source_of_income = "Employment"
        ud.country_of_birth = "Malaysia"
        ud.physically_present = True
        ud.main_sources_of_income = "Employment salary"
        ud.has_unusual_transactions = False
        ud.marital_history = "Single, never married"
        ud.geographical_connections = "None"
        ud.other_relevant_info = "None"
        await db.flush()

        # ── 3. Create CRS Tax Residency ──
        # Clear existing
        existing_crs = await db.execute(
            select(CrsTaxResidency).where(CrsTaxResidency.app_user_id == user_id)
        )
        for row in existing_crs.scalars().all():
            await db.delete(row)
        await db.flush()

        crs_malaysia = CrsTaxResidency(
            app_user_id=user_id,
            jurisdiction="Malaysia",
            tin_status="have_tin",
            tin="IG55012309",
        )
        crs_singapore = CrsTaxResidency(
            app_user_id=user_id,
            jurisdiction="Singapore",
            tin_status="have_tin",
            tin="S1234567X",
        )
        db.add(crs_malaysia)
        db.add(crs_singapore)
        await db.flush()
        print(f"Created CRS rows: Malaysia, Singapore")

        # ── 4. Create PEP Declaration ──
        existing_pep = await db.execute(
            select(PepDeclaration).where(PepDeclaration.app_user_id == user_id)
        )
        pep = existing_pep.scalar_one_or_none()

        if pep is None:
            pep = PepDeclaration(app_user_id=user_id, is_pep=False)
            db.add(pep)
            await db.flush()
            print(f"Created PEP declaration id={pep.id}")
        else:
            pep.is_pep = False
            pep.pep_relationship = None
            pep.pep_name = None
            pep.pep_position = None
            pep.pep_organisation = None
            await db.flush()
            print(f"Updated PEP declaration id={pep.id}")

        # ── 5. Create Beneficiaries ──
        # Clear existing
        existing_ben = await db.execute(
            select(Beneficiary).where(Beneficiary.app_user_id == user_id)
        )
        for row in existing_ben.scalars().all():
            await db.delete(row)
        await db.flush()

        # Pre-demise: Spouse
        ben_pre = Beneficiary(
            app_user_id=user_id,
            beneficiary_type="pre_demise",
            same_as_settlor=False,
            full_name="LIM MEI LING",
            nric="920505-14-5678",
            id_number=None,
            gender="Female",
            dob=date(1992, 5, 5),
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
            share_percentage=Decimal("100.00"),
        )
        # Post-demise: Child 1
        ben_post_1 = Beneficiary(
            app_user_id=user_id,
            beneficiary_type="post_demise",
            same_as_settlor=False,
            full_name="LEE JUN WEI",
            nric="150101-10-1234",
            id_number=None,
            gender="Male",
            dob=date(2015, 1, 1),
            relationship_to_settlor="CHILD",
            residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
            mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
            share_percentage=Decimal("60.00"),
        )
        # Post-demise: Child 2
        ben_post_2 = Beneficiary(
            app_user_id=user_id,
            beneficiary_type="post_demise",
            same_as_settlor=False,
            full_name="LEE XIAO YI",
            nric="170303-14-5678",
            id_number=None,
            gender="Female",
            dob=date(2017, 3, 3),
            relationship_to_settlor="CHILD",
            residential_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
            mailing_address="12, Jalan Ampang, 55000 Kuala Lumpur, Malaysia",
            share_percentage=Decimal("40.00"),
        )
        db.add(ben_pre)
        db.add(ben_post_1)
        db.add(ben_post_2)
        await db.flush()
        print("Created 3 beneficiaries (1 pre-demise, 2 post-demise)")

        # ── 6. Create Trust Order ──
        existing_to = await db.execute(
            select(TrustOrder).where(TrustOrder.app_user_id == user_id)
        )
        trust_order = existing_to.scalar_one_or_none()

        if trust_order is None:
            trust_order = TrustOrder(
                app_user_id=user_id,
                date_of_trust_deed=date(2026, 4, 1),
                trust_asset_amount=Decimal("1000000.00"),
                advisor_name=None,
                advisor_nric=None,
                case_status="PENDING",
            )
            db.add(trust_order)
            await db.flush()
            print(f"Created TrustOrder id={trust_order.id}")
        else:
            trust_order.date_of_trust_deed = date(2026, 4, 1)
            trust_order.trust_asset_amount = Decimal("1000000.00")
            await db.flush()
            print(f"Updated TrustOrder id={trust_order.id}")

        await db.commit()
        print(f"\nAll test data committed for user_id={user_id}")

        # ── 7. Generate PDFs ──
        print("\nGenerating VTB KYC form PDFs...")
        data = await assemble_kyc_form_data(db, user_id, trust_order.id)

        # Fetch signature from S3 if available
        sig_bytes = None
        if ud.digital_signature_key:
            try:
                from app.services.s3_service import download_object_bytes
                sig_bytes = download_object_bytes(ud.digital_signature_key)
                print(f"  Downloaded signature: {len(sig_bytes)} bytes")
            except Exception as e:
                print(f"  WARNING: Failed to download signature: {e}")
                sig_bytes = None

        pdfs = generate_all_vtb_pdfs(data, signature_bytes=sig_bytes)

        # ── 8. Upload to S3 ──
        print("\nUploading PDFs to S3...")
        for form_id, pdf_bytes in pdfs.items():
            s3_key = f"kyc-forms/{user_id}/{form_id}/VTB_{form_id}.pdf"
            upload_bytes_to_s3(key=s3_key, data=pdf_bytes, content_type="application/pdf")
            print(f"  Uploaded {form_id}: s3_key={s3_key} ({len(pdf_bytes)} bytes)")

        # ── 9. Email PDFs ──
        print("\nEmailing PDFs to fangkhai.foo@citadelgroup.com.my...")
        form_labels = {
            "A1": "Form A1 — Services Agreement",
            "A2": "Form A2 — Risk Assessment",
            "B2": "Form B2 — Application for Trustee Service",
            "B3": "Form B3 — Trust Deed (Individual)",
            "B4": "Form B4 — CRS Self-Certification",
            "B6": "Form B6 — Asset Allocation Direction",
        }
        attachments = []
        for form_id, pdf_bytes in pdfs.items():
            attachments.append({
                "form_id": form_id,
                "filename": f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf",
                "content_type": "application/pdf",
                "content_bytes": pdf_bytes,
            })

        await send_kyc_forms_email(
            to_email="fangkhai.foo@citadelgroup.com.my",
            client_name=data.name,
            attachments=attachments,
        )
        print("\nSUCCESS! All 6 PDFs generated, uploaded to S3, and emailed.")


if __name__ == "__main__":
    asyncio.run(main())