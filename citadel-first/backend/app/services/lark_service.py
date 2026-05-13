"""Lark (Bitable) API integration — pushes trust KYC data to Vanguard's Lark tables.

5-step submission flow:
  1. Generate/reuse tenant access token
  2. Create Trust Info record → get record_id
  3. Create Settlor Info record (linked to trust record)
  4. Create Beneficiary records (linked to trust record)
  5. Upload PDF attachments + update Trust Info with file tokens

Includes automatic retry with exponential backoff (30s, 60s, 120s).
Each retry resumes from the last successful step using lark_trust_record_id.
"""

import asyncio
import logging
import time
from datetime import date, datetime

import httpx
from sqlalchemy import select

from app.core.config import settings
from app.core.database import AsyncSessionLocal
from app.models.trust_order import TrustOrder
from app.schemas.vtb_kyc import BeneficiaryData, CrsTaxResidencyData, VtbKycFormData

logger = logging.getLogger(__name__)

# ── Lark Bitable table IDs ──
TRUST_INFO_TABLE = "tblKZ8jH5ppXSREk"
SETTLOR_INFO_TABLE = "tblFOpW9wDONZ45F"
BENEFICIARY_TABLE = "tblOQGNgji24iqSt"

# ── Retry configuration ──
MAX_RETRIES = 3
RETRY_DELAYS = [30, 60, 120]  # seconds


# ═══════════════════════════════════════════════════════════════════════
# Token management
# ═══════════════════════════════════════════════════════════════════════

_token_cache: dict = {"token": "", "expires_at": 0.0}


async def _get_tenant_token() -> str:
    """Get a valid Lark tenant access token, refreshing if needed."""
    if _token_cache["token"] and time.time() < _token_cache["expires_at"] - 300:
        return _token_cache["token"]

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            f"{settings.LARK_API_BASE_URL}/auth/v3/tenant_access_token/internal",
            json={
                "app_id": settings.LARK_APP_ID,
                "app_secret": settings.LARK_APP_SECRET,
            },
        )
        response.raise_for_status()
        data = response.json()

    token = data["tenant_access_token"]
    expires_in = data.get("expire", 7200)
    _token_cache["token"] = token
    _token_cache["expires_at"] = time.time() + expires_in
    logger.info("Lark token refreshed, expires in %d seconds", expires_in)
    return token


async def _lark_headers() -> dict[str, str]:
    """Build authorization headers for Lark API calls."""
    token = await _get_tenant_token()
    return {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}


def _is_configured() -> bool:
    """Check if Lark integration is configured."""
    return bool(settings.LARK_APP_ID and settings.LARK_APP_SECRET and settings.LARK_BITABLE_APP_TOKEN)


# ═══════════════════════════════════════════════════════════════════════
# Data transformation functions (pure, testable)
# ═══════════════════════════════════════════════════════════════════════

# Legacy range maps kept for backward compatibility with existing records
INCOME_RANGE_MAP: dict[str, int] = {
    "Below RM25,000": 25000,
    "RM25,000 - RM50,000": 37500,
    "RM25,000 – RM50,000": 37500,
    "RM50,000 - RM100,000": 75000,
    "RM50,000 – RM100,000": 75000,
    "RM100,000 - RM250,000": 175000,
    "RM100,001 - RM250,000": 175000,
    "RM250,000 - RM500,000": 375000,
    "RM250,001 - RM500,000": 375000,
    "RM500,000 - RM1,000,000": 750000,
    "RM500,001 - RM1,000,000": 750000,
    "Above RM1,000,000": 1000000,
    "Above RM500,000": 750000,
}

NET_WORTH_RANGE_MAP: dict[str, int] = {
    "Below RM100,000": 100000,
    "RM100,000 - RM500,000": 300000,
    "RM100,000 – RM500,000": 300000,
    "RM100,001 - RM500,000": 300000,
    "RM500,000 - RM1,000,000": 750000,
    "RM500,001 - RM1,000,000": 750000,
    "RM1,000,000 - RM5,000,000": 3000000,
    "RM1,000,001 - RM5,000,000": 3000000,
    "Above RM5,000,000": 5000000,
}

KNOWN_SOURCE_OF_INCOME = {
    "Employment", "Business", "Investment", "Inheritance",
    "Gift", "Rental Income", "Others",
}


