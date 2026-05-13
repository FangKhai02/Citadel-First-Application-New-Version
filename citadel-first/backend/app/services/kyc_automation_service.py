"""Automated KYC form generation and delivery triggered by trust order creation.

When a trust order is created (user purchases a Vanguard Trust Product),
this service assembles all KYC data, generates 6 PDF forms, uploads them
to S3, emails them to the configured internal address, and sends a status
notification email + in-app notification to the user.
"""

import logging

from sqlalchemy import select

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.user import AppUser
from app.models.user_details import UserDetails
from app.services.email_service import send_kyc_forms_email, send_trust_status_email
from app.services.s3_service import upload_bytes_to_s3
from app.services.vtb_form_data import KycFormDataError, assemble_kyc_form_data
from app.services.vtb_pdf_service import generate_all_vtb_pdfs

logger = logging.getLogger(__name__)

FORM_LABELS = {
    "A1": "Form A1 — Services Agreement",
    "A2": "Form A2 — Risk Assessment",
    "B2": "Form B2 — Application for Trustee Service",
    "B3": "Form B3 — Trust Deed (Individual)",
    "B4": "Form B4 — CRS Self-Certification",
    "B6": "Form B6 — Asset Allocation Direction",
}

STATUS_LABELS = {
    "PENDING": "Pending Review",
    "UNDER_REVIEW": "In Review",
    "APPROVED": "Approved",
    "REJECTED": "Rejected",
    "ACTIVE": "Active",
    "COMPLETED": "Completed",
    "DEFERRED": "Deferred",
}

STATUS_MESSAGES = {
    "PENDING": "Your trust application has been received and is currently pending review. We will get back to you as soon as it has been reviewed.",
    "UNDER_REVIEW": "Your trust application is now under review by our team. We will notify you once a decision has been made.",
    "APPROVED": "Congratulations! Your trust application has been approved. You may now proceed with the trust placement.",
    "REJECTED": "Your trust application was not approved. Please contact your advisor for more information.",
    "ACTIVE": "Your trust is now active. Thank you for choosing Citadel Wealth Diversification Trust.",
    "COMPLETED": "Your trust has been completed. Thank you for choosing Citadel Wealth Diversification Trust.",
    "DEFERRED": "Your trust application has been deferred. Additional information may be required — please check with your advisor.",
}

STATUS_NOTIFICATION_TYPES = {
    "PENDING": "info",
    "UNDER_REVIEW": "info",
    "APPROVED": "success",
    "REJECTED": "warning",
    "ACTIVE": "success",
    "COMPLETED": "success",
    "DEFERRED": "warning",
}


async def _get_user_email(db, app_user_id: int) -> str | None:
    """Get the user's email from user_details or app_users."""
    result = await db.execute(
        select(UserDetails.email).where(UserDetails.app_user_id == app_user_id)
    )
    email = result.scalar_one_or_none()
    if email and email != "N/A":
        return email
    result = await db.execute(
        select(AppUser.email_address).where(AppUser.id == app_user_id)
    )
    return result.scalar_one_or_none()


async def _get_user_name(db, app_user_id: int) -> str:
    """Get the user's name from user_details."""
    result = await db.execute(
        select(UserDetails.name).where(UserDetails.app_user_id == app_user_id)
    )
    name = result.scalar_one_or_none()
    return name or "Client"


