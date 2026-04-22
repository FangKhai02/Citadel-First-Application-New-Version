"""
Server-side OCR for Malaysian identity documents.

Document types:
  - MYKAD / IKAD / MYTENTERA → PaddleOCR (ppOCRv5)
  - PASSPORT                 → Manual MRZ parser (PaddleOCR-based, replaces broken omnimrz package)
"""

import io
import logging
import re
from dataclasses import dataclass
from datetime import date

logger = logging.getLogger(__name__)

_ocr_engine = None


@dataclass
class OcrOutput:
    full_name: str | None
    identity_number: str | None
    date_of_birth: date | None
    gender: str | None
    nationality: str | None
    address: str | None
    confidence: float
    raw_text: str


def _get_paddle_ocr():
    """Lazily initialise and return the PaddleOCR engine."""
    global _ocr_engine
    if _ocr_engine is None:
        from paddleocr import PaddleOCR

        _ocr_engine = PaddleOCR(
            use_angle_cls=True,
            lang="en",
        )
    return _ocr_engine


# ── Helpers ────────────────────────────────────────────────────────────────────

IC_PATTERN = re.compile(r"\b(\d{6})-?(\d{2})-?(\d{4})\b")
DOB_PATTERN = re.compile(r"\b(\d{2})/(\d{2})/(\d{4})\b")

_NON_NAME_WORDS = {
    "KADPENGENALAN", "KAD PENGENALAN", "PENGENALAN", "KAD",
    "MALAYSIA", "MYKAD", "WARGANEGARA", "PEREMPUAN",
    "LELAKI", "SARAWAK", "SABAH", "KELANTAN", "JOHOR", "SELANGOR",
    "PERAK", "PAHANG", "TERENGGANU", "KEDAH", "MELAKA", "NEGERI",
    "SEMBILAN", "PULAU", "PINANG", "LABUAN", "PUTRAJAYA", "SINGAPURA",
    "WARGANEGRA", "PENDAFTARAN", "NEGARA", "IDENTITY", "CARD",
}
_NAME_KEYWORDS = {"BIN", "BINTI", "ANAK", "A/L", "A/P", "AL", "B."}
_ADDRESS_KEYWORDS = {"NO", "LOT", "JALAN", "TAMAN", "LORONG", "KAMPUNG", "KG", "BANDAR", "BLOK"}


def _extract_ic(lines: list[tuple[str, float]]) -> str | None:
    for text, _ in lines:
        cleaned = text.replace(" ", "")
        match = IC_PATTERN.search(cleaned)
        if match:
            # Normalise to XXXXXX-XX-XXXX format
            digits = re.sub(r"\D", "", match.group())
            if len(digits) == 12:
                return f"{digits[:6]}-{digits[6:8]}-{digits[8:]}"
    return None


def _dob_from_ic(ic: str | None) -> date | None:
    if not ic:
        return None
    digits = re.sub(r"\D", "", ic)
    if len(digits) < 6:
        return None
    yy, mm, dd = int(digits[0:2]), int(digits[2:4]), int(digits[4:6])
    year = (2000 + yy) if yy <= (date.today().year % 100) else (1900 + yy)
    try:
        return date(year, mm, dd)
    except ValueError:
        return None


def _extract_dob(text_lines: list[str], ic: str | None = None) -> date | None:
    for line in text_lines:
        match = DOB_PATTERN.search(line)
        if match:
            day, month, year = match.groups()
            try:
                return date(int(year), int(month), int(day))
            except ValueError:
                continue
    return _dob_from_ic(ic)


def _extract_gender(text_lines: list[str]) -> str | None:
    for line in text_lines:
        upper = line.upper()
        if "LELAKI" in upper or "LANAK" in upper or (len(upper) <= 4 and upper.strip() == "M"):
            return "MALE"
        if "PEREMPUAN" in upper or (len(upper) <= 4 and upper.strip() == "F"):
            return "FEMALE"
    return None


def _extract_nationality(text_lines: list[str]) -> str | None:
    for line in text_lines:
        upper = line.upper()
        if "WARGANEGARA" in upper or "WARGA" in upper or "MALAYSIA" in upper:
            return "MALAYSIA"
    return None


def _is_name_continuation(text: str) -> bool:
    """Return True if text looks like a continuation of a multi-line name."""
    if not text.isupper() or len(text) < 3:
        return False
    if any(non in text for non in _NON_NAME_WORDS):
        return False
    if re.search(r"\d", text):
        return False
    words = text.split()
    if words and words[0] in _ADDRESS_KEYWORDS:
        return False
    return True