def _income_to_number(income_range: str | None) -> int | None:
    if not income_range or income_range == "N/A":
        return None
    # New format: numeric string like "75000"
    try:
        return int(float(income_range.replace(",", "")))
    except ValueError:
        pass
    # Legacy format: range string like "RM50,000 - RM100,000"
    return INCOME_RANGE_MAP.get(income_range)


def _net_worth_to_number(net_worth_range: str | None) -> int | None:
    if not net_worth_range or net_worth_range == "N/A":
        return None
    # New format: numeric string like "300000"
    try:
        return int(float(net_worth_range.replace(",", "")))
    except ValueError:
        pass
    # Legacy format: range string like "RM100,000 - RM500,000"
    return NET_WORTH_RANGE_MAP.get(net_worth_range)


def _bool_to_yes_no(value: str | bool | None) -> str:
    if value is True or value in ("True", "Yes", "yes", "1"):
        return "Yes"
    return "No"


def _date_to_ms_epoch(d: date | datetime | str | None) -> int | None:
    if d is None or d == "N/A" or d == "":
        return None
    if isinstance(d, str):
        try:
            d = datetime.strptime(d, "%d/%m/%Y").date()
        except ValueError:
            return None
    if isinstance(d, datetime):
        return int(d.timestamp() * 1000)
    if isinstance(d, date):
        return int(datetime(d.year, d.month, d.day).timestamp() * 1000)
    return None


def _beneficiary_type_to_lark(beneficiary_type: str) -> str:
    return {"pre_demise": "Pre Demise Beneficiaries", "post_demise": "Post Demise Beneficiaries"}.get(
        beneficiary_type, beneficiary_type
    )


def _split_source_of_income(source_of_income: str | None) -> tuple[str, str | None]:
    if not source_of_income or source_of_income == "N/A":
        return ("N/A", None)
    if source_of_income in KNOWN_SOURCE_OF_INCOME:
        return (source_of_income, None)
    return ("Others", source_of_income)


def _format_crs_residencies(crs_rows: list[CrsTaxResidencyData]) -> str:
    if not crs_rows:
        return "N/A"
    parts = []
    for row in crs_rows:
        jurisdiction = row.jurisdiction if row.jurisdiction != "N/A" else ""
        tin = row.tin if row.tin != "N/A" else "No TIN"
        if jurisdiction:
            parts.append(f"{jurisdiction}: {tin}")
    return "; ".join(parts) if parts else "N/A"


def _na(value: str | None) -> str | None:
    """Return None for N/A strings so they're omitted from Lark records."""
    if value is None or value == "N/A" or value == "":
        return None
    return value


# ═══════════════════════════════════════════════════════════════════════
# Step 2: Create Trust Info record
# ═══════════════════════════════════════════════════════════════════════