async def generate_and_email_kyc_forms(
    app_user_id: int,
    trust_order_id: int,
) -> None:
    """Background task: assemble KYC data, generate PDFs, upload to S3, and email.

    Also sends a status notification email and in-app notification to the user.
    Creates its own database session since the request session will be closed
    by the time this background task runs. All exceptions are caught and logged
    so the trust order creation is never affected.
    """
    try:
        async with AsyncSessionLocal() as db:
            # 1. Assemble KYC data from all 5 tables
            try:
                data = await assemble_kyc_form_data(db, app_user_id, trust_order_id)
            except KycFormDataError as exc:
                logger.error(
                    "KYC automation skipped: missing data for user_id=%d order_id=%d: %s",
                    app_user_id, trust_order_id, exc,
                )
                return

            # 2. Fetch digital signature from S3
            signature_bytes = await _get_signature_bytes(db, app_user_id)

            # 3. Generate all 6 PDF forms
            pdfs = generate_all_vtb_pdfs(data, signature_bytes=signature_bytes)
            logger.info(
                "KYC automation: generated %d PDF forms for user_id=%d order_id=%d",
                len(pdfs), app_user_id, trust_order_id,
            )

            # 4. Upload each PDF to S3
            for form_id, pdf_bytes in pdfs.items():
                filename_suffix = (
                    FORM_LABELS[form_id]
                    .split(" — ")[1]
                    .replace(" ", "_")
                    .replace("(", "")
                    .replace(")", "")
                )
                s3_key = f"kyc-forms/{app_user_id}/{form_id}/{filename_suffix}.pdf"
                upload_bytes_to_s3(
                    key=s3_key, data=pdf_bytes, content_type="application/pdf"
                )
                logger.info(
                    "KYC automation: uploaded %s to S3 for user_id=%d",
                    form_id, app_user_id,
                )

            # 5. Email to configured internal address
            internal_email = settings.VTB_KYC_INTERNAL_EMAIL
            if internal_email:
                attachments = [
                    {
                        "form_id": form_id,
                        "filename": f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf",
                        "content_type": "application/pdf",
                        "content_bytes": pdf_bytes,
                    }
                    for form_id, pdf_bytes in pdfs.items()
                ]
                try:
                    await send_kyc_forms_email(
                        to_email=internal_email,
                        client_name=data.name,
                        attachments=attachments,
                    )
                    logger.info(
                        "KYC automation: emailed %d forms to %s for user_id=%d order_id=%d",
                        len(attachments), internal_email, app_user_id, trust_order_id,
                    )
                except Exception:
                    logger.exception("KYC automation: failed to email forms to internal address")
            else:
                logger.warning(
                    "VTB_KYC_INTERNAL_EMAIL not configured; skipping email for user_id=%d",
                    app_user_id,
                )

            # 6. Send status notification email + in-app notification to user
            await notify_trust_status(
                db=db,
                app_user_id=app_user_id,
                status="PENDING",
                trust_order_id=trust_order_id,
            )

            # 7. Submit to Lark Bitable (failure is logged but does not block email/S3)
            try:
                from app.services.lark_service import submit_kyc_to_lark

                await submit_kyc_to_lark(
                    data=data,
                    pdfs=pdfs,
                    trust_order_id=trust_order_id,
                )
            except Exception:
                logger.exception(
                    "Lark submission failed for order_id=%d; email and S3 uploads unaffected",
                    trust_order_id,
                )

    except Exception:
        logger.exception(
            "KYC automation failed unexpectedly for user_id=%d order_id=%d",
            app_user_id, trust_order_id,
        )


async def notify_trust_status(
    db,
    app_user_id: int,
    status: str,
    trust_order_id: int,
) -> None:
    """Send in-app notification and email to the user about their trust application status.

    Args:
        db: Async database session.
        app_user_id: The user's ID.
        status: The new case_status value (e.g., "PENDING", "APPROVED").
        trust_order_id: The trust order ID for reference.
    """
    status_label = STATUS_LABELS.get(status, status)
    message = STATUS_MESSAGES.get(status, f"Your trust application status has been updated to: {status_label}")
    notif_type = STATUS_NOTIFICATION_TYPES.get(status, "info")

    # In-app notification
    try:
        from app.api.v1.notifications import create_notification
        await create_notification(
            db=db,
            user_id=app_user_id,
            title=f"Trust Application — {status_label}",
            message=message,
            notif_type=notif_type,
        )
        logger.info(
            "Trust status notification created: user_id=%d status=%s order_id=%d",
            app_user_id, status, trust_order_id,
        )
    except Exception:
        logger.exception("Failed to create in-app notification for user_id=%d", app_user_id)

    # Email notification
    try:
        user_email = await _get_user_email(db, app_user_id)
        user_name = await _get_user_name(db, app_user_id)
        if user_email:
            extra_info = None
            show_contact_button = False
            if status == "PENDING":
                extra_info = "We will get back to you as soon as your application has been reviewed. Once approved, you may proceed with the trust placement."
            elif status == "APPROVED":
                extra_info = "You may now proceed with the trust placement."
            elif status == "REJECTED":
                extra_info = "Please contact our customer support team for more details about this decision."
                show_contact_button = True

            await send_trust_status_email(
                to_email=user_email,
                client_name=user_name,
                status_label=status_label,
                message=message,
                extra_info=extra_info,
                show_contact_button=show_contact_button,
            )
            logger.info(
                "Trust status email sent to %s for user_id=%d status=%s",
                user_email, app_user_id, status,
            )
        else:
            logger.warning("No email found for user_id=%d; skipping status email", app_user_id)
    except Exception:
        logger.exception("Failed to send status email for user_id=%d", app_user_id)


async def _get_signature_bytes(db, app_user_id: int) -> bytes | None:
    """Fetch the user's digital signature from S3 if available."""
    from app.api.v1.vtb_kyc import _get_signature_bytes as _fetch_sig
    return await _fetch_sig(db, app_user_id)