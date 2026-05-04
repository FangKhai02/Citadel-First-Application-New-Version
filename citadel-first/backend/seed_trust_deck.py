"""One-time script to upload the CWD Trust Deck PDF to S3.

Usage:
    cd backend
    python seed_trust_deck.py <path_to_pdf>
    # Or set TRUST_DECK_PDF_PATH env var

This uploads the PDF to S3 at:
    trust-products/cwd-trust-deck.pdf

After running successfully, you do NOT need to run this again.
"""

import os
import sys
from pathlib import Path

from app.core.config import settings
from app.services.s3_service import upload_bytes_to_s3

S3_KEY = "trust-products/cwd-trust-deck.pdf"

# Use command-line argument or environment variable for the PDF path
DEFAULT_PDF = os.environ.get("TRUST_DECK_PDF_PATH", "")
PDF_PATH = Path(sys.argv[1]) if len(sys.argv) > 1 else (Path(DEFAULT_PDF) if DEFAULT_PDF else None)


def main() -> None:
    if not PDF_PATH or not PDF_PATH.exists():
        print("ERROR: PDF path not provided. Usage: python seed_trust_deck.py <path_to_pdf>")
        print("   Or set TRUST_DECK_PDF_PATH environment variable.")
        sys.exit(1)

    print(f"Reading {PDF_PATH.name} ({PDF_PATH.stat().st_size / 1024:.0f} KB)...")
    data = PDF_PATH.read_bytes()

    print(f"Uploading to S3 key: {S3_KEY}")
    print(f"Bucket: {settings.AWS_S3_BUCKET}")
    print(f"Region: {settings.AWS_REGION}")

    key = upload_bytes_to_s3(key=S3_KEY, data=data, content_type="application/pdf")
    print(f"SUCCESS! Uploaded to S3 key: {key}")
    print("\nThe PDF is now available via the /trust-orders/products/cwd-deck-url endpoint.")


if __name__ == "__main__":
    main()