async def create_trust_info_record(
    data: VtbKycFormData,
    trust_order_id: int,
) -> str:
    headers = await _lark_headers()

    trust_amount = None
    if data.trust_asset_amount and data.trust_asset_amount != "N/A":
        try:
            cleaned = data.trust_asset_amount.replace("RM", "").replace(",", "").strip()
            trust_amount = float(cleaned)
        except (ValueError, TypeError):
            trust_amount = None

    signed_date_ms = _date_to_ms_epoch(data.date_of_trust_deed)

    fields = {
        "Order ID": trust_order_id,
        "Signed Date": signed_date_ms,
        "Trust Amount": trust_amount,
        "Advisor Name": _na(data.advisor_name),
        "Advisor NRIC": _na(data.advisor_nric),
        "Trust Plan Name Options": "CWD Trust",
    }
    fields = {k: v for k, v in fields.items() if v is not None}

    url = (
        f"{settings.LARK_API_BASE_URL}/bitable/v1/apps/{settings.LARK_BITABLE_APP_TOKEN}"
        f"/tables/{TRUST_INFO_TABLE}/records/batch_create"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(url, headers=headers, json={"records": [{"fields": fields}]})
        response.raise_for_status()
        result = response.json()

    if result.get("code") != 0:
        raise RuntimeError(f"Lark API error creating Trust Info: {result.get('msg')} — {result.get('error', {}).get('message', '')}")

    record_id = result["data"]["records"][0]["record_id"]
    logger.info("Lark: created Trust Info record_id=%s for order_id=%d", record_id, trust_order_id)
    return record_id


# ═══════════════════════════════════════════════════════════════════════
# Step 3: Create Settlor Info record
# ═══════════════════════════════════════════════════════════════════════

async def create_settlor_info_record(
    data: VtbKycFormData,
    trust_record_id: str,
) -> str:
    headers = await _lark_headers()

    nric_value = _na(data.identity_card_number) if data.identity_doc_type in ("MYKAD", "IKAD", "MYTENTERA") else None
    id_number_value = _na(data.identity_card_number) if data.identity_doc_type == "PASSPORT" else None

    primary_income, income_others = _split_source_of_income(data.source_of_income)
    crs_text = _format_crs_residencies(data.crs_residencies)
    annual_income_num = _income_to_number(data.annual_income_range)
    net_worth_num = _net_worth_to_number(data.estimated_net_worth)

    fields = {
        "English Name": _na(data.name),
        "Title": _na(data.title),
        "Gender": _na(data.gender),
        "Date of Birth": _date_to_ms_epoch(data.dob),
        "Nationality": _na(data.nationality),
        "NRIC": nric_value,
        "ID Number": id_number_value,
        "Passport Expiry": _date_to_ms_epoch(data.passport_expiry),
        "Marital status": _na(data.marital_status),
        "Residential Address": _na(data.residential_address),
        "Mailing Address": _na(data.mailing_address),
        "Home Tel Number": _na(data.home_telephone),
        "Mobile number": _na(data.mobile_number),
        "Email": _na(data.email),
        "Occupation": _na(data.occupation),
        "Work Title": _na(data.work_title),
        "Nature of Business": _na(data.nature_of_business),
        "Employer Name": _na(data.employer_name),
        "Employer Address": _na(data.employer_address),
        "Employer Tel Number": _na(data.employer_telephone),
        "Annual Income": annual_income_num,
        "Estimated Net Worth": net_worth_num,
        "Source of the Trust Fund": _na(data.source_of_trust_fund),
        "Source of Income": _na(primary_income) if primary_income != "N/A" else None,
        "Source of Income (Others)": income_others,
        "Client’s Country of Birth": _na(data.country_of_birth),
        "Client Physically Present": _bool_to_yes_no(data.physically_present),
        "Client Tax Residency and TIN": crs_text if crs_text != "N/A" else None,
        "Client Main Sources of Income And Capital": _na(data.main_sources_of_income),
        "Unusual Transactions": _bool_to_yes_no(data.has_unusual_transactions),
        "Client Marital Status History": _na(data.marital_history),
        "Client Geographical Connections": _na(data.geographical_connections),
        "Other Relevant Information": _na(data.other_relevant_info),
        "Trust Info": [trust_record_id],
    }
    fields = {k: v for k, v in fields.items() if v is not None}

    url = (
        f"{settings.LARK_API_BASE_URL}/bitable/v1/apps/{settings.LARK_BITABLE_APP_TOKEN}"
        f"/tables/{SETTLOR_INFO_TABLE}/records/batch_create"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(url, headers=headers, json={"records": [{"fields": fields}]})
        response.raise_for_status()
        result = response.json()

    if result.get("code") != 0:
        raise RuntimeError(f"Lark API error creating Settlor Info: {result.get('msg')} — {result.get('error', {}).get('message', '')}")

    record_id = result["data"]["records"][0]["record_id"]
    logger.info("Lark: created Settlor Info record_id=%s", record_id)
    return record_id


# ═══════════════════════════════════════════════════════════════════════
# Step 4: Create Beneficiary record
# ═══════════════════════════════════════════════════════════════════════

async def create_beneficiary_record(
    beneficiary: BeneficiaryData,
    trust_record_id: str,
) -> str:
    headers = await _lark_headers()

    share_pct = None
    if beneficiary.share_percentage and beneficiary.share_percentage != "N/A":
        try:
            share_pct = float(beneficiary.share_percentage.rstrip("%"))
        except (ValueError, TypeError):
            share_pct = None

    fields = {
        "English Name": _na(beneficiary.full_name),
        "Beneficiaries Type": _beneficiary_type_to_lark(beneficiary.beneficiary_type),
        "NRIC": _na(beneficiary.nric),
        "ID Number": _na(beneficiary.id_number),
        "Gender": _na(beneficiary.gender),
        "Date of Birth": _date_to_ms_epoch(beneficiary.dob),
        "Relationship With Settlor": _na(beneficiary.relationship_to_settlor),
        "Share Percentage (%)": share_pct,
        "Residential Address": _na(beneficiary.residential_address),
        "Mailing Address": _na(beneficiary.mailing_address),
        "Email Address": _na(beneficiary.email),
        "Contact Number": _na(beneficiary.contact_number),
        "Beneficiary Account Name": _na(beneficiary.bank_account_name),
        "Beneficiary Account Number": _na(beneficiary.bank_account_number),
        "Beneficiary Bank Name": _na(beneficiary.bank_name),
        # NOTE: "Swift code" — capital S matches Lark field name
        "Swift code": _na(beneficiary.bank_swift_code),
        # NOTE: "Benedficiary Bank Address" — typo is intentional, must match Lark
        "Benedficiary Bank Address": _na(beneficiary.bank_address),
        "Trust Info": [trust_record_id],
    }
    fields = {k: v for k, v in fields.items() if v is not None}

    url = (
        f"{settings.LARK_API_BASE_URL}/bitable/v1/apps/{settings.LARK_BITABLE_APP_TOKEN}"
        f"/tables/{BENEFICIARY_TABLE}/records/batch_create"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(url, headers=headers, json={"records": [{"fields": fields}]})
        response.raise_for_status()
        result = response.json()

    if result.get("code") != 0:
        raise RuntimeError(f"Lark API error creating Beneficiary: {result.get('msg')} — {result.get('error', {}).get('message', '')}")

    record_id = result["data"]["records"][0]["record_id"]
    logger.info("Lark: created Beneficiary record_id=%s type=%s", record_id, beneficiary.beneficiary_type)
    return record_id


# ═══════════════════════════════════════════════════════════════════════
# Step 5a: Upload file to Lark Drive
# ═══════════════════════════════════════════════════════════════════════

async def upload_file_to_lark(file_bytes: bytes, filename: str) -> str:
    token = await _get_tenant_token()

    url = f"{settings.LARK_API_BASE_URL}/drive/v1/medias/upload_all"

    async with httpx.AsyncClient(timeout=120) as client:
        response = await client.post(
            url,
            headers={"Authorization": f"Bearer {token}"},
            data={
                "parent_type": "bitable_file",
                "parent_node": settings.LARK_BITABLE_APP_TOKEN,
                "file_name": filename,
                "size": str(len(file_bytes)),
            },
            files={"file": (filename, file_bytes, "application/pdf")},
        )
        response.raise_for_status()
        result = response.json()

    if result.get("code") != 0:
        raise RuntimeError(f"Lark API error uploading file: {result.get('msg')} — {result.get('error', {}).get('message', '')}")

    file_token = result["data"]["file_token"]
    logger.info("Lark: uploaded file %s → file_token=%s", filename, file_token)
    return file_token


# ═══════════════════════════════════════════════════════════════════════
# Step 5b: Update Trust Info with attachment file tokens
# ═══════════════════════════════════════════════════════════════════════

async def update_trust_info_with_attachments(
    trust_record_id: str,
    attachments: dict[str, str],
) -> None:
    headers = await _lark_headers()

    fields = {}
    for field_name, file_token in attachments.items():
        if file_token:
            fields[field_name] = [{"file_token": file_token}]

    if not fields:
        return

    url = (
        f"{settings.LARK_API_BASE_URL}/bitable/v1/apps/{settings.LARK_BITABLE_APP_TOKEN}"
        f"/tables/{TRUST_INFO_TABLE}/records/batch_update"
    )

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            url,
            headers=headers,
            json={"records": [{"record_id": trust_record_id, "fields": fields}]},
        )
        response.raise_for_status()
        result = response.json()

    if result.get("code") != 0:
        raise RuntimeError(f"Lark API error updating Trust Info attachments: {result.get('msg')} — {result.get('error', {}).get('message', '')}")

    logger.info("Lark: updated Trust Info record_id=%s with %d attachments", trust_record_id, len(attachments))


# ═══════════════════════════════════════════════════════════════════════
# Database status helpers
# ═══════════════════════════════════════════════════════════════════════

async def _get_existing_lark_record_id(trust_order_id: int) -> str | None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(TrustOrder.lark_trust_record_id).where(TrustOrder.id == trust_order_id)
        )
        return result.scalar_one_or_none()


async def _save_lark_record_id(trust_order_id: int, record_id: str) -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(TrustOrder).where(TrustOrder.id == trust_order_id)
        )
        order = result.scalar_one_or_none()
        if order:
            order.lark_trust_record_id = record_id
            order.lark_submission_status = "IN_PROGRESS"
            await db.commit()


