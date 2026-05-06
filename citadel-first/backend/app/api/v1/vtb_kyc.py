"""VTB KYC form generation and delivery endpoints.

Provides endpoints to:
- Generate 6 VTB KYC form PDFs (A1, A2, B2, B3, B4, B6) with auto-populated data
- Upload PDFs to S3 and return presigned download URLs
- Generate and email PDFs to a specified address
"""

import asyncio
import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.database import get_db
from app.models.user_details import UserDetails
from app.schemas.vtb_kyc import (
    KycFormsGenerateRequest,
    KycFormsGenerateResponse,
    KycFormResult,
)
from app.services.email_service import send_kyc_forms_email
from app.services.s3_service import download_object_bytes, upload_bytes_to_s3
from app.services.vtb_form_data import KycFormDataError, assemble_kyc_form_data
from app.services.vtb_pdf_service import FORM_BUILDERS, generate_all_vtb_pdfs
from sqlalchemy import select

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/kyc-forms", tags=["KYC Forms"])

FORM_LABELS = {
    "A1": "Form A1 — Services Agreement",
    "A2": "Form A2 — Risk Assessment",
    "B2": "Form B2 — Application for Trustee Service",
    "B3": "Form B3 — Trust Deed (Individual)",
    "B4": "Form B4 — CRS Self-Certification",
    "B6": "Form B6 — Asset Allocation Direction",
}


async def _get_signature_bytes(db: AsyncSession, app_user_id: int) -> bytes | None:
    """Fetch the user's digital signature from S3 if available."""
    result = await db.execute(
        select(UserDetails.digital_signature_key).where(
            UserDetails.app_user_id == app_user_id
        )
    )
    sig_key = result.scalar_one_or_none()
    if not sig_key:
        return None
    try:
        return await asyncio.to_thread(download_object_bytes, sig_key)
    except Exception:
        logger.warning("Failed to download signature for user_id=%d", app_user_id)
        return None


@router.post("/generate", response_model=KycFormsGenerateResponse)
async def generate_kyc_forms(
    request: KycFormsGenerateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Generate all 6 VTB KYC form PDFs, upload to S3, and return download URLs."""
    try:
        data = await assemble_kyc_form_data(db, request.app_user_id, request.trust_order_id)
    except KycFormDataError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    signature_bytes = await _get_signature_bytes(db, request.app_user_id)
    pdfs = generate_all_vtb_pdfs(data, signature_bytes=signature_bytes)

    results: list[KycFormResult] = []
    for form_id, pdf_bytes in pdfs.items():
        s3_key = f"kyc-forms/{request.app_user_id}/{form_id}/{FORM_LABELS[form_id].split(' — ')[1].replace(' ', '_').replace('(', '').replace(')', '')}.pdf"
        upload_bytes_to_s3(key=s3_key, data=pdf_bytes, content_type="application/pdf")
        results.append(KycFormResult(
            form_id=form_id,
            s3_key=s3_key,
            filename=f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf",
        ))

    return KycFormsGenerateResponse(forms=results)


@router.post("/generate-and-email", response_model=KycFormsGenerateResponse)
async def generate_and_email_kyc_forms(
    request: KycFormsGenerateRequest,
    db: AsyncSession = Depends(get_db),
):
    """Generate all 6 VTB KYC form PDFs, upload to S3, and email them."""
    try:
        data = await assemble_kyc_form_data(db, request.app_user_id, request.trust_order_id)
    except KycFormDataError as exc:
        raise HTTPException(status_code=404, detail=str(exc))

    signature_bytes = await _get_signature_bytes(db, request.app_user_id)
    pdfs = generate_all_vtb_pdfs(data, signature_bytes=signature_bytes)

    # Upload to S3
    results: list[KycFormResult] = []
    for form_id, pdf_bytes in pdfs.items():
        s3_key = f"kyc-forms/{request.app_user_id}/{form_id}/{FORM_LABELS[form_id].split(' — ')[1].replace(' ', '_').replace('(', '').replace(')', '')}.pdf"
        upload_bytes_to_s3(key=s3_key, data=pdf_bytes, content_type="application/pdf")
        results.append(KycFormResult(
            form_id=form_id,
            s3_key=s3_key,
            filename=f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf",
        ))

    # Send email with attachments
    email = request.email if request.email else data.email
    if email == "N/A":
        email = settings.EMAIL_FROM  # Fallback

    attachments = []
    for form_id, pdf_bytes in pdfs.items():
        attachments.append({
            "form_id": form_id,
            "filename": f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf",
            "content_type": "application/pdf",
            "content_bytes": pdf_bytes,
        })

    try:
        await send_kyc_forms_email(
            to_email=email,
            client_name=data.name,
            attachments=attachments,
        )
    except Exception:
        logger.exception("Failed to send KYC forms email to %s", email)
        # Don't fail the whole request — PDFs are still uploaded to S3

    return KycFormsGenerateResponse(forms=results)