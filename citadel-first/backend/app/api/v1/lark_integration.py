"""Lark integration endpoints — manual retry for failed submissions."""

import logging

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.models.trust_order import TrustOrder
from app.models.user import AppUser
from app.api.v1.users import get_current_user
from app.services.lark_service import _is_configured, submit_kyc_to_lark
from app.services.vtb_form_data import KycFormDataError, assemble_kyc_form_data
from app.services.vtb_pdf_service import generate_all_vtb_pdfs
from app.services.s3_service import download_object_bytes

logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/lark/retry/{order_id}")
async def retry_lark_submission(
    order_id: int,
    current_user: AppUser = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Manually retry a failed Lark submission for a trust order.

    Only works when lark_submission_status is "FAILED".
    Re-assembles KYC data, re-generates PDFs, and calls submit_kyc_to_lark
    which will resume from the last successful step.
    """
    if not _is_configured():
        raise HTTPException(status_code=503, detail="Lark integration is not configured")

    # Fetch trust order
    result = await db.execute(
        select(TrustOrder).where(
            TrustOrder.id == order_id,
            TrustOrder.app_user_id == current_user.id,
            TrustOrder.is_deleted == False,
        )
    )
    order = result.scalar_one_or_none()
    if not order:
        raise HTTPException(status_code=404, detail="Trust order not found")

    # Only allow retry for failed submissions
    if order.lark_submission_status not in ("FAILED", None, "PENDING"):
        raise HTTPException(
            status_code=400,
            detail=f"Cannot retry: current status is '{order.lark_submission_status}'",
        )

    try:
        data = await assemble_kyc_form_data(db, current_user.id, order_id)
    except KycFormDataError as exc:
        raise HTTPException(status_code=422, detail=f"KYC data incomplete: {exc}")

    # Fetch digital signature
    signature_bytes = None
    if data.digital_signature_key and data.digital_signature_key != "N/A":
        try:
            signature_bytes = await download_object_bytes(data.digital_signature_key)
        except Exception:
            logger.exception("Failed to download signature for Lark retry")

    pdfs = generate_all_vtb_pdfs(data, signature_bytes=signature_bytes)

    try:
        await submit_kyc_to_lark(data=data, pdfs=pdfs, trust_order_id=order_id)
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Lark submission failed after retries: {str(exc)[:200]}",
        )

    # Refresh order from DB to get updated status
    await db.refresh(order)
    return {
        "order_id": order.id,
        "lark_submission_status": order.lark_submission_status,
        "lark_trust_record_id": order.lark_trust_record_id,
        "lark_submitted_at": order.lark_submitted_at.isoformat() if order.lark_submitted_at else None,
        "lark_error_message": order.lark_error_message,
    }