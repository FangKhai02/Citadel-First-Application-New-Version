"""VTB KYC form PDF generation using PyMuPDF overlay.

Opens the original VTB PDF forms and overlays user data at the exact
field positions, preserving the original formatting, layout, and legal text.

Position mapping: data is placed AFTER the label text, aligned to the
label's baseline. All positions were extracted from the original template
PDFs using PyMuPDF's get_text('dict').
"""

import logging
from io import BytesIO
from pathlib import Path

import fitz  # PyMuPDF

from app.schemas.vtb_kyc import BeneficiaryData, VtbKycFormData

logger = logging.getLogger(__name__)

_TEMPLATE_DIR = Path(__file__).resolve().parent.parent / "templates" / "vtb_forms"

FONT_NAME = "helv"  # Helvetica built-in
FONT_SIZE = 10
FONT_COLOR = (0, 0, 0)  # Black


def _overlay_text(
    page: fitz.Page,
    text: str,
    x: float,
    y: float,
    font_size: float = FONT_SIZE,
    font_name: str = FONT_NAME,
    color: tuple = FONT_COLOR,
    max_width: float | None = None,
    align: int = fitz.TEXT_ALIGN_LEFT,
) -> None:
    """Insert text at a specific position on a PDF page.

    Uses insert_textbox when max_width is provided (for multi-line wrapping).
    Uses insert_text for single-line placement (more reliable).
    """
    if not text or text == "N/A":
        text = "N/A"
        color = (0.4, 0.4, 0.4)

    if max_width:
        # Manually wrap text using font metrics for reliable multi-line rendering
        font = fitz.Font(font_name)
        line_height = font_size * 1.3
        words = text.split()
        lines = []
        current_line = ""
        for word in words:
            test_line = f"{current_line} {word}".strip() if current_line else word
            if font.text_length(test_line, fontsize=font_size) <= max_width:
                current_line = test_line
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
        if current_line:
            lines.append(current_line)
        # Render each line
        for i, line in enumerate(lines):
            page.insert_text(
                fitz.Point(x, y + i * line_height),
                line,
                fontname=font_name,
                fontsize=font_size,
                color=color,
            )
    else:
        page.insert_text(
            fitz.Point(x, y),
            text,
            fontname=font_name,
            fontsize=font_size,
            color=color,
        )


def _overlay_checkbox(
    page: fitz.Page,
    x: float,
    y: float,
    checked: bool,
    size: float = 10,
) -> None:
    """Draw a checkmark in a checkbox area."""
    if checked:
        page.insert_text(
            fitz.Point(x, y),
            "X",
            fontname="helv",
            fontsize=size,
            color=(0, 0, 0),
        )


def _overlay_signature(
    page: fitz.Page,
    signature_bytes: bytes | None,
    x: float,
    y: float,
    width: float = 120,
    height: float = 40,
) -> None:
    """Embed a signature image on the page if available.

    Uses the image's actual aspect ratio to prevent PyMuPDF from
    centering/shifting the image within the rect.
    """
    if not signature_bytes:
        return
    try:
        # Get image dimensions to preserve aspect ratio and avoid centering
        img_doc = fitz.open("png", signature_bytes)
        img_page = img_doc[0]
        img_w = img_page.rect.width
        img_h = img_page.rect.height
        img_doc.close()

        # Calculate rect that matches the image aspect ratio exactly
        # so PyMuPDF doesn't center/shift it
        aspect = img_w / img_h if img_h > 0 else 3.0
        actual_width = height * aspect
        rect = fitz.Rect(x, y, x + actual_width, y + height)
        page.insert_image(rect, stream=signature_bytes)
    except Exception:
        logger.warning("Failed to overlay signature image")


def _cover_area(page: fitz.Page, x: float, y: float, width: float, height: float) -> None:
    """Remove template text in an area by redacting it, then fill with white."""
    rect = fitz.Rect(x, y, x + width, y + height)
    page.add_redact_annot(rect, fill=(1, 1, 1))
    page.apply_redactions(images=fitz.PDF_REDACT_IMAGE_NONE)


def _format_phone_for_a1(raw_phone: str) -> str:
    """Format a Malaysian phone number: '+ (60) 12-345 6789'.

    Accepts formats like '+60123456789', '60123456789', '0123456789', etc.
    """
    if not raw_phone or raw_phone == "N/A":
        return "N/A"
    digits = raw_phone.replace("+", "").replace("-", "").replace(" ", "").replace("(", "").replace(")", "")
    # Strip leading 0 if Malaysian local format (012-345 6789 → 60 12-345 6789)
    if digits.startswith("0") and len(digits) >= 9:
        digits = "60" + digits[1:]
    # Malaysian numbers start with 60
    if digits.startswith("60") and len(digits) >= 4:
        country_code = digits[:2]  # "60"
        rest = digits[2:]  # "123456789"
        if len(rest) >= 8:
            formatted_rest = f"{rest[:2]}-{rest[2:5]} {rest[5:]}"
        elif len(rest) >= 7:
            formatted_rest = f"{rest[:2]}-{rest[2:5]} {rest[5:]}"
        else:
            formatted_rest = rest
        return f"+ ({country_code}) {formatted_rest}"
    # Fallback: return as-is if not Malaysian format
    return raw_phone


# ════════════════════════════════════════════════════════════════════════════════
# Form B6 — Asset Allocation Direction
# ═════════════════════════════════════════════════════════════════════════════════

