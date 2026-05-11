"""Quick test: send a KYC forms email with the Outlook-compatible template."""

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
            "content_bytes": b"test",
        },
        {
            "form_id": "A2",
            "filename": "VTB_A2_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",
        },
        {
            "form_id": "B2",
            "filename": "VTB_B2_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",
        },
        {
            "form_id": "B3",
            "filename": "VTB_B3_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",
        },
        {
            "form_id": "B4",
            "filename": "VTB_B4_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",
        },
        {
            "form_id": "B6",
            "filename": "VTB_B6_TEST.pdf",
            "content_type": "application/pdf",
            "content_bytes": b"test",
        },
    ]
    await send_kyc_forms_email(
        to_email="fangkhai.foo@citadelgroup.com.my",
        client_name="LEE WEI KANG",
        attachments=attachments,
    )
    print("Email sent! Check both Outlook and mobile.")


if __name__ == "__main__":
    asyncio.run(main())