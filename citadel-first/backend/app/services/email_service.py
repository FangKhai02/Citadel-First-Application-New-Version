import logging
from pathlib import Path

import httpx
from jinja2 import Environment, FileSystemLoader

from app.core.config import settings

logger = logging.getLogger(__name__)

_TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates"

_jinja_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=True,
)


def _logo_url() -> str:
    return f"{settings.BACKEND_URL}/static/citadel-logo.png"


async def send_verification_email(to_email: str, token: str) -> None:
    verification_url = (
        f"{settings.BACKEND_URL}/api/v1/auth/verify-email?token={token}"
    )

    template = _jinja_env.get_template("verification_email.html")
    html_body = template.render(
        verification_url=verification_url,
        logo_url=_logo_url(),
    )

    payload = {
        "from": settings.EMAIL_FROM,
        "to": [to_email],
        "subject": "Citadel — Verify Your Email",
        "html": html_body,
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                json=payload,
                headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
            response.raise_for_status()
            logger.info("Verification email sent to %s (resend_id=%s)", to_email, response.json().get("id"))
    except httpx.HTTPStatusError as exc:
        logger.exception("Resend API error sending to %s: %s", to_email, exc.response.text)
        raise
    except Exception:
        logger.exception("Failed to send verification email to %s", to_email)
        raise


async def send_kyc_forms_email(
    to_email: str,
    client_name: str,
    attachments: list[dict],
) -> None:
    """Send KYC forms email with PDF attachments via Resend API.

    Args:
        to_email: Recipient email address.
        client_name: Client name for personalization.
        attachments: List of dicts with keys: filename, content_type, content_bytes (bytes).
    """
    import base64

    form_labels = {
        "A1": "Form A1 — Services Agreement",
        "A2": "Form A2 — Risk Assessment",
        "B2": "Form B2 — Application for Trustee Service",
        "B3": "Form B3 — Trust Deed (Individual)",
        "B4": "Form B4 — CRS Self-Certification",
        "B6": "Form B6 — Asset Allocation Direction",
    }

    template = _jinja_env.get_template("vtb_kyc_email.html")
    forms_list = [
        {"label": form_labels.get(a["form_id"], a["form_id"]), "filename": a["filename"]}
        for a in attachments
    ]
    html_body = template.render(
        client_name=client_name,
        forms=forms_list,
        logo_url=_logo_url(),
    )

    # Encode attachments as base64 for Resend API
    resend_attachments = []
    for att in attachments:
        b64_content = base64.b64encode(att["content_bytes"]).decode("utf-8")
        resend_attachments.append({
            "filename": att["filename"],
            "content_type": att["content_type"],
            "content": b64_content,
        })

    payload = {
        "from": settings.EMAIL_FROM,
        "to": [to_email],
        "subject": f"VTB KYC Forms — {client_name}",
        "html": html_body,
        "attachments": resend_attachments,
    }

    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                json=payload,
                headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
            response.raise_for_status()
            logger.info(
                "KYC forms email sent to %s (resend_id=%s, %d attachments)",
                to_email, response.json().get("id"), len(resend_attachments),
            )
    except httpx.HTTPStatusError as exc:
        logger.exception("Resend API error sending KYC forms to %s: %s", to_email, exc.response.text)
        raise
    except Exception:
        logger.exception("Failed to send KYC forms email to %s", to_email)
        raise


async def send_trust_status_email(
    to_email: str,
    client_name: str,
    status_label: str,
    message: str,
    extra_info: str | None = None,
    show_contact_button: bool = False,
) -> None:
    """Send a trust application status update email to the user.

    Args:
        to_email: Recipient email address (the user).
        client_name: Client name for personalization.
        status_label: Human-readable status label (e.g., "Pending Review").
        message: Main body message.
        extra_info: Optional additional info (e.g., next steps).
        show_contact_button: Show "Contact Customer Support" button (for REJECTED).
    """
    template = _jinja_env.get_template("trust_status_email.html")
    html_body = template.render(
        client_name=client_name,
        status_label=status_label,
        message=message,
        extra_info=extra_info or "",
        show_contact_button=show_contact_button,
    )

    payload = {
        "from": settings.EMAIL_FROM,
        "to": [to_email],
        "subject": f"Trust Application Update — {status_label}",
        "html": html_body,
    }

    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(
                "https://api.resend.com/emails",
                json=payload,
                headers={
                    "Authorization": f"Bearer {settings.RESEND_API_KEY}",
                    "Content-Type": "application/json",
                },
            )
            response.raise_for_status()
            logger.info(
                "Trust status email sent to %s (status=%s, resend_id=%s)",
                to_email, status_label, response.json().get("id"),
            )
    except Exception:
        logger.exception("Failed to send trust status email to %s", to_email)
        raise