def build_form_b6(data: VtbKycFormData, signature_bytes: bytes | None = None) -> bytes:
    """Overlay data onto B6 form.

    Positions aligned to sample form:
      Page 1:
        "From:" label at x=72, y=173.3 → name at x=146, y=168
        "MYR __________" at x=202.8, y=405.1 → amount at x=227, y=398
        "Settlor's Signature" at x=77.4, y=718 → signature at x=78, y=660
        "Dated:" at x=77.4, y=611.0 → date at x=115, y=611
      Page 3:
        "INITIAL:" at x=478.3, y=780.4 → signature at x=478, y=760
    """
    doc = fitz.open(str(_TEMPLATE_DIR / "B6_FORM.pdf"))

    # ── Page 1 ──
    page = doc[0]
    # Settlor name — aligned to sample "LEE WEI KANG" at x=146, y=168.5
    _overlay_text(page, data.name, 146, 168.5, font_size=10)
    # Trust asset amount — bold, larger font, positioned after "MYR"
    trust_amount = data.trust_asset_amount.replace("RM ", "")
    page.insert_text(
        fitz.Point(227, 398),
        trust_amount,
        fontname="helv",
        fontsize=11,
        color=(0, 0, 0),
    )
    # Date — left empty per user request

    # Settlor signature — above "Settlor's Signature" label
    _overlay_signature(page, signature_bytes, 78, 660, width=140, height=40)

    # ── Page 3 — Initial signature ──
    p3 = doc[2]
    _overlay_signature(p3, signature_bytes, 478, 785, width=80, height=22)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


# ════════════════════════════════════════════════════════════════════════════════
# Form A1 — VTB Services Agreement
# ═════════════════════════════════════════════════════════════════════════════════

def build_form_a1(
    data: VtbKycFormData,
    signature_bytes: bytes | None = None,
) -> bytes:
    """Overlay data onto A1 form.

    Positions matched to sample form (page 595.56 x 842.04):
      Ref No — left empty per sample
      "entered on" — no date per sample
      "Name of Client :" at x=141.4, y=287.6 → name at x=275, y=282
      "Passport / ID Number" at x=106.1, y=328.6 → IC at x=249
      "Registered Address" at x=106.1, y=373.3 → addr at x=249
      Contact Number: cover template "+ (     )" and overlay "+ (60) 12-345 6789"
      Page 6: Signature at x=80, y=692; Name at x=120, y=723
      Page 8: Signature at x=80, y=296; Name at x=110, y=327
    """
    doc = fitz.open(str(_TEMPLATE_DIR / "A1_FORM.pdf"))

    # Page 1 — Client details
    p1 = doc[0]
    _overlay_text(p1, data.name, 275, 282, font_size=10)
    _overlay_text(p1, data.identity_card_number, 249, 329, font_size=10)
    _overlay_text(p1, data.residential_address, 249, 372, font_size=10)

    # Contact Number — cover the template "+ (     )" and overlay formatted number
    _cover_area(p1, 243, 407, 38, 17)
    phone_formatted = _format_phone_for_a1(data.mobile_number)
    _overlay_text(p1, phone_formatted, 244, 420, font_size=10)

    # Page 6 — Client signature area
    # Sample signature "Wei Kang" starts at x≈137, above the dotted line (top ≈ y=694.7)
    # Name goes after "Name :" label at y≈723
    if len(doc) >= 6:
        p6 = doc[5]
        _overlay_signature(p6, signature_bytes, 137, 679, width=180, height=20)
        _overlay_text(p6, data.name, 120, 723, font_size=10)

    # Page 8 — Client signature area
    # Signature starts at the beginning of the dotted line (x=56.5)
    # Name goes after "Name:" label at y≈327
    if len(doc) >= 8:
        p8 = doc[7]
        _overlay_signature(p8, signature_bytes, 56, 278, width=200, height=22)
        _overlay_text(p8, data.name, 110, 327, font_size=10)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


# ════════════════════════════════════════════════════════════════════════════════
# Form A2 — KYC & Risk Assessment
# ═════════════════════════════════════════════════════════════════════════════════

def _draw_strikethrough(page: fitz.Page, x: float, y: float, width: float, thickness: float = 1.5) -> None:
    """Draw a horizontal line through text to cross it out.

    y should be at the vertical center of the text (not the baseline).
    For typical font size 10-11, the center is ~4px above the baseline.
    """
    shape = page.new_shape()
    shape.draw_line(fitz.Point(x, y), fitz.Point(x + width, y))
    shape.finish(color=(0, 0, 0), width=thickness)
    shape.commit()


