# Vanguard Lark (Bitable) API Integration Flow

## Overview

When a client submits a trust order, the Citadel app pushes all KYC data to Vanguard's Lark Bitable tables via the Lark Open API. This happens automatically in the background alongside the existing email flow.

---

## Architecture

```
Client App                    Citadel Backend                     Vanguard Lark
─────────                     ───────────────                     ─────────────
                                  
Trust Order Created ─────────► Background Task                    
         │                         │                              
         │                         ├── 1. Assemble KYC Data       
         │                         ├── 2. Generate 6 PDFs         
         │                         ├── 3. Upload to S3             
         │                         ├── 4. Email to Vanguard ──────► Email inbox
         │                         └── 5. Submit to Lark ──────────► Lark Bitable
         │                                 │                              
         │                                 ├─ Step 1: Get Token ────► Tenant Token
         │                                 ├─ Step 2: Trust Info ───► Record (recXXXX)
         │                                 ├─ Step 3: Settlor Info ─► Record
         │                                 ├─ Step 4: Beneficiaries ─► Records
         │                                 ├─ Step 5a: Upload PDFs ──► File tokens
         │                                 └─ Step 5b: Link PDFs ────► Trust Info updated
```

**Key principle:** Lark failure NEVER blocks the email/S3 flow.

---

## Lark API Credentials

| Credential | Env Variable | Source |
|-----------|-------------|--------|
| App ID | `LARK_APP_ID` | Provided by Vanguard, stored in `.env` |
| App Secret | `LARK_APP_SECRET` | Provided by Vanguard, stored in `.env` |
| App Token | `LARK_BITABLE_APP_TOKEN` | Provided by Vanguard, stored in `.env` |
| API Base URL | `LARK_API_BASE_URL` | Defaults to `https://open.larksuite.com/open-apis` |

These are stored in `.env` as `LARK_APP_ID`, `LARK_APP_SECRET`, `LARK_BITABLE_APP_TOKEN`, and `LARK_API_BASE_URL`.

---

## Lark Bitable Tables

| Table | Table ID | Purpose |
|-------|----------|---------|
| Trust Info | `tblKZ8jH5ppXSREk` | Trust order details (amount, advisor, dates) |
| Settlor Info | `tblFOpW9wDONZ45F` | Client personal, contact, employment, KYC data |
| Beneficiaries | `tblOQGNgji24iqSt` | Beneficiary personal, bank, and share allocation data |

---

## Step-by-Step Submission Flow

### Step 1: Generate Tenant Access Token

```
POST https://open.larksuite.com/open-apis/auth/v3/tenant_access_token/internal

Request:
{
  "app_id": "<LARK_APP_ID>",
  "app_secret": "<LARK_APP_SECRET>"
}

Response:
{
  "code": 0,
  "tenant_access_token": "<tenant_access_token>",
  "expire": 7200
}
```

- Token is cached and auto-refreshed 5 minutes before expiry
- Used as `Authorization: Bearer {token}` in all subsequent calls

---

### Step 2: Create Trust Info Record

```
POST https://open.larksuite.com/open-apis/bitable/v1/apps/{app_token}/tables/tblKZ8jH5ppXSREk/records/batch_create

Request:
{
  "records": [{
    "fields": {
      "Signed Date": 1713340800000,           // Date of trust deed as ms epoch
      "Trust Amount": 50000,                     // Numeric amount (no RM prefix)
      "Advisor Name": "John Advisor",
      "Advisor NRIC": "901234567890",
      "Advisor Code": null,                      // May be null initially
      "Trust Plan Name Options ": "CWD Trust"    // NOTE: trailing space is intentional
    }
  }]
}

Response:
{
  "code": 0,
  "data": {
    "records": [{ "record_id": "recXXXXXX", "fields": { ... } }]
  }
}
```

**Save the `record_id`** — it links Settlor and Beneficiary records to this trust.

| Lark Field | Type | Source | Transformation |
|-----------|------|--------|----------------|
| `Signed Date` | timestamp (ms) | `TrustOrder.date_of_trust_deed` | Convert date to ms epoch |
| `Trust Amount` | number | `VtbKycFormData.trust_asset_amount` | Strip "RM", commas, parse to float |
| `Advisor Name` | string | `TrustOrder.advisor_name` | Direct |
| `Advisor NRIC` | string | `TrustOrder.advisor_nric` | Direct |
| `Advisor Code` | string | `TrustOrder.advisor_code` | May be null |
| `Trust Plan Name Options` | string | Constant | `"CWD Trust"` |

---

### Step 3: Create Settlor Info Record

```
POST https://open.larksuite.com/open-apis/bitable/v1/apps/{app_token}/tables/tblFOpW9wDONZ45F/records/batch_create
```