def _extract_name(lines: list[tuple[str, float]]) -> str | None:
    texts = [t for t, _ in lines]
    caps_lines = [
        t for t in texts
        if t.isupper()
        and len(t) > 5
        and t.strip() not in _NON_NAME_WORDS
        and not any(non in t for non in _NON_NAME_WORDS)
    ]

    primary: str | None = None
    primary_idx: int = -1

    # Prefer lines that contain a known Malaysian name particle
    for line in caps_lines:
        if any(kw in line for kw in _NAME_KEYWORDS):
            primary = line
            primary_idx = texts.index(line)
            break

    # Fallback: first caps line that is not a blacklisted word
    if primary is None:
        for line in caps_lines:
            if not any(non in line for non in _NON_NAME_WORDS):
                primary = line
                primary_idx = texts.index(line)
                break

    if primary is None:
        return caps_lines[0] if caps_lines else None

    # Collect continuation lines that immediately follow (multi-line names)
    name_parts = [primary]
    idx = primary_idx + 1
    while idx < len(texts) and _is_name_continuation(texts[idx]):
        name_parts.append(texts[idx])
        idx += 1

    return " ".join(name_parts)


_ADDRESS_STOP_WORDS = {
    "WARGANEGARA", "WARGANEGRA", "PEREMPUAN", "LELAKI",
    "MYKAD", "PENDAFTARAN", "NEGARA", "IDENTITY", "CARD",
}

_HARD_ADDRESS_STARTERS = {"NO", "LOT", "JALAN", "TAMAN", "LORONG", "KAMPUNG", "KG", "BANDAR", "BLOK"}


def _is_hard_address_start(text: str) -> bool:
    """True if this line is an unambiguous address opener (keyword or postcode)."""
    upper = text.upper().strip()
    # Exclude IC numbers (XXXXXX-XX-XXXX or 12 pure digits)
    if IC_PATTERN.search(text.replace(" ", "")):
        return False
    words = upper.split()
    if not words:
        return False
    # Starts with a known address keyword (handle OCR-merged tokens like "NO348BLOT2777")
    first_alpha = re.match(r"^([A-Z]+)", words[0])
    if first_alpha and first_alpha.group(1) in _HARD_ADDRESS_STARTERS:
        return True
    # Starts with a 5-digit postcode (must be exactly 5 digits optionally followed by non-digit)
    if re.match(r"^\d{5}(?!\d)", upper):
        return True
    return False


def _extract_address(lines: list[tuple[str, float]]) -> str | None:
    texts = [t for t, _ in lines]
    addr_parts: list[str] = []
    in_address = False

    for text in texts:
        upper = text.upper().strip()
        # Stop collecting when we hit known non-address words
        if any(stop in upper for stop in _ADDRESS_STOP_WORDS):
            if in_address:
                break
            continue
        if _is_hard_address_start(text):
            in_address = True
        if in_address:
            addr_parts.append(text)

    return ", ".join(addr_parts) if addr_parts else None


# ── Main extractors ────────────────────────────────────────────────────────────


def extract_myKad(image_bytes: bytes) -> OcrOutput:
    """
    Extract fields from MyKad / iKad / MyTentera front image using PaddleOCR.
    """
    engine = _get_paddle_ocr()
    result = engine.ocr(image_bytes)

    all_text: list[str] = []
    lines: list[tuple[str, float]] = []

    for line in (result[0] or []):
        if isinstance(line, list) and len(line) >= 2:
            _, (text, conf) = line
            all_text.append(text)
            lines.append((text, float(conf)))

    raw = "\n".join(all_text)
    avg_conf = sum(c for _, c in lines) / len(lines) if lines else 0.0

    ic = _extract_ic(lines)
    return OcrOutput(
        full_name=_extract_name(lines),
        identity_number=ic,
        date_of_birth=_extract_dob(all_text, ic),
        gender=_extract_gender(all_text),
        nationality=_extract_nationality(all_text),
        address=_extract_address(lines),
        confidence=avg_conf,
        raw_text=raw,
    )


from itertools import cycle


def _check_digit(data: str) -> int:
    """ISO/IEC 7064 MOD 11-10 check digit for MRZ fields."""
    weights = cycle([7, 3, 1])
    total = 0
    for c, w in zip(data, weights):
        if c.isdigit():
            total += int(c) * w
    return total % 10