def build_form_a2(data: VtbKycFormData) -> bytes:
    """Overlay data onto A2 form.

    Positions matched to template layout:
      Column divider at x≈313, right edge at x≈557
      Data column width: ~244px (313→557)
      All data at x=316 (3px after divider), font size 9 (standardised)
    """
    doc = fitz.open(str(_TEMPLATE_DIR / "A2_FORM.pdf"))

    FS = 9  # Standard font size for all A2 fields
    DX = 316  # Data x position (just after the column divider at x≈313)
    COL_W = 244  # Max width for address wrapping (313 to 557 minus padding)

    # Helper for long text fields that may need wrapping
    def _overlay_address(page, text, x, y, max_width=COL_W):
        if not text or text == "N/A":
            _overlay_text(page, "N/A", x, y, font_size=FS, color=(0.4, 0.4, 0.4))
            return
        _overlay_text(page, text, x, y, font_size=FS, max_width=max_width)

    p1 = doc[0]
    # Name — placed after "Client Full English Name: " label (label ends at x≈173)
    _overlay_text(p1, data.name, 173, 156.0, font_size=FS)

    # Our Reference and Date — left empty per sample form

    # Page 1 data fields — all at DX=316, font size 9
    # Y positions aligned to the top of each table cell so addresses fit within their boxes:
    #   Residential addr box: y=436.7→478.7, label at y=448, data starts at y=448 (top of data cell)
    #   Business addr box:    y=582.0→627.7, label at y=593.4, data starts at y=593 (top of data cell)
    #   Mailing addr box:     y=656.0→681.6, label at y=667.6, data starts at y=668 (top of data cell)
    _overlay_text(p1, data.dob, DX, 346, font_size=FS)
    _overlay_text(p1, data.identity_card_number, DX, 370, font_size=FS)
    _overlay_text(p1, data.nationality, DX, 430, font_size=FS)
    _overlay_address(p1, data.residential_address, DX, 448)
    _overlay_text(p1, data.home_telephone or "N/A", DX, 492, font_size=FS)
    _overlay_text(p1, data.mobile_number, DX, 521, font_size=FS)
    _overlay_text(p1, data.email, DX, 547, font_size=FS)
    _overlay_text(p1, data.employer_name, DX, 577, font_size=FS)
    _overlay_address(p1, data.employer_address, DX, 593)
    _overlay_text(p1, data.employer_telephone or "N/A", DX, 645, font_size=FS)
    _overlay_address(p1, data.mailing_address, DX, 668)
    _overlay_text(p1, data.crs_residencies_text if hasattr(data, 'crs_residencies_text') else "N/A", DX, 693, font_size=FS)
    _overlay_text(p1, data.country_of_birth, DX, 724, font_size=FS)

    # Physically present — cross out the option NOT selected
    # "Yes / No" baseline at y≈744, font size 11 → center at y≈740
    present_val = "Yes" if data.physically_present in (True, "True", "yes", "Yes") else "No"
    strike_y = 740
    if present_val == "Yes":
        _draw_strikethrough(p1, 340, strike_y, 20)
    else:
        _draw_strikethrough(p1, 323, strike_y, 20)

    p2 = doc[1]
    # Page 2 data — standardised to font size 9
    _overlay_text(p2, data.main_sources_of_income, 82, 105.7, font_size=FS)
    _overlay_text(p2, data.has_unusual_transactions, 84, 156.3, font_size=FS)
    _overlay_text(p2, data.marital_history, 82, 217, font_size=FS)
    _overlay_text(p2, data.geographical_connections, 84, 321.0, font_size=FS)
    _overlay_text(p2, data.other_relevant_info, 85, 387.3, font_size=FS)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


# ════════════════════════════════════════════════════════════════════════════════
# Form B2 — Application for Trustee Service
# ═════════════════════════════════════════════════════════════════════════════════

def _overlay_checkbox_b2(page: fitz.Page, x: float, y: float, checked: bool, size: float = 12) -> None:
    """Draw an X mark at a checkbox position in the B2 form."""
    if checked:
        page.insert_text(
            fitz.Point(x, y),
            "X",
            fontname="helv",
            fontsize=size,
            color=(0, 0, 0),
        )


def _format_phone_for_b2(raw_phone: str) -> str:
    """Format phone as '+ (60) 12-345 6789' for B2 form."""
    return _format_phone_for_a1(raw_phone)


def _overlay_address_b2(
    page: fitz.Page,
    text: str,
    x: float,
    y: float,
    max_width: float = 347,
) -> None:
    """Overlay multi-line address text on a B2 form page."""
    if not text or text == "N/A":
        _overlay_text(page, "N/A", x, y, font_size=9, color=(0.4, 0.4, 0.4))
        return
    _overlay_text(page, text, x, y, font_size=9, max_width=max_width)


# Position dictionaries for B2 beneficiary pages (extracted from template analysis).
# Page 2 (Pre-Demise Beneficiary) has "Same as the Settlor" and Part A/B headers.
# Page 3 (Post-Demise Beneficiary) has Pre/Post checkboxes and no Part A/B headers.
_B2_P2: dict[str, float] = {
    # Data column x positions
    "left_x": 194,
    "right_x": 432,
    "addr_x": 76,
    "addr_max_w": 347,
    # Part A field y positions
    "surname_y": 220.6,
    "given_name_y": 243.6,
    "other_names_y": 266.8,
    "relationship_y": 289.7,
    "share_pct_y": 289.7,
    "acct_name_y": 312.4,
    "acct_number_y": 335.5,
    "bank_name_y": 359.2,
    "bank_swift_y": 357.0,
    "bank_addr_y": 390.0,
    # Part B field y positions (checkbox positions aligned to ☐ origins)
    "passport_y": 464.8,
    "id_number_y": 464.4,
    "same_as_settlor_cb_x": 234.2,
    "same_as_settlor_cb_y": 175.4,
    "male_cb_x": 200.8,
    "female_cb_x": 249.4,
    "gender_y": 485.0,
    "dob_y": 487.4,
    "nationality_y": 510.6,
    "email_y": 533.6,
    "contact_y": 533.6,
    "contact_bracket_left_x": 431,
    "contact_bracket_right_x": 449,
    "res_addr_y": 568.0,
    "mail_addr_y": 628.0,
}