**27 fields** mapped from `VtbKycFormData`:

| Lark Field | Type | Source | Transformation |
|-----------|------|--------|----------------|
| `English Name` | string | `UserDetails.name` | Direct |
| `Title` | string | `UserDetails.title` | Direct |
| `Gender` | string | `UserDetails.gender` | "Male"/"Female" |
| `Date of Birth` | timestamp | `UserDetails.dob` | DD/MM/YYYY → ms epoch |
| `Nationality` | string | `UserDetails.nationality` | Direct |
| `NRIC` | string | `UserDetails.identity_card_number` | Only when doc type is MYKAD/IKAD/MYTENTERA |
| `ID Number` | string | `UserDetails.identity_card_number` | Only when doc type is PASSPORT |
| `Passport Expiry` | timestamp | `UserDetails.passport_expiry` | DD/MM/YYYY → ms epoch |
| `Marital status` | string | `UserDetails.marital_status` | Direct |
| `Residential Address` | string | `UserDetails.residential_address` | Direct |
| `Mailing Address` | string | `UserDetails.mailing_address` | Direct |
| `Home Tel Number` | string | `UserDetails.home_telephone` | Direct |
| `Mobile number` | string | `UserDetails.mobile_number` | Direct |
| `Email` | string | `UserDetails.email` | Direct |
| `Occupation` | string | `UserDetails.occupation` | Direct |
| `Work Title` | string | `UserDetails.work_title` | Direct |
| `Nature of Business` | string | `UserDetails.nature_of_business` | Direct |
| `Employer Name` | string | `UserDetails.employer_name` | Direct |
| `Employer Address` | string | `UserDetails.employer_address` | Direct |
| `Employer Tel Number` | string | `UserDetails.employer_telephone` | Direct |
| `Annual Income` | **number** | `UserDetails.annual_income_range` | Numeric string → int (e.g. "75000" → 75000). Legacy range strings mapped via lookup table. |
| `Estimated Net Worth` | **number** | `UserDetails.estimated_net_worth` | Numeric string → int (e.g. "300000" → 300000). Legacy range strings mapped via lookup table. |
| `Source of the Trust Fund` | string | `UserDetails.source_of_trust_fund` | Direct |
| `Source of Income` | string | `UserDetails.source_of_income` | Known dropdown value or "Others" |
| `Source of Income (Others)` | string | `UserDetails.source_of_income` | Custom text when "Others" |
| `Client's Country of Birth` | string | `UserDetails.country_of_birth` | Direct |
| `Client Physically Present` | string | `UserDetails.physically_present` | Boolean → "Yes"/"No" |
| `Client Tax Residency and TIN` | string | `CrsTaxResidency` rows | Concatenated: "Malaysia: TIN12345; Singapore: No TIN" |
| `Client Main Sources of Income And Capital` | string | `UserDetails.main_sources_of_income` | Direct |
| `Unusual Transactions` | string | `UserDetails.has_unusual_transactions` | Boolean → "Yes"/"No" |
| `Client Marital Status History` | string | `UserDetails.marital_history` | Direct |
| `Client Geographical Connections` | string | `UserDetails.geographical_connections` | Direct |
| `Other Relevant Information` | string | `UserDetails.other_relevant_info` | Direct |
| `Trust Info` | linked record | From Step 2 | `[record_id]` array |

#### Annual Income → Number Mapping

New users enter a numeric value directly (e.g. `75000`). The value is parsed as an integer and sent to Lark.

Legacy range strings from existing records are mapped as follows:

| Stored Value | Lark Number Value |
|--------------|-------------------|
| Below RM25,000 | 25000 |
| RM25,000 - RM50,000 / RM25,000 – RM50,000 | 37500 |
| RM50,000 - RM100,000 / RM50,000 – RM100,000 | 75000 |
| RM100,000 - RM250,000 / RM100,001 - RM250,000 | 175000 |
| RM250,000 - RM500,000 / RM250,001 - RM500,000 | 375000 |
| RM500,000 - RM1,000,000 / RM500,001 - RM1,000,000 | 750000 |
| Above RM1,000,000 | 1000000 |
| Above RM500,000 | 750000 |

#### Net Worth → Number Mapping

New users enter a numeric value directly (e.g. `300000`). The value is parsed as an integer and sent to Lark.

Legacy range strings from existing records are mapped as follows:

| Stored Value | Lark Number Value |
|--------------|-------------------|
| Below RM100,000 | 100000 |
| RM100,000 - RM500,000 / RM100,000 – RM500,000 | 300000 |
| RM100,001 - RM500,000 | 300000 |
| RM500,000 - RM1,000,000 / RM500,001 - RM1,000,000 | 750000 |
| RM1,000,000 - RM5,000,000 / RM1,000,001 - RM5,000,000 | 3000000 |
| Above RM5,000,000 | 5000000 |