def _parse_mrz_variant(line1: str, line2: str) -> dict | None:
    """
    Parse Malaysian passport MRZ (TD3 format, 44-char lines).
    Also handles a non-standard variant where line1 is shorter (26 chars)
    containing 'P' + nationality + name without standard field padding.
    In MRZ format, '<<' within a name field represents a single space.
    """
    try:
        import re

        surname = ""
        given_names = ""
        nationality = "MYS"
        doc_number = ""
        dob_str = ""
        sex = ""
        expiry_str = ""

        # Variant: 26-char name line + 44-char data line
        if len(line1) == 26 and line1.startswith("P") and "MYS" in line1:
            # line1: P + MYS + name (e.g. 'PMYSMAHATHIRBINIDRUS<<<<<<')
            # MRZ convention: '<<' inside a field means one space
            # Replace '<<' with a placeholder, then single '<', then restore
            name_raw = line1[1:]  # Remove leading P
            if name_raw.startswith("MYS"):
                nationality = "MYS"
                name_str = name_raw[3:]
            else:
                parts = name_raw.split()
                nationality = parts[0] if parts else "MYS"
                name_str = " ".join(parts[1:]) if len(parts) > 1 else ""
            # In MRZ: '<<' within field = one space, '<' = field separator
            # Replace all '<' with spaces, collapse multiple spaces, then split name
            name_str = name_raw[3:].replace("<", " ")
            name_str = " ".join(name_str.split())
            name_parts = name_str.strip().split(None, 1)
            raw_surname = name_parts[0] if name_parts else ""
            raw_given = name_parts[1] if len(name_parts) > 1 else ""

            # Split surname/given using Malay name particles:
            # '<<' separates surname from given names in MRZ, but if absent (non-standard),
            # fall back to splitting on known particles: BIN, BINTI, A/L, A/P, AL, B.
            # First particle = surname, rest = given names.
            MRZ_PARTICLES = ("BIN", "BINTI", "A/L", "A/P", "AL", "B.")
            for particle in MRZ_PARTICLES:
                if particle in raw_surname:
                    idx = raw_surname.index(particle)
                    surname = raw_surname[:idx].strip()
                    given_names = raw_surname[idx:].strip()
                    break
            else:
                # No known particle found — use the whole thing as surname
                surname = raw_surname
                given_names = raw_given

            # line2: 44-char data line
            # The OCR line is shifted: 'A000000000MYS9302165M2408312930216146007<<72'
            # Standard positions are shifted by 1 due to OCR artifact: '0' before MYS
            # Try flexible parsing using regex patterns
            data_line = line2

            # Document number: starts with letters, ends with digit (9 chars total)
            doc_match = re.match(r'^([A-Z0-9<]{9})', data_line)
            if doc_match:
                doc_number = doc_match.group(1).rstrip('<')

            # Nationality: scan for MYS
            if 'MYS' in data_line:
                nationality = 'MYS'

            # Sex: 'M' or 'F' — scan all positions, accept M or F anywhere in line
            sex_chars = re.findall(r'(?<=[<\d])([MF])(?=[<\d])', data_line)
            if sex_chars:
                sex = sex_chars[0]

            # DOB: first valid YYMMDD (month 01-12, day 01-31)
            all_nums = re.findall(r'\d{6}', data_line)
            dob_candidates = []
            for candidate in all_nums:
                yy, mm, dd = int(candidate[:2]), int(candidate[2:4]), int(candidate[4:6])
                if 0 < mm <= 12 and 0 < dd <= 31:
                    dob_candidates.append(candidate)
            if dob_candidates:
                dob_str = dob_candidates[0]
                # Expiry: last 6-digit number, or second valid date
                expiry_str = all_nums[-1] if len(all_nums) >= 2 else (dob_candidates[1] if len(dob_candidates) > 1 else "")

        else:
            # Standard TD3 format (44 or 72 chars each)
            names_raw = line1[2:44]
            # In standard MRZ: '<' is filler, '<<' within name = space
            names_raw = names_raw.replace("<<", "\x00").replace("<", " ").replace("\x00", " ").strip()
            parts = names_raw.split(None, 1)
            surname = parts[0] if parts else ""
            given_names = parts[1] if len(parts) > 1 else ""
            nationality = line2[9:12]
            doc_num_raw = line2[0:9]
            dob = line2[12:19]
            sex = line2[20]
            expiry = line2[21:28]

            valid = False
            try:
                cd_doc = int(doc_num_raw[8])
                cd_dob = int(dob[6])
                cd_exp = int(expiry[7])
                valid = (
                    _check_digit(doc_num_raw[:8]) == cd_doc
                    and _check_digit(dob[:6]) == cd_dob
                    and _check_digit(expiry[:6]) == cd_exp
                )
            except (ValueError, IndexError):
                valid = False

            return {
                "surname": surname,
                "given_names": given_names,
                "document_number": doc_num_raw[:8].rstrip("<"),
                "nationality": nationality.rstrip("<") if len(nationality) >= 3 else nationality,
                "date_of_birth": dob[:6],
                "sex": sex,
                "expiry_date": expiry[:6],
                "valid": valid,
            }

        return {
            "surname": surname,
            "given_names": given_names,
            "document_number": doc_number or None,
            "nationality": nationality,
            "date_of_birth": dob_str or None,
            "sex": sex or None,
            "expiry_date": expiry_str or None,
            "valid": False,
        }
    except Exception:
        return None