_B2_P3: dict[str, float] = {
    "left_x": 196,
    "right_x": 437,
    "addr_x": 76,
    "addr_max_w": 355,
    # Part A field y positions
    "surname_y": 204.4,
    "given_name_y": 227.5,
    "other_names_y": 250.6,
    "relationship_y": 274.9,
    "share_pct_y": 275.4,
    "acct_name_y": 298.8,
    "acct_number_y": 321.7,
    "bank_name_y": 345.2,
    "bank_swift_y": 344.0,
    "bank_addr_y": 377.0,
    # Part B field y positions (checkbox positions aligned to ☐ origins)
    "passport_y": 427.5,
    "id_number_y": 427.7,
    "pre_demise_cb_x": 186.8,
    "pre_demise_cb_y": 159.2,
    "post_demise_cb_x": 188.0,
    "post_demise_cb_y": 173.0,
    "male_cb_x": 205.5,
    "female_cb_x": 254.0,
    "gender_y": 448.5,
    "dob_y": 450.8,
    "nationality_y": 474.0,
    "email_y": 497.0,
    "contact_y": 497.0,
    "contact_bracket_left_x": 440,
    "contact_bracket_right_x": 458,
    "res_addr_y": 531.0,
    "mail_addr_y": 590.0,
}


def _fill_part_a(
    page: fitz.Page,
    pos: dict[str, float],
    name: str,
    relationship: str,
    share_pct: str,
    bank_acct_name: str,
    bank_acct_number: str,
    bank_name: str,
    bank_swift: str,
    bank_addr: str,
) -> None:
    """Fill Part A (Mandatory) fields using position dictionary."""
    FS = 9
    lx = pos["left_x"]
    rx = pos["right_x"]
    _overlay_text(page, name, lx, pos["surname_y"], font_size=FS)
    _overlay_text(page, "N/A", lx, pos["given_name_y"], font_size=FS, color=(0.4, 0.4, 0.4))
    _overlay_text(page, "N/A", lx, pos["other_names_y"], font_size=FS, color=(0.4, 0.4, 0.4))
    _overlay_text(page, relationship, lx, pos["relationship_y"], font_size=FS)
    _overlay_text(page, share_pct, rx, pos["share_pct_y"], font_size=FS)
    _overlay_text(page, bank_acct_name, lx, pos["acct_name_y"], font_size=FS)
    _overlay_text(page, bank_acct_number, lx, pos["acct_number_y"], font_size=FS)
    _overlay_text(page, bank_name, lx, pos["bank_name_y"], font_size=FS)
    _overlay_text(page, bank_swift, rx, pos["bank_swift_y"], font_size=FS)
    _overlay_address_b2(
        page, bank_addr, pos["addr_x"], pos["bank_addr_y"], max_width=pos["addr_max_w"]
    )


def _fill_part_b(
    page: fitz.Page,
    pos: dict[str, float],
    passport: str,
    id_number: str,
    gender: str,
    dob: str,
    nationality: str,
    email: str,
    contact: str,
    res_addr: str,
    mail_addr: str,
) -> None:
    """Fill Part B (personal details) fields using position dictionary."""
    FS = 9
    lx = pos["left_x"]
    rx = pos["right_x"]
    _overlay_text(page, passport, lx, pos["passport_y"], font_size=FS)
    _overlay_text(page, id_number, rx, pos["id_number_y"], font_size=FS)
    _overlay_checkbox_b2(page, pos["male_cb_x"], pos["gender_y"], gender.lower() == "male", size=9)
    _overlay_checkbox_b2(page, pos["female_cb_x"], pos["gender_y"], gender.lower() == "female", size=9)
    _overlay_text(page, dob, rx, pos["dob_y"], font_size=FS)
    _overlay_text(page, nationality, lx, pos["nationality_y"], font_size=FS)
    _overlay_text(page, email, lx, pos["email_y"], font_size=FS)
    # Contact Number — cover template "( )" brackets and overlay full formatted number
    bracket_y = pos["contact_y"] - 7
    bracket_width = pos["contact_bracket_right_x"] - pos["contact_bracket_left_x"] + 10
    _cover_area(page, pos["contact_bracket_left_x"], bracket_y, bracket_width, 14)
    _overlay_text(page, contact, pos["contact_bracket_left_x"] + 1, pos["contact_y"], font_size=FS)
    _overlay_address_b2(page, res_addr, pos["addr_x"], pos["res_addr_y"], max_width=pos["addr_max_w"])
    _overlay_address_b2(page, mail_addr, pos["addr_x"], pos["mail_addr_y"], max_width=pos["addr_max_w"])