#### Source of Income Splitting

```
If source_of_income is a known dropdown value (Employment, Business, etc.):
  → "Source of Income": "Employment"
  → "Source of Income (Others)": null

If source_of_income is custom text (user typed "Freelance consulting"):
  → "Source of Income": "Others"
  → "Source of Income (Others)": "Freelance consulting"
```

---

### Step 4: Create Beneficiary Records

```
POST https://open.larksuite.com/open-apis/bitable/v1/apps/{app_token}/tables/tblOQGNgji24iqSt/records/batch_create
```

One API call per beneficiary (up to 2 pre-demise + up to 5 post-demise):

| Lark Field | Type | Source | Transformation |
|-----------|------|--------|----------------|
| `English Name` | string | `Beneficiary.full_name` | Direct |
| `Beneficiaries Type` | string | `Beneficiary.beneficiary_type` | "pre_demise" → "Pre Demise Beneficiaries", "post_demise" → "Post Demise Beneficiaries" |
| `NRIC` | string | `Beneficiary.nric` | Direct |
| `ID Number` | string | `Beneficiary.id_number` | Direct |
| `Gender` | string | `Beneficiary.gender` | "Male"/"Female" |
| `Date of Birth` | timestamp | `Beneficiary.dob` | DD/MM/YYYY → ms epoch |
| `Relationship With Settlor` | string | `Beneficiary.relationship_to_settlor` | Direct |
| `Share Percentage (%)` | number | `Beneficiary.share_percentage` | Strip "%" suffix, parse to float |
| `Residential Address` | string | `Beneficiary.residential_address` | Direct |
| `Mailing Address` | string | `Beneficiary.mailing_address` | Direct |
| `Email Address` | string | `Beneficiary.email` | Direct |
| `Contact Number` | string | `Beneficiary.contact_number` | Direct |
| `Beneficiary Account Name` | string | `Beneficiary.bank_account_name` | Direct |
| `Beneficiary Account Number` | string | `Beneficiary.bank_account_number` | Direct |
| `Beneficiary Bank Name` | string | `Beneficiary.bank_name` | Direct |
| `Swift code` | string | `Beneficiary.bank_swift_code` | Direct (capital S) |
| `Benedficiary Bank Address` | string | `Beneficiary.bank_address` | Direct (typo preserved!) |
| `Trust Info` | linked record | From Step 2 | `[record_id]` array |

---

### Step 5a: Upload PDF Files

```
POST https://open.larksuite.com/open-apis/drive/v1/medias/upload_all

Content-Type: multipart/form-data

Fields:
  parent_type: "bitable_file"
  parent_node: {app_token}
  file_name: "VTB_A2_John_Doe.pdf"
  size: {file_size_in_bytes}
  file: (binary PDF content)

Response:
{
  "code": 0,
  "data": { "file_token": "file_xxx" }
}
```

**Only these 4 forms are uploaded** (A1 and B4 are NOT uploaded to Lark):

| PDF Form | Lark Attachment Field |
|----------|----------------------|
| A2 | `A2 Form` |
| B2 | `B2 Form` |
| B3 | `B3 Form` |
| B6 | `B6 Form` |

---

### Step 5b: Update Trust Info with File Attachments

```
POST https://open.larksuite.com/open-apis/bitable/v1/apps/{app_token}/tables/tblKZ8jH5ppXSREk/records/batch_update

Request:
{
  "records": [{
    "record_id": "recXXXXXX",
    "fields": {
      "A2 Form": [{"file_token": "file_xxx"}],
      "B2 Form": [{"file_token": "file_yyy"}],
      "B3 Form": [{"file_token": "file_zzz"}],
      "B6 Form": [{"file_token": "file_www"}]
    }
  }]
}
```

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Client Submits Trust Order                │
│                     POST /trust-orders                        │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Background Task: generate_and_email_kyc_forms   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  1. Assemble KYC Data                                │   │
│  │     Query: user_details, trust_orders,                │   │
│  │     crs_tax_residency, pep_declaration, beneficiaries │   │
│  │     → VtbKycFormData (null → "N/A" conversions)      │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  2. Generate 6 PDFs (A1, A2, B2, B3, B4, B6)         │   │
│  │     → dict[str, bytes]                                │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  3. Upload all 6 PDFs to S3                           │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  4. Email all 6 PDFs to Vanguard (existing flow)      │   │
│  │     ✉️  VTB_KYC_INTERNAL_EMAIL                       │   │
│  └──────────────────┬───────────────────────────────────┘   │
│                     │                                        │
│  ┌──────────────────▼───────────────────────────────────┐   │
│  │  5. Submit to Lark Bitable (NEW)                      │   │
│  │     try:                                              │   │
│  │       submit_kyc_to_lark(data, pdfs, order_id)        │   │
│  │     except:                                           │   │
│  │       log error (never blocks email/S3)                │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  6. Send PENDING notification to client              │   │
│  │     📧 Email + 🔔 In-app notification                │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Automatic Retry Flow

