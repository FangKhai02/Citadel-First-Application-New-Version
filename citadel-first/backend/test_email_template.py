"""Quick test: send a KYC forms email with the updated light theme template."""

import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from app.services.email_service import send_kyc_forms_email


async def main() -> None:
    attachments = [
        {
            "form_id": "A1",
            "filename": "VTB_A1_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",  # Placeholder — won't be a valid PDF but tests email formatting
        },
    ]
    await send_kyc_forms_email(
        to_email="fangkhai.foo@citadelgroup.com.my",
        client_name="LEE WEI KANG",
        attachments=attachments,
    )
    print("Email sent! Check your inbox for the updated template.")


if __name__ == "__main__":
    asyncio.run(main())