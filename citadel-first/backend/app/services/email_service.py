import logging

import httpx
from jinja2 import Environment, FileSystemLoader

from app.core.config import settings

logger = logging.getLogger(__name__)

_jinja_env = Environment(
    loader=FileSystemLoader("app/templates"),
    autoescape=True,
)


async def send_verification_email(to_email: str, token: str) -> None:
    verification_url = (
        f"{settings.BACKEND_URL}/api/v1/auth/verify-email?token={token}"
    )

    template = _jinja_env.get_template("verification_email.html")
    html_body = template.render(verification_url=verification_url)

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