def build_form_b2(data: VtbKycFormData, signature_bytes: bytes | None = None) -> bytes:
    """Overlay data onto B2 form.

    Layout:
      - Page 1: Settlor details (Trust No left empty, gender uses X checkbox)
      - Page 2: First Pre-Demise Beneficiary (highest share, with "Same as Settlor" option)
      - Additional Pre-Demise pages: cloned from template page 3, ticked "Pre-Demise"
      - Post-Demise pages: first uses template page 3, extras cloned, ticked "Post-Demise"
      - Last page: Trust Property section (original page 4, pushed to end)
    """
    FS = 9
    doc = fitz.open(str(_TEMPLATE_DIR / "B2_FORM.pdf"))

    # ── Page 1 — Settlor details ──
    p1 = doc[0]
    _overlay_text(p1, data.name, 194, 262.1, font_size=FS)
    _overlay_text(p1, "N/A", 194, 285.4, font_size=FS, color=(0.4, 0.4, 0.4))
    _overlay_text(p1, "N/A", 194, 308.5, font_size=FS, color=(0.4, 0.4, 0.4))

    # Gender — X on the matching checkbox (☐ origins at (204.4, 332.4) and (252.8, 332.4))
    _overlay_checkbox_b2(p1, 205, 333, data.gender.lower() == "male", size=9)
    _overlay_checkbox_b2(p1, 254, 333, data.gender.lower() == "female", size=9)
    _overlay_text(p1, data.dob, 432, 331.8, font_size=FS)

    _overlay_text(p1, data.nationality, 194, 355.0, font_size=FS)
    _overlay_text(p1, data.identity_card_number, 432, 381.1, font_size=FS)
    _overlay_text(p1, data.email, 194, 404.3, font_size=FS)
    # Contact Number — cover template "( )" brackets and overlay full formatted number
    _cover_area(p1, 437, 397, 28, 14)
    _overlay_text(p1, _format_phone_for_b2(data.mobile_number), 438, 404.3, font_size=FS)

    # Addresses — start below the label row
    _overlay_address_b2(p1, data.residential_address, 76, 443)
    _overlay_address_b2(p1, data.mailing_address, 76, 498)

    _overlay_text(p1, data.annual_income_range, 194, 540.8, font_size=FS)
    _overlay_text(p1, data.source_of_trust_fund, 432, 537.1, font_size=FS)
    _overlay_text(p1, data.source_of_income, 194, 562.1, font_size=FS)
    _overlay_text(p1, data.employer_name, 194, 654.4, font_size=FS)
    _overlay_text(p1, data.nature_of_business, 194, 677.6, font_size=FS)
    _overlay_text(p1, data.occupation, 194, 700.8, font_size=FS)
    _overlay_text(p1, data.work_title, 194, 724.1, font_size=FS)
    _overlay_text(p1, data.date_of_trust_deed, 194, 747.7, font_size=FS)

    # ── Page 2 — Pre-Demise Beneficiary (highest share percentage) ──
    pre_bens = data.pre_demise_beneficiaries or []
    first_pre = None
    extra_pre = []
    if pre_bens:
        def _parse_share_pct(s: str) -> float:
            """Extract numeric percentage from formats like '70%', 'RM 70.00', '70', or 'N/A'."""
            if not s or s == "N/A":
                return 0
            s = s.strip().rstrip("%")
            s = s.replace("RM", "").replace(",", "").strip()
            try:
                return float(s)
            except ValueError:
                return 0

        sorted_pre = sorted(
            pre_bens,
            key=lambda b: _parse_share_pct(b.share_percentage),
            reverse=True,
        )
        first_pre = sorted_pre[0]
        extra_pre = sorted_pre[1:]

    if first_pre and len(doc) >= 2:
        p2 = doc[1]
        p = _B2_P2

        if first_pre.same_as_settlor:
            # Tick "Same as the Settlor" checkbox
            _overlay_checkbox_b2(p2, p["same_as_settlor_cb_x"], p["same_as_settlor_cb_y"], True, size=9)
            # Part A — fill with beneficiary's own bank details (even though same person as settlor)
            _fill_part_a(
                p2, p,
                name=data.name,
                relationship=first_pre.relationship_to_settlor,
                share_pct=first_pre.share_percentage,
                bank_acct_name=first_pre.bank_account_name or "N/A",
                bank_acct_number=first_pre.bank_account_number or "N/A",
                bank_name=first_pre.bank_name or "N/A",
                bank_swift=first_pre.bank_swift_code or "N/A",
                bank_addr=first_pre.bank_address or "N/A",
            )
            # Part B — left blank (omitted when "Same as Settlor" is ticked)
        else:
            # Part A — beneficiary bank details
            _fill_part_a(
                p2, p,
                name=first_pre.full_name,
                relationship=first_pre.relationship_to_settlor,
                share_pct=first_pre.share_percentage,
                bank_acct_name=first_pre.bank_account_name or "N/A",
                bank_acct_number=first_pre.bank_account_number or "N/A",
                bank_name=first_pre.bank_name or "N/A",
                bank_swift=first_pre.bank_swift_code or "N/A",
                bank_addr=first_pre.bank_address or "N/A",
            )
            # Part B — beneficiary personal details
            contact = _format_phone_for_b2(first_pre.contact_number) if first_pre.contact_number != "N/A" else "N/A"
            _fill_part_b(
                p2, p,
                passport=first_pre.nric,
                id_number=first_pre.id_number,
                gender=first_pre.gender,
                dob=first_pre.dob,
                nationality="N/A",
                email=first_pre.email,
                contact=contact,
                res_addr=first_pre.residential_address,
                mail_addr=first_pre.mailing_address,
            )

    # ── Additional Pre-Demise pages — insert between page 2 and page 3 ──
    # Each insertion at index 2 pushes original pages down
    for i, ben in enumerate(extra_pre):
        template_doc = fitz.open(str(_TEMPLATE_DIR / "B2_FORM.pdf"))
        new_page = doc.new_page(pno=2 + i, width=template_doc[2].rect.width, height=template_doc[2].rect.height)
        new_page.show_pdf_page(new_page.rect, template_doc, 2)
        template_doc.close()

        p_new = doc[2 + i]
        p = _B2_P3

        # Tick "Pre-Demise of Settlor" checkbox on the generic beneficiary page
        _overlay_checkbox_b2(p_new, p["pre_demise_cb_x"], p["pre_demise_cb_y"], True, size=9)

        _fill_part_a(
            p_new, p,
            name=ben.full_name,
            relationship=ben.relationship_to_settlor,
            share_pct=ben.share_percentage,
            bank_acct_name=ben.bank_account_name or "N/A",
            bank_acct_number=ben.bank_account_number or "N/A",
            bank_name=ben.bank_name or "N/A",
            bank_swift=ben.bank_swift_code or "N/A",
            bank_addr=ben.bank_address or "N/A",
        )
        contact = _format_phone_for_b2(ben.contact_number) if ben.contact_number != "N/A" else "N/A"
        _fill_part_b(
            p_new, p,
            passport=ben.nric,
            id_number=ben.id_number,
            gender=ben.gender,
            dob=ben.dob,
            nationality="N/A",
            email=ben.email,
            contact=contact,
            res_addr=ben.residential_address,
            mail_addr=ben.mailing_address,
        )

    # ── Post-Demise Beneficiaries ──
    # After inserting extra pre-demise pages, the original post-demise page
    # is now at index 2 + len(extra_pre)
    post_bens = data.post_demise_beneficiaries or []
    post_start = 2 + len(extra_pre)

    if post_bens and len(doc) > post_start:
        p3 = doc[post_start]
        p = _B2_P3
        ben = post_bens[0]

        # Tick "Post-Demise of Settlor" checkbox
        _overlay_checkbox_b2(p3, p["post_demise_cb_x"], p["post_demise_cb_y"], True, size=9)

        _fill_part_a(
            p3, p,
            name=ben.full_name,
            relationship=ben.relationship_to_settlor,
            share_pct=ben.share_percentage,
            bank_acct_name=ben.bank_account_name or "N/A",
            bank_acct_number=ben.bank_account_number or "N/A",
            bank_name=ben.bank_name or "N/A",
            bank_swift=ben.bank_swift_code or "N/A",
            bank_addr=ben.bank_address or "N/A",
        )
        contact = _format_phone_for_b2(ben.contact_number) if ben.contact_number != "N/A" else "N/A"
        _fill_part_b(
            p3, p,
            passport=ben.nric,
            id_number=ben.id_number,
            gender=ben.gender,
            dob=ben.dob,
            nationality="N/A",
            email=ben.email,
            contact=contact,
            res_addr=ben.residential_address,
            mail_addr=ben.mailing_address,
        )

    # Additional post-demise beneficiaries — insert before Trust Property page
    for i, ben in enumerate(post_bens[1:]):
        insert_at = post_start + 1 + i
        template_doc = fitz.open(str(_TEMPLATE_DIR / "B2_FORM.pdf"))
        new_page = doc.new_page(pno=insert_at, width=template_doc[2].rect.width, height=template_doc[2].rect.height)
        new_page.show_pdf_page(new_page.rect, template_doc, 2)
        template_doc.close()

        p_new = doc[insert_at]
        p = _B2_P3

        _overlay_checkbox_b2(p_new, p["post_demise_cb_x"], p["post_demise_cb_y"], True, size=9)

        _fill_part_a(
            p_new, p,
            name=ben.full_name,
            relationship=ben.relationship_to_settlor,
            share_pct=ben.share_percentage,
            bank_acct_name=ben.bank_account_name or "N/A",
            bank_acct_number=ben.bank_account_number or "N/A",
            bank_name=ben.bank_name or "N/A",
            bank_swift=ben.bank_swift_code or "N/A",
            bank_addr=ben.bank_address or "N/A",
        )
        contact = _format_phone_for_b2(ben.contact_number) if ben.contact_number != "N/A" else "N/A"
        _fill_part_b(
            p_new, p,
            passport=ben.nric,
            id_number=ben.id_number,
            gender=ben.gender,
            dob=ben.dob,
            nationality="N/A",
            email=ben.email,
            contact=contact,
            res_addr=ben.residential_address,
            mail_addr=ben.mailing_address,
        )

    # ── Last page — Section 3: Trust Property + Settlor Signature ──
    last_page = doc[-1]
    # Trust Property and Amount — strip "RM " prefix since MYR is already in the template
    trust_amount = data.trust_asset_amount.replace("RM ", "")
    _overlay_text(last_page, trust_amount, 230, 241.9, font_size=9)

    # Settlor signature (left side, below "Signed by the Settlor:")
    _overlay_signature(last_page, signature_bytes, 71, 620, width=140, height=35)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