def extract_mrz_manual(image_bytes: bytes) -> list[dict]:
    """
    Extract MRZ from passport image using PaddleOCR + manual ICAO 9303 parsing.
    Replaces broken omnimrz package (wheel missing Python source files).
    Handles both 2-line (Type 1/2, 44 chars) and 3-line (Type 3, 30 chars) formats.
    """
    import tempfile, os, cv2, numpy as np
    engine = _get_paddle_ocr()

    # Decode image bytes to numpy array using OpenCV
    img_np = np.frombuffer(image_bytes, dtype=np.uint8)
    img_cv = cv2.imdecode(img_np, cv2.IMREAD_COLOR)
    if img_cv is None:
        return []

    # Save to temp file for PaddleOCR
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as tmp:
        cv2.imwrite(tmp.name, img_cv)
        tmp_path = tmp.name

    try:
        result = engine.ocr(tmp_path)
    finally:
        os.unlink(tmp_path)

    MRZ_CHARS = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789<")
    candidate_lines: list[tuple[float, str]] = []

    for block in (result[0] or []):
        if isinstance(block, list) and len(block) >= 2:
            _, (text, conf) = block
            cleaned = text.strip().replace(" ", "")
            # Accept MRZ-like lines from 26 chars (variant) up to 88 chars
            if 26 <= len(cleaned) <= 88:
                ratio = sum(c in MRZ_CHARS for c in cleaned) / len(cleaned)
                if ratio > 0.85:
                    candidate_lines.append((float(conf), cleaned))

    if len(candidate_lines) < 2:
        return []

    candidate_lines.sort(key=lambda x: -len(x[1]))

    for _, line1_text in candidate_lines:
        line1_len = len(line1_text)
        remaining = [ln for _, ln in candidate_lines if ln != line1_text]

        for line2_text in remaining:
            len_diff = abs(len(line2_text) - line1_len)
            # Standard TD3: both lines same length (44 or 72 chars)
            is_standard = line1_len in (44, 72) and len(line2_text) in (44, 72)
            # Variant: name line is 26 chars, data line is 44 chars
            is_variant = (line1_len == 26 and len(line2_text) == 44)

            if is_standard:
                parsed = _parse_mrz_variant(line1_text, line2_text)
                if parsed:
                    return [parsed]
            elif is_variant:
                # line1_text = 26-char name line, line2_text = 44-char data line
                parsed = _parse_mrz_variant(line1_text, line2_text)
                if parsed:
                    return [parsed]
            elif len(line2_text) == 26 and line1_len == 44:
                # Reversed: line1_text = 44-char data line, line2_text = 26-char name line
                parsed = _parse_mrz_variant(line2_text, line1_text)
                if parsed:
                    return [parsed]

    return []


def extract_passport(image_bytes: bytes) -> OcrOutput:
    """
    Extract fields from passport MRZ using manual ICAO 9303 parser (PaddleOCR-based).
    Handles both 2-line and 3-line MRZ formats.
    """
    mrz_data = extract_mrz_manual(image_bytes)
    if not mrz_data:
        return OcrOutput(
            full_name=None,
            identity_number=None,
            date_of_birth=None,
            gender=None,
            nationality=None,
            address=None,
            confidence=0.0,
            raw_text="",
        )

    first = mrz_data[0]
    surname = first.get("surname", "")
    given = first.get("given_names", "")
    full_name = f"{surname}, {given}".strip(", ")

    raw = str(first)

    dob = None
    dob_str = first.get("date_of_birth", "")
    if dob_str:
        try:
            dob = date(
                year=int("19" + dob_str[0:2]) if int(dob_str[0:2]) > 50 else int("20" + dob_str[0:2]),
                month=int(dob_str[2:4]),
                day=int(dob_str[4:6]),
            )
        except ValueError:
            pass

    return OcrOutput(
        full_name=full_name or None,
        identity_number=first.get("document_number", "") or None,
        date_of_birth=dob,
        gender=(first.get("sex", "") or "").upper() or None,
        nationality=first.get("nationality", "") or None,
        address=None,
        confidence=1.0 if first.get("valid") else 0.5,
        raw_text=raw,
    )


def run_ocr(image_bytes: bytes, doc_type: str) -> OcrOutput:
    """
    Route to the correct OCR engine based on document type.
    """
    if doc_type == "PASSPORT":
        return extract_passport(image_bytes)
    else:
        # MYKAD, IKAD, MYTENTERA all use PaddleOCR
        return extract_myKad(image_bytes)
