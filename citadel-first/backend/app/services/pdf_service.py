import io
from datetime import date
from decimal import Decimal

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.units import cm
from reportlab.platypus import (
    HRFlowable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

_PAGE_W, _ = A4
_LM = 2.5 * cm
_RM = 2.5 * cm
_TM = 2.5 * cm
_BM = 2.5 * cm
_BW = _PAGE_W - _LM - _RM

_DARK = colors.HexColor("#1A1A1A")
_F = "Helvetica"
_FB = "Helvetica-Bold"

# ── Styles ─────────────────────────────────────────────────────────────────────

def _style(name: str, **kw) -> ParagraphStyle:
    base = dict(fontName=_F, fontSize=10, leading=16, textColor=_DARK)
    base.update(kw)
    return ParagraphStyle(name, **base)


_appendix_s = _style("Appendix",  fontName=_FB, alignment=2)
_title_s    = _style("Title",     fontName=_FB, fontSize=14, alignment=1, spaceBefore=8, spaceAfter=16, leading=20)
_normal_s   = _style("Normal",    spaceAfter=6)
_just_s     = _style("Just",      alignment=4, spaceAfter=14)
_bold_s     = _style("Bold",      fontName=_FB, spaceAfter=8)
_sec_s      = _style("Sec",       fontName=_FB, spaceBefore=16, spaceAfter=8)
_clause_s   = _style("Clause",    alignment=4, spaceAfter=12)
_list_s     = _style("List",      alignment=4, spaceAfter=10, leftIndent=28)
_initial_s  = _style("Initial",   fontName=_FB, alignment=2)

# ── Helpers ────────────────────────────────────────────────────────────────────

def _sp(h: float = 0.3) -> Spacer:
    return Spacer(1, h * cm)


def _hr(thickness: float = 1.5) -> HRFlowable:
    return HRFlowable(width="100%", thickness=thickness, color=_DARK,
                      spaceBefore=8, spaceAfter=8)


def _short_hr() -> HRFlowable:
    return HRFlowable(width="30%", thickness=0.75, color=_DARK,
                      hAlign="RIGHT", spaceBefore=2, spaceAfter=4)


def _li(letter: str, text: str) -> Paragraph:
    return Paragraph(f"{letter})\u00a0\u00a0\u00a0\u00a0{text}", _list_s)

# ── Page-1 tables ──────────────────────────────────────────────────────────────

def _address_table(advisor_name: str) -> Table:
    c1 = 1.5 * cm
    c2 = 0.6 * cm
    c4 = 3.8 * cm
    c3 = _BW - c1 - c2 - c4
    data = [
        [
            Paragraph("To",   _normal_s),
            Paragraph(":",    _normal_s),
            Paragraph('Vanguard Trustee Berhad (the \u201cTrustee\u201d)', _normal_s),
            Paragraph("",     _normal_s),
        ],
        [
            Paragraph("Re",   _normal_s),
            Paragraph(":",    _normal_s),
            Paragraph("Citadel Wealth Diversification Trust", _normal_s),
            Paragraph('(the \u201cTrust\u201d)', _normal_s),
        ],
        [
            Paragraph("From", _normal_s),
            Paragraph(":",    _normal_s),
            Paragraph(f'<u>{advisor_name}</u>', _normal_s),
            Paragraph('(the \u201cSettlor\u201d)', _normal_s),
        ],
    ]
    t = Table(data, colWidths=[c1, c2, c3, c4])
    t.setStyle(TableStyle([
        ("VALIGN",        (0, 0), (-1, -1), "MIDDLE"),
        ("TOPPADDING",    (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
        ("LEFTPADDING",   (0, 0), (-1, -1), 0),
        ("RIGHTPADDING",  (0, 0), (-1, -1), 4),
    ]))
    return t


def _dated_table(formatted_date: str, advisor_nric: str) -> Table:
    half = _BW / 2
    left = Paragraph(f"Dated:\u00a0\u00a0\u00a0{formatted_date}", _normal_s)
    right = Paragraph(
        f"Instructions Taken:<br/>"
        f"For and on behalf of trustee<br/><br/>"
        f"NRIC:\u00a0{advisor_nric}",
        _normal_s,
    )
    t = Table([[left, right]], colWidths=[half, half])
    t.setStyle(TableStyle([
        ("VALIGN",        (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING",    (0, 0), (-1, -1), 0),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 55),
        ("LEFTPADDING",   (0, 0), (-1, -1), 0),
    ]))
    return t


def _signature_table() -> Table:
    half = _BW / 2
    left  = Paragraph("Settlor\u2019s Signature", _normal_s)
    right = Paragraph("Vanguard Trustee Berhad", _normal_s)
    t = Table([[left, right]], colWidths=[half, half])
    t.setStyle(TableStyle([
        ("VALIGN",        (0, 0), (-1, -1), "BOTTOM"),
        ("TOPPADDING",    (0, 0), (-1, -1), 2),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("LEFTPADDING",   (0, 0), (-1, -1), 0),
        ("LINEABOVE",     (0, 0), (0, 0), 0.75, _DARK),
        ("LINEABOVE",     (1, 0), (1, 0), 0.75, _DARK),
    ]))
    return t

# ── Public API ─────────────────────────────────────────────────────────────────

def generate_b6_pdf(
    *,
    trust_deed_date: date,
    trust_asset_amount: Decimal,
    advisor_name: str,
    advisor_nric: str,
) -> bytes:
    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=_LM,
        rightMargin=_RM,
        topMargin=_TM,
        bottomMargin=_BM,
    )

    amount_str     = f"{trust_asset_amount:,.2f}"
    formatted_date = trust_deed_date.strftime("%d %B %Y")

    story = [

        # ══ PAGE 1: B6 FORM ═══════════════════════════════════════════════════
        Paragraph("Appendix-1", _appendix_s),
        Paragraph("B 6: Asset Allocation Direction", _title_s),

        _address_table(advisor_name),
        _sp(0.4),
        _hr(),
        _sp(0.5),

        Paragraph(
            "As Settlor of the Trust and pursuant to the powers vested in me, and in accordance with Clause 4 and "
            "Clause 13 of the Trust Deed, I hereby provide the following Asset Allocation Direction to you, as the "
            "Trustee of the Trust, to invest and allocated the trust fund as follows:",
            _just_s,
        ),
        _sp(0.4),
        Paragraph(
            "The Trustee shall exercise its institutional discretion for the strategic allocation of Trust Assets, by "
            "granting asset management mandates thereof to one or more local or overseas licensed asset "
            "manager(s) or investment bank(s) with capital-preserved fixed income strategies in private markets to "
            "meet the desired return profile for the Trust Assets.",
            _just_s,
        ),
        _sp(0.4),
        Paragraph(
            f'To allocate the sum of MYR <u><b>{amount_str}</b></u> , subject to a deduction of 1% as a trust '
            'service setup fee into appropriate asset allocation vehicles as determined by the Trustee, for the '
            'purpose of asset allocation and preservation of Trust Assets, and subject always to the Trustee\u2019s '
            'fiduciary obligations, risk assessment, and regulatory compliance requirements.',
            _just_s,
        ),
        _sp(0.5),
        _hr(),
        _sp(0.3),

        Paragraph(
            "I, hereby take full responsibility as stated in Clause 4 and Clause 13 of the Deed of the Trust. "
            "(Remarks* Details as stated in Appendix-1)",
            _normal_s,
        ),
        _sp(0.2),
        Paragraph(
            "I agree, understand and accept that the Trustee may charge any expenses/profit from my asset "
            "allocation as a professional cost during the period of the Trust.",
            _just_s,
        ),
        _sp(0.5),

        _dated_table(formatted_date, advisor_nric),
        _signature_table(),
        PageBreak(),

        # ══ PAGE 2: CLAUSE 4 ══════════════════════════════════════════════════
        Paragraph("Appendix-1", _appendix_s),
        _sp(0.6),
        Paragraph("Clause 4 and Clause 13 of the Trust Deed of the Trust", _bold_s),
        _sp(0.2),
        Paragraph("4.\u00a0\u00a0\u00a0\u00a0TRUSTEE POWERS", _sec_s),
        Paragraph(
            "4.1\u00a0\u00a0\u00a0Trustees have the discretion (after proper consideration) whether or not to use the power as "
            "it varies according to the character of the trust. If powers are used or unused upon proper "
            "consideration, the beneficiary will not be allowed to complain. In administrating the Trust and in "
            "facilitating the management of the Trust in accordance to Clause 3.1 of the Deed, the Trustee shall "
            "have the following powers: -",
            _clause_s,
        ),
        _sp(0.2),
        _li("a", "all the powers conferred under the Trustee Act 1949;"),
        _li("b", "to do all things and perform all acts which in the Trustee\u2019s judgment is necessary and proper for "
                 "the protection of the Trust Fund;"),
        _li("c", "to hold and continue to hold on trust the Trust Fund on behalf of the Settlor, so long as they deem "
                 "proper, and to allocate and re-allocate in the authorized asset allocation including any assets "
                 "purchased pursuant to the authorized asset allocation;"),
        _li("d", "to make, execute, acknowledge, and deliver all deeds, releases, mortgages, leases, contracts, "
                 "agreements, instruments, and other obligations of whatsoever nature relating to the Trust Fund, "
                 "and generally to have full right, power and authority to do all things and perform all acts necessary "
                 "to make the instruments proper and legal;"),
        _li("e", "to compromise, settle, arbitrate, or defend any claim or demand in favor of or against the Trust;"),
        _li("f", "to incur and pay the ordinary and necessary expenses of administration, including (but not by way "
                 "of limitation) reasonable attorneys\u2019 fees, accountants\u2019 fees, asset allocation counsel fees, and the like;"),
        _li("g", "to act through an agent or attorney-in-fact, by and under power of attorney duly executed by the "
                 "Trustee, in carrying out any of the authorized powers and duties;"),
        _li("h", "to represent the Trust and the Beneficiary in all suits and legal proceedings relating to the Trust "
                 "Fund in any court of law of equity, or before any other bodies or tribunals; to initiate suits and to "
                 "prosecute them to final judgment or decree; to compromise claims or suits, and to submit the same "
                 "to arbitration when, in his judgment, such course is necessary or proper;"),
        _li("j", "to pay all lawful taxes and assessments and the necessary expenses of the Trust and make payment "
                 "of any and all other legitimate expenses of the Trust from the Trust Fund;"),
        PageBreak(),

        # ══ PAGE 3: CLAUSE 4 (cont.) + CLAUSE 13 ═════════════════════════════
        Paragraph("Appendix-1", _appendix_s),
        _sp(0.5),
        _li("k", "to collect notes, obligations, dividends, and all other payments that may be due and payable to "
                 "the Trust; to deposit the proceeds thereof, as well as any other moneys from whatsoever source they "
                 "may be derived, in any suitable bank or depository, and to draw the same from time to time;"),
        _li("l", "appoint any one or more of its own officers as its attorney (jointly and severally if more than one) "
                 "with power to execute documents on behalf of the Trustee for the day to day running of the Trust; and"),
        _li("m", "engage and pay, at the expense of the Trust, for the advice or services of any banker, banking "
                 "company, lawyer, accountant or any other professional advisers or experts whose advice or services "
                 "may be reasonably necessary and rely and act upon any advice so obtained for the performance of "
                 "their respective duties and services hereunder and shall incur no liability for action taken or suffered "
                 "to be taken or omitted to be taken in good faith and in accordance with the opinion or advice of "
                 "such any banker, banking company, lawyer, accountant or any other"),
        _li("n", "professional advisers or experts."),
        _sp(0.5),

        Paragraph("13.\u00a0\u00a0\u00a0\u00a0LIABILITY AND INDEMNITY", _sec_s),
        Paragraph(
            "13.1\u00a0\u00a0\u00a0The Settlor shall at all times hereafter keep save and harmless and agree to indemnify and "
            "continue to indemnify Trustee against all actions, proceedings, claims, demands, penalties, costs "
            "(including legal costs) and expenses which may be brought or made against or incurred by the Trustee "
            "by reason or on account of Trustee adhering to the Settlor\u2019s instruction and executing this Trust within "
            "its mandate.",
            _clause_s,
        ),
        Paragraph(
            "13.2\u00a0\u00a0\u00a0This clause shall survive the determination of this Deed and continue for so long as is necessary "
            "to give its full effect, notwithstanding any other provision in this Deed.",
            _clause_s,
        ),
        Paragraph(
            "13.3\u00a0\u00a0\u00a0In the professed execution of the Trust and powers of the Trustee, the Trustee and its agents "
            "shall not be liable for any loss by reason of any improper asset allocation made in good faith or the "
            "carrying on of any business in good faith or in connection with the administration and management of "
            "the Trust by reason of any mistake or omission made in good faith by the Trustee unless it is caused "
            "by its own gross negligence or by commission of a willful act of breach of trust.",
            _clause_s,
        ),
        Paragraph(
            "13.4\u00a0\u00a0\u00a0The Trustee may validly act upon the opinion or advice of or information obtained from "
            "advocates and solicitors whether instructed by the Trustee and/or the Settlor and the Trustee may act "
            "upon any statements of or information obtained from the bankers, accountants, valuers and other "
            "persons appointed by the Trustee believed by the Trustee in good faith to be an expert in relation to "
            "the matters upon which they are consulted and the Trustee shall not be liable for anything done or "
            "suffered by it in good faith in reliance upon such opinion, advice, statements or information provide "
            "that any such bankers, accountants, valuers and other persons consulted.",
            _clause_s,
        ),
        Paragraph(
            "13.5\u00a0\u00a0\u00a0The Trustee is under no duty to insure the Trust and shall not be liable for failure to insure if "
            "subsequent loss or damage occurs to the Trust.",
            _clause_s,
        ),
        _sp(1.5),
        Paragraph("<b>INITIAL:</b>", _initial_s),
        _short_hr(),
    ]

    doc.build(story)
    return buffer.getvalue()