# ════════════════════════════════════════════════════════════════════════════════
# Form B3 — Trust Deed (Individual)
# ═════════════════════════════════════════════════════════════════════════════════

def build_form_b3(data: VtbKycFormData, signature_bytes: bytes | None = None) -> bytes:
    """Overlay data onto B3 form.

    Positions:
      Page 1: "is made on this" → date
      Page 15: Settlor signature, Name, NRIC
      Pages 16-17: Schedule A (settlor details + up to 5 beneficiaries)
    """
    FS = 10
    doc = fitz.open(str(_TEMPLATE_DIR / "B3_FORM.pdf"))

    # ── Page 1 — Date of trust deed ──
    p1 = doc[0]
    _overlay_text(p1, data.date_of_trust_deed, 270, 234.3, font_size=12)

    # ── Page 15 — Settlor signature, Name, NRIC ──
    p15 = doc[14]
    _overlay_signature(p15, signature_bytes, 57, 200, width=140, height=40)
    _overlay_text(p15, data.name, 99, 307, font_size=FS)
    _overlay_text(p15, data.identity_card_number, 113, 329, font_size=FS)

    # ── Page 16 — Schedule A ──
    p16 = doc[15]
    # Section 1: Details of Settlor
    _overlay_text(p16, data.name, 286, 188, font_size=FS)
    _overlay_text(p16, data.identity_card_number, 286, 213, font_size=FS)
    _overlay_address_b3(p16, data.residential_address, 288, 237)
    _overlay_text(p16, _format_phone_for_b3(data.mobile_number), 291, 300, font_size=FS)
    _overlay_text(p16, data.email.upper(), 289, 337, font_size=FS)

    # Section 2: Details of Beneficiaries (up to 5)
    # Combine pre-demise then post-demise beneficiaries
    all_bens = list(data.pre_demise_beneficiaries or []) + list(data.post_demise_beneficiaries or [])

    # Beneficiary positions on page 16 (3 beneficiaries fit)
    ben1_pos = {"name_y": 404, "nric_y": 429, "addr_y": 452, "phone_y": 516, "email_y": 554}
    ben2_pos = {"name_y": 580, "nric_y": 605, "addr_y": 629, "phone_y": 658, "email_y": 694}
    ben3_pos = {"name_y": 718, "nric_y": 743}  # Only name + NRIC fit on page 16

    if len(all_bens) >= 1:
        b = all_bens[0]
        _overlay_text(p16, b.full_name, 284, ben1_pos["name_y"], font_size=FS)
        _overlay_text(p16, b.nric, 284, ben1_pos["nric_y"], font_size=FS)
        _overlay_address_b3(p16, b.residential_address, 286, ben1_pos["addr_y"])
        _overlay_text(p16, _format_phone_for_b3(b.contact_number), 289, ben1_pos["phone_y"], font_size=FS)
        _overlay_text(p16, b.email.upper() if b.email and b.email != "N/A" else "N/A", 287, ben1_pos["email_y"], font_size=FS)

    if len(all_bens) >= 2:
        b = all_bens[1]
        _overlay_text(p16, b.full_name, 289, ben2_pos["name_y"], font_size=FS)
        _overlay_text(p16, b.nric, 289, ben2_pos["nric_y"], font_size=FS)
        _overlay_address_b3(p16, b.residential_address, 291, ben2_pos["addr_y"])
        _overlay_text(p16, _format_phone_for_b3(b.contact_number), 291, ben2_pos["phone_y"], font_size=FS)
        _overlay_text(p16, b.email.upper() if b.email and b.email != "N/A" else "N/A", 292, ben2_pos["email_y"], font_size=FS)

    if len(all_bens) >= 3:
        b = all_bens[2]
        _overlay_text(p16, b.full_name, 290, ben3_pos["name_y"], font_size=FS)
        _overlay_text(p16, b.nric, 290, ben3_pos["nric_y"], font_size=FS)

    # ── Page 17 — Schedule A continued (beneficiary 3 rest + beneficiaries 4-5) ──
    p17 = doc[16]
    if len(all_bens) >= 3:
        b = all_bens[2]
        _overlay_address_b3(p17, b.residential_address, 291, 66)
        _overlay_text(p17, _format_phone_for_b3(b.contact_number), 291, 91, font_size=FS)
        _overlay_text(p17, b.email.upper() if b.email and b.email != "N/A" else "N/A", 292, 130, font_size=FS)

    # Beneficiary 4 positions on page 17
    if len(all_bens) >= 4:
        b = all_bens[3]
        _overlay_text(p17, b.full_name, 290, 155, font_size=FS)
        _overlay_text(p17, b.nric, 290, 180, font_size=FS)
        _overlay_address_b3(p17, b.residential_address, 291, 205)
        _overlay_text(p17, _format_phone_for_b3(b.contact_number), 291, 230, font_size=FS)
        _overlay_text(p17, b.email.upper() if b.email and b.email != "N/A" else "N/A", 292, 269, font_size=FS)

    # Beneficiary 5 positions on page 17
    if len(all_bens) >= 5:
        b = all_bens[4]
        _overlay_text(p17, b.full_name, 290, 294, font_size=FS)
        _overlay_text(p17, b.nric, 290, 319, font_size=FS)
        _overlay_address_b3(p17, b.residential_address, 291, 344)
        _overlay_text(p17, _format_phone_for_b3(b.contact_number), 291, 383, font_size=FS)
        _overlay_text(p17, b.email.upper() if b.email and b.email != "N/A" else "N/A", 292, 408, font_size=FS)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