async def _update_lark_status(
    trust_order_id: int,
    status: str,
    error: str | None = None,
) -> None:
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(TrustOrder).where(TrustOrder.id == trust_order_id)
        )
        order = result.scalar_one_or_none()
        if order:
            order.lark_submission_status = status
            if status == "SUBMITTED":
                order.lark_submitted_at = datetime.now()
                order.lark_error_message = None
            elif error:
                order.lark_error_message = error[:2000]
            await db.commit()


# ═══════════════════════════════════════════════════════════════════════
# Core step executor (resume-aware)
# ═══════════════════════════════════════════════════════════════════════

async def _execute_lark_steps(
    data: VtbKycFormData,
    pdfs: dict[str, bytes],
    trust_order_id: int,
) -> None:
    """Execute the 5 Lark submission steps, resuming from the last successful step."""
    trust_record_id = await _get_existing_lark_record_id(trust_order_id)

    # Step 2: Create Trust Info (skip if record_id already exists)
    if not trust_record_id:
        trust_record_id = await create_trust_info_record(data, trust_order_id)
        await _save_lark_record_id(trust_order_id, trust_record_id)

    # Step 3: Create Settlor Info
    await create_settlor_info_record(data, trust_record_id)

    # Step 4: Create Beneficiary records
    all_beneficiaries = list(data.pre_demise_beneficiaries or []) + list(
        data.post_demise_beneficiaries or []
    )
    for ben in all_beneficiaries:
        await create_beneficiary_record(ben, trust_record_id)

    # Step 5: Upload and link attachments (A1, A2, B2, B3, B4, B6)
    lark_field_map = {
        "A1": "A1 Form", "A2": "A2 Form",
        "B2": "B2 Form", "B3": "B3 Form", "B4": "B4 Form",
        "B6": "B6 Form",
    }
    attachments: dict[str, str] = {}
    for form_id, lark_field in lark_field_map.items():
        if form_id in pdfs:
            filename = f"VTB_{form_id}_{data.name.replace(' ', '_')}.pdf"
            file_token = await upload_file_to_lark(pdfs[form_id], filename)
            attachments[lark_field] = file_token

    if attachments:
        await update_trust_info_with_attachments(trust_record_id, attachments)

    # Mark as submitted
    await _update_lark_status(trust_order_id, "SUBMITTED")