```
submit_kyc_to_lark() called
         │
         ▼
    ┌─ Attempt 1 ──────────────────────────────────────┐
    │  _execute_lark_steps(data, pdfs, order_id)      │
    │    Check DB for existing lark_trust_record_id    │
    │    ├─ If exists → Skip Step 2, resume from 3    │
    │    └─ If null → Start from Step 2               │
    │    Execute Steps 2→3→4→5                         │
    └────────────┬────────────────────────────────────┘
                 │
            Success? ─── YES → Mark SUBMITTED ✅
                 │
                 NO
                 │
            Wait 30 seconds
                 │
    ┌─ Attempt 2 ──────────────────────────────────────┐
    │  Resume from last successful step                  │
    │  (lark_trust_record_id tells where to resume)     │
    └────────────┬────────────────────────────────────┘
                 │
            Success? ─── YES → Mark SUBMITTED ✅
                 │
                 NO
                 │
            Wait 60 seconds
                 │
    ┌─ Attempt 3 ──────────────────────────────────────┐
    │  Resume from last successful step                  │
    └────────────┬────────────────────────────────────┘
                 │
            Success? ─── YES → Mark SUBMITTED ✅
                 │
                 NO
                 │
            Wait 120 seconds
                 │
    ┌─ Attempt 4 ──────────────────────────────────────┐
    │  Resume from last successful step                  │
    └────────────┬────────────────────────────────────┘
                 │
            Success? ─── YES → Mark SUBMITTED ✅
                 │
                 NO
                 │
                 ▼
    Mark as FAILED ❌
    Store error message
    (Email/S3 still completed successfully)
```

---

## Manual Retry (Fallback)

If all 4 attempts fail, an admin can manually retry via:

```
POST /api/v1/lark/retry/{order_id}

Authorization: Bearer {jwt_token}
```

**Preconditions:**
- `lark_submission_status` must be `FAILED` or `PENDING`
- Lark credentials must be configured in `.env`

**What it does:**
1. Re-assembles KYC data from database
2. Re-generates PDFs
3. Calls `submit_kyc_to_lark()` with the same retry logic
4. Resumes from the last successful step if `lark_trust_record_id` exists

---

## Tracking Status in Database

The `trust_orders` table has 4 new columns:

| Column | Type | Values | Purpose |
|--------|------|--------|---------|
| `lark_trust_record_id` | String(100) | `recXXXXXX` or null | Lark record ID from Step 2. Enables resume on retry. |
| `lark_submission_status` | String(20) | `PENDING` → `IN_PROGRESS` → `SUBMITTED` or `FAILED` | Current Lark status |
| `lark_submitted_at` | DateTime | Timestamp or null | When submission succeeded |
| `lark_error_message` | Text | Error details or null | Last error if FAILED |

These are also returned in the `GET /trust-orders/{id}` and `GET /trust-orders/me` API responses.

---

## Lark Field Name Quirks

The following Lark field names have intentional typos that **must be preserved exactly**:

| Lark Field Name | Quirk | Notes |
|----------------|-------|-------|
| `Benedficiary Bank Address` | Typo "Benedficiary" | Must match Lark exactly |
| `Swift code` | Capital S | "Swift" not "swift" |
| `Client's Country of Birth` | Apostrophe in "Client's" | Curly vs straight apostrophe |

---

## Files Modified/Created

### New Files
| File | Purpose |
|------|---------|
| `backend/app/services/lark_service.py` | Core Lark integration service |
| `backend/app/schemas/lark.py` | Pydantic models for Lark API responses |
| `backend/app/api/v1/lark_integration.py` | Manual retry endpoint |
| `backend/migrations/versions/lark_001_*.py` | Alembic migration for Lark columns |

### Modified Files
| File | Change |
|------|--------|
| `backend/app/core/config.py` | Added LARK_APP_ID, LARK_APP_SECRET, LARK_BITABLE_APP_TOKEN, LARK_API_BASE_URL |
| `backend/.env` | Added Lark credential values |
| `backend/app/models/trust_order.py` | Added lark_trust_record_id, lark_submission_status, lark_submitted_at, lark_error_message |
| `backend/app/schemas/trust_order.py` | Added same 4 fields to TrustOrderResponse |
| `backend/app/api/v1/router.py` | Registered lark_integration router |
| `backend/app/services/kyc_automation_service.py` | Added submit_kyc_to_lark() call after email step |