def _format_phone_for_b3(raw_phone: str) -> str:
    """Format phone for B3 Schedule A: '6012-7654321' style (no + prefix)."""
    if not raw_phone or raw_phone == "N/A":
        return "N/A"
    digits = raw_phone.replace("+", "").replace("-", "").replace(" ", "").replace("(", "").replace(")", "")
    if digits.startswith("0") and len(digits) >= 9:
        digits = "60" + digits[1:]
    if digits.startswith("60") and len(digits) >= 10:
        country = digits[:2]
        rest = digits[2:]
        return f"{country}{rest[:2]}-{rest[2:]}"
    return raw_phone


def _overlay_address_b3(
    page: fitz.Page,
    text: str,
    x: float,
    y: float,
) -> None:
    """Overlay multi-line address text on B3 form (Schedule A boxes)."""
    if not text or text == "N/A":
        _overlay_text(page, "N/A", x, y, font_size=10, color=(0.4, 0.4, 0.4))
        return
    _overlay_text(page, text, x, y, font_size=10, max_width=260)


# ════════════════════════════════════════════════════════════════════════════════
# Form B4 — CRS Self-Certification
# ═════════════════════════════════════════════════════════════════════════════════

def build_form_b4(data: VtbKycFormData, signature_bytes: bytes | None = None) -> bytes:
    """Overlay data onto B4 form.

    Positions aligned to sample form:
      Page 1 — Part 1 fields (data in right column after labels):
        Name: x=225, y=330
        NRIC/Passport: x=225, y=367
        Residence Address: x=225, y=402
        Mailing Address: x=225, y=440
        DOB: x=226, y=484
        Nationality: x=225, y=520
      Page 2 — Part 2 CRS table:
        Jurisdiction col: x=63
        TIN col: x=171
        Reason A/B/C col: x=266
        Explanation col: x=378
        Row (1): y=89, row (2): y=113, row (3): y=138, etc.
      Page 2 — Part 3 Signature:
        Signature image: x=100, y=510
        Name: x=146, y=598
    """
    doc = fitz.open(str(_TEMPLATE_DIR / "B4_FORM.pdf"))
    FS = 9

    # ── Page 1 — Part 1: Identification ──
    p1 = doc[0]
    _overlay_text(p1, data.name, 225, 330, font_size=FS)
    _overlay_text(p1, data.identity_card_number, 225, 367, font_size=FS)
    _overlay_text(p1, data.residential_address, 225, 402, font_size=FS, max_width=300)
    _overlay_text(p1, data.mailing_address, 225, 440, font_size=FS, max_width=300)
    _overlay_text(p1, data.dob, 226, 484, font_size=FS)
    _overlay_text(p1, data.nationality, 225, 520, font_size=FS)

    # ── Page 2 — Part 2: CRS table ──
    p2 = doc[1]
    y_start = 89
    row_height = 24
    for i, crs in enumerate(data.crs_residencies[:5]):
        y = y_start + i * row_height
        _overlay_text(p2, crs.jurisdiction, 63, y, font_size=FS)
        if crs.tin_status == "no_tin":
            _overlay_text(p2, "N/A", 171, y, font_size=FS)
            _overlay_text(p2, crs.no_tin_reason, 266, y, font_size=7)
            if crs.reason_b_explanation and crs.reason_b_explanation != "N/A":
                explanation_y = y - 3  # Move up to align with top of cell row
                _overlay_text(p2, crs.reason_b_explanation, 378, explanation_y, font_size=7, max_width=160)
        else:
            _overlay_text(p2, crs.tin, 171, y, font_size=FS)

    # ── Page 2 — Part 3: Signature and Name ──
    _overlay_signature(p2, signature_bytes, 147, 535, width=140, height=35)
    _overlay_text(p2, data.name, 146, 598, font_size=FS)

    buf = BytesIO()
    doc.save(buf)
    doc.close()
    return buf.getvalue()


