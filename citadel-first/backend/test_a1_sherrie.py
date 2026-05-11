"""Generate A1 form for Sherrie (user_id=52) using her real data and signature
from the database and S3, then email it for validation.

Usage:
    cd backend
    python test_a1_sherrie.py
"""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))


async def main() -> None:
    from app.core.database import AsyncSessionLocal
    from app.models.user import AppUser
    from app.models.user_details import UserDetails
    from app.models.trust_order import TrustOrder
    from app.models.beneficiary import Beneficiary
    from app.models.crs_tax_residency import CrsTaxResidency
    from app.models.pep_declaration import PepDeclaration
    from app.services.vtb_form_data import assemble_kyc_form_data, NA, na_date, na_currency
    from app.services.vtb_pdf_service import build_form_a1
    from app.services.s3_service import download_object_bytes
    from app.services.email_service import send_kyc_forms_email
    from app.schemas.vtb_kyc import VtbKycFormData, PepDeclarationData
    from sqlalchemy import select

    async with AsyncSessionLocal() as db:
        user_id = 52

        # Get user details
        result = await db.execute(select(UserDetails).where(UserDetails.app_user_id == user_id))
        ud = result.scalar_one_or_none()
        if not ud:
            print("ERROR: UserDetails not found for user_id=52")
            return

        # Get trust order (may not exist)
        result = await db.execute(select(TrustOrder).where(TrustOrder.app_user_id == user_id))
        to = result.scalar_one_or_none()

        # Download signature from S3
        sig_bytes = None
        if ud.digital_signature_key:
            try:
                print(f"Downloading signature from S3: {ud.digital_signature_key}")
                sig_bytes = download_object_bytes(ud.digital_signature_key)
                print(f"  Downloaded: {len(sig_bytes)} bytes")
            except Exception as e:
                print(f"  WARNING: Failed to download signature: {e}")
                sig_bytes = None

        # Build form data using the same assembly logic
        data = await assemble_kyc_form_data(db, user_id, to.id if to else None)

        print(f"\nAssembled data for: {data.name}")
        print(f"  IC: {data.identity_card_number}")
        print(f"  Mobile: {data.mobile_number}")
        print(f"  Address: {data.residential_address}")
        print(f"  Signature: {'Yes' if sig_bytes else 'No'}")

        # Generate A1 form
        print("\nGenerating A1 form for SHERRIE...")
        pdf = build_form_a1(data, signature_bytes=sig_bytes)
        print(f"  Generated: {len(pdf)} bytes")

        # Save locally
        out_dir = Path(__file__).resolve().parent / "test_output"
        out_dir.mkdir(exist_ok=True)
        filename = f"A1_{data.name.replace(' ', '_')}.pdf"
        (out_dir / filename).write_bytes(pdf)
        print(f"  Saved to {out_dir / filename}")

        # Email
        print("\nEmailing A1 form to fangkhai.foo@citadelgroup.com.my...")
        attachments = [
            {
                "form_id": "A1",
                "filename": f"VTB_{filename}",
                "content_type": "application/pdf",
                "content_bytes": pdf,
            },
        ]
        await send_kyc_forms_email(
            to_email="fangkhai.foo@citadelgroup.com.my",
            client_name=data.name,
            attachments=attachments,
        )
        print("SUCCESS! A1 form emailed.")


if __name__ == "__main__":
    asyncio.run(main())