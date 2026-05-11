import base64
import logging
from datetime import datetime
from io import BytesIO
from pathlib import Path

from jinja2 import Environment, FileSystemLoader

logger = logging.getLogger(__name__)

_TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates"

_jinja_env = Environment(
    loader=FileSystemLoader(str(_TEMPLATE_DIR)),
    autoescape=True,
)


def generate_onboarding_agreement_pdf(
    full_name: str,
    ic_number: str,
    date_str: str,
    signature_base64: str,
) -> bytes:
    template = _jinja_env.get_template("onboarding_agreement.html")
    signature_data_uri = f"data:image/png;base64,{signature_base64}"

    html_content = template.render(
        full_name=full_name,
        ic_number=ic_number,
        date=date_str,
        signature_data_uri=signature_data_uri,
        year=datetime.now().year,
    )

    pdf_buffer = BytesIO()
    from xhtml2pdf import pisa
    pisa_status = pisa.CreatePDF(html_content, dest=pdf_buffer)

    if pisa_status.err:
        logger.error("PDF generation failed with %d errors", pisa_status.err)
        raise RuntimeError(f"PDF generation failed with {pisa_status.err} errors")

    pdf_bytes = pdf_buffer.getvalue()
    logger.info(
        "Generated onboarding agreement PDF: name=%s ic=%s size=%d bytes",
        full_name, ic_number, len(pdf_bytes),
    )
    return pdf_bytes