# ════════════════════════════════════════════════════════════════════════════════
# Generate all 6 forms
# ═════════════════════════════════════════════════════════════════════════════════

FORM_BUILDERS = {
    "A1": build_form_a1,
    "A2": build_form_a2,
    "B2": build_form_b2,
    "B3": build_form_b3,
    "B4": build_form_b4,
    "B6": build_form_b6,
}


def generate_all_vtb_pdfs(
    data: VtbKycFormData,
    signature_bytes: bytes | None = None,
) -> dict[str, bytes]:
    """Generate all 6 VTB KYC form PDFs by overlaying data onto original templates."""
    results = {}
    for form_id, builder in FORM_BUILDERS.items():
        try:
            if form_id in ("A1", "B2", "B3", "B4", "B6"):
                pdf_bytes = builder(data, signature_bytes=signature_bytes)
            else:
                pdf_bytes = builder(data)
            results[form_id] = pdf_bytes
            logger.info("Generated %s PDF: %d bytes", form_id, len(pdf_bytes))
        except Exception:
            logger.exception("Failed to generate %s PDF", form_id)
            raise
    return results


def generate_vtb_form_pdf(
    form_id: str,
    data: VtbKycFormData,
    signature_bytes: bytes | None = None,
) -> bytes:
    """Generate a single VTB KYC form PDF."""
    builder = FORM_BUILDERS.get(form_id)
    if builder is None:
        raise ValueError(f"Unknown form_id: {form_id}. Must be one of {list(FORM_BUILDERS.keys())}")
    if form_id in ("A1", "B2", "B3", "B4", "B6"):
        return builder(data, signature_bytes=signature_bytes)
    return builder(data)