# ═══════════════════════════════════════════════════════════════════════
# Orchestrator with auto-retry
# ═══════════════════════════════════════════════════════════════════════

async def submit_kyc_to_lark(
    data: VtbKycFormData,
    pdfs: dict[str, bytes],
    trust_order_id: int,
) -> None:
    """Submit KYC data to Lark with automatic retry on failure.

    Retries up to 3 times with exponential backoff (30s, 60s, 120s).
    Each retry resumes from the last successful step using lark_trust_record_id.
    """
    if not _is_configured():
        logger.warning("Lark integration not configured; skipping submission for order_id=%d", trust_order_id)
        return

    for attempt in range(MAX_RETRIES + 1):
        try:
            await _execute_lark_steps(data, pdfs, trust_order_id)
            logger.info("Lark submission succeeded for order_id=%d on attempt %d", trust_order_id, attempt + 1)
            return
        except Exception as exc:
            if attempt < MAX_RETRIES:
                delay = RETRY_DELAYS[attempt]
                logger.warning(
                    "Lark submission attempt %d/%d failed for order_id=%d, "
                    "retrying in %ds: %s",
                    attempt + 1, MAX_RETRIES + 1, trust_order_id,
                    delay, exc,
                )
                await asyncio.sleep(delay)
            else:
                await _update_lark_status(trust_order_id, "FAILED", error=str(exc)[:2000])
                logger.exception(
                    "Lark submission failed after %d attempts for order_id=%d",
                    MAX_RETRIES + 1, trust_order_id,
                )
                raise