# Client & Vanguard Full Flow

## End-to-End Process: Trust Product Purchase to Active Investment

---

### trust_orders Column Ownership

| Column | Who Sets It | When |
|--------|------------|------|
| `id` | System (auto) | Order creation |
| `app_user_id` | System (from auth token) | Order creation |
| `date_of_trust_deed` | **Client** | Step 5 — order submission |
| `trust_asset_amount` | **Client** | Step 5 — order submission |
| `advisor_name` | **Both** — Client can optionally pre-fill at submission; Vanguard pushes final value at approval | Step 5 / Step 10 |
| `advisor_nric` | **Both** — Client can optionally pre-fill at submission; Vanguard pushes final value at approval | Step 5 / Step 10 |
| `trust_reference_id` | **Vanguard** | Step 9/10 — review/approval |
| `case_status` | **Vanguard** | Step 9/10 — review/approval |
| `kyc_status` | **Vanguard** | Step 9/10 — review/approval |
| `deferment_remark` | **Vanguard** | Step 10 — rejection/deferral |
| `advisor_code` | **Vanguard** | Step 10 — approval |
| `commencement_date` | **Vanguard** | Step 10 — approval |
| `trust_period_ending_date` | **Vanguard** | Step 10 — approval |
| `irrevocable_termination_notice_date` | **Vanguard** | Step 10 — approval or later update |
| `auto_renewal_date` | **Vanguard** | Step 10 — approval or later update |
| `projected_yield_schedule_key` | **Vanguard** | Step 10+ — document upload |
| `acknowledgement_receipt_key` | **Vanguard** | Step 10+ — document upload |
| `is_deleted` | System (default false) | Soft delete |
| `created_at` | System (auto) | Order creation |
| `updated_at` | System (auto) | On any update |

---

### Step-by-Step Flow

| Step | Actor | Action | API Call / UI | Status After |
|------|-------|--------|---------------|--------------|
| 1 | **Client** | Opens app, logs in | `POST /auth/login` | Authenticated |
| 2 | **Client** | Sees dashboard with Trust Products section | `GET /portfolios/me`, `GET /transactions/me` | — |
| 3 | **Client** | Taps "Purchase" on Trust Product card | Navigate to `/client/trust-purchase` | — |
| 4 | **Client** | Fills Trust Info form: Date of Trust Deed, Trust Asset Amount (RM), optional Advisor Name & NRIC | Form input | — |
| 5 | **Client** | Reviews details on Step 2 and taps "Submit Application" | `POST /trust-orders` | `case_status = PENDING` |
| 6 | **System** | Auto-generates KYC forms and emails to client | Background task: `generate_and_email_kyc_forms` | Email sent |
| 7 | **Client** | Sees "Application Submitted!" success screen | Navigate to `/client/trust-purchase-success` | — |
| 8 | **Client** | Returns to dashboard. Portfolio section shows order as "Pending Review" | `GET /trust-orders/me` | `PENDING` |
| | | | | |
| 9 | **Vanguard** | Reviews the trust order and updates status | `PATCH /trust-orders/{id}/status` | `case_status = UNDER_REVIEW` |
| 10 | **Vanguard** | Approves the trust order with reference details | `PATCH /trust-orders/{id}/status` (see Table 2) | `case_status = APPROVED` |
| 11 | **System** | Auto-creates TrustPortfolio from the approved order | Auto-triggered in backend | `portfolio.status = PENDING_PAYMENT`, `portfolio.payment_status = PENDING` |
| 12 | **Client** | Receives notification that order is approved | Push notification / in-app | — |
| 13 | **Client** | Sees portfolio on dashboard with "Pending Payment" status | `GET /portfolios/me` | `PENDING_PAYMENT` |
| | | | | |
| 14 | **Client** | Adds bank account details | `POST /bank-details` | Bank account created |
| 15 | **Client** | Uploads payment receipt (PDF/image) | 3-step S3 presigned URL flow | Receipt `upload_status = UPLOADED` |
| 16 | **Vanguard** | Verifies the payment receipt | `PATCH /trust-orders/{id}/payment-status` | `payment_status = SUCCESS` |
| 17 | **System** | Portfolio status updates to ACTIVE | Auto-triggered in backend | `portfolio.status = ACTIVE` |
| 18 | **Client** | Sees portfolio as "Active" on dashboard | `GET /portfolios/me` | `ACTIVE` |
| | | | | |
| 19 | **Vanguard** | Records dividend for the quarter | `POST /dividends` | `payment_status = PENDING` |
| 20 | **Vanguard** | Marks dividend as paid | `PATCH /dividends/{id}/status` | `payment_status = PAID` |
| 21 | **Client** | Sees dividend entries in transaction list | `GET /transactions/me` | — |

---

### Table 1: What the Client Submits

| Step | API Endpoint | Request Body Fields |
|------|-------------|---------------------|
| 5 (Create Order) | `POST /trust-orders` | `date_of_trust_deed` (required, date), `trust_asset_amount` (required, decimal), `advisor_name` (optional, string), `advisor_nric` (optional, string) |
| 14 (Add Bank) | `POST /bank-details` | `bank_name` (required), `bank_account_holder_name` (required), `bank_account_number` (required), `bank_address` (optional), `postcode` (optional), `city` (optional), `state` (optional), `country` (optional), `swift_code` (optional) |
| 15 (Upload Receipt) | `POST /trust-orders/{id}/payment-receipt/upload-url` | `filename` (required), `content_type` (required) → returns `upload_url` + `key` |
| 15 (Confirm Receipt) | `POST /trust-orders/{id}/payment-receipt/confirm` | `key` (required), `file_name` (required) |

---

### Table 2: What Vanguard Pushes Back to Citadel

| Step | API Endpoint | Request Body Fields | When | Effect |
|------|-------------|--------------------|------|--------|
| 9 (Under Review) | `PATCH /trust-orders/{id}/status` | `case_status: "UNDER_REVIEW"` | When Vanguard starts reviewing | Client sees "Under Review" status |
| 10 (Approve) | `PATCH /trust-orders/{id}/status` | `case_status: "APPROVED"`, `trust_reference_id` (Vanguard reference number), `kyc_status` (e.g. "VERIFIED"), `advisor_name` (Vanguard advisor name), `advisor_nric` (Vanguard advisor NRIC), `advisor_code` (Vanguard advisor code), `commencement_date` (trust start date), `trust_period_ending_date` (trust end date), `irrevocable_termination_notice_date` (optional), `auto_renewal_date` (optional), `projected_yield_schedule_key` (optional, S3 key), `acknowledgement_receipt_key` (optional, S3 key) | When Vanguard approves the order | Auto-creates `trust_portfolio` record with `status = PENDING_PAYMENT` |
| 10 (Reject) | `PATCH /trust-orders/{id}/status` | `case_status: "REJECTED"`, `deferment_remark` (optional, reason for rejection) | When Vanguard rejects the order | Client sees "Rejected" status with remark |
| 16 (Verify Payment) | `PATCH /trust-orders/{id}/payment-status` | `payment_status: "SUCCESS"` | When Vanguard confirms payment received | Portfolio status changes to `ACTIVE` |
| 16 (Fail Payment) | `PATCH /trust-orders/{id}/payment-status` | `payment_status: "FAILED"` | When Vanguard rejects the payment | Portfolio stays `PENDING_PAYMENT` |
| 19 (Create Dividend) | `POST /dividends` | `trust_portfolio_id` (required), `dividend_amount` (required), `trustee_fee_amount` (optional, default 0), `dividend_quarter` (optional, 1-4), `period_starting_date` (optional), `period_ending_date` (optional), `payment_status` (required, "PENDING") | When Vanguard records a dividend payment | Dividend appears in client's transaction list |
| 20 (Mark Dividend Paid) | `PATCH /dividends/{id}/status` | `payment_status: "PAID"`, `payment_date` (optional), `reference_number` (optional) | When Vanguard pays out the dividend | Client sees "Paid" dividend with amount |

---

### Table 3: Vanguard Push Fields Detail

Full breakdown of every field Vanguard pushes into `trust_orders`, with descriptions:

| Field | Type | Required | Description | Pushed At |
|-------|------|----------|-------------|-----------|
| `case_status` | string | Yes | Order status: `UNDER_REVIEW`, `APPROVED`, `REJECTED` | Step 9/10 |
| `trust_reference_id` | string(50) | On approve | Vanguard's reference number for the trust (e.g., "VTB-2026-001") | Step 10 |
| `kyc_status` | string(30) | Optional | KYC verification status (e.g., "VERIFIED", "PENDING") | Step 9/10 |
| `deferment_remark` | text | Optional | Reason for rejection or deferral | Step 10 (rejection) |
| `advisor_name` | string(255) | Optional | Vanguard advisor full name. **Note:** Client can also optionally pre-fill this at submission, but Vanguard's value takes precedence. | Step 5 / Step 10 |
| `advisor_nric` | string(50) | Optional | Vanguard advisor NRIC number. **Note:** Client can also optionally pre-fill this at submission, but Vanguard's value takes precedence. | Step 5 / Step 10 |
| `advisor_code` | string(50) | Optional | Vanguard advisor code | Step 10 |
| `commencement_date` | date | Recommended | Trust period start date | Step 10 |
| `trust_period_ending_date` | date | Recommended | Trust period end date | Step 10 |
| `irrevocable_termination_notice_date` | date | Optional | Date by which termination notice must be given | Step 10 or later |
| `auto_renewal_date` | date | Optional | Date the trust auto-renews | Step 10 or later |
| `projected_yield_schedule_key` | string(500) | Optional | S3 key for the projected yield schedule PDF | Step 10 or later |
| `acknowledgement_receipt_key` | string(500) | Optional | S3 key for the acknowledgement receipt PDF | Step 10 or later |

---

### Table 4: Status Transitions

| Entity | From | To | Trigger |
|--------|------|----|---------|
| **TrustOrder.case_status** | — | PENDING | Client submits order (Step 5) |
| | PENDING | UNDER_REVIEW | Vanguard starts review (Step 9) |
| | UNDER_REVIEW | APPROVED | Vanguard approves (Step 10) |
| | UNDER_REVIEW | REJECTED | Vanguard rejects (Step 10) |
| **TrustPortfolio.status** | — | PENDING_PAYMENT | Auto-created on order approval (Step 11) |
| | PENDING_PAYMENT | ACTIVE | Vanguard verifies payment (Step 16) |
| | ACTIVE | MATURED | Trust period ends (future) |
| | ACTIVE | WITHDRAWN | Client withdraws (future) |
| **TrustPortfolio.payment_status** | — | PENDING | Auto-created with portfolio (Step 11) |
| | PENDING | SUCCESS | Vanguard verifies payment (Step 16) |
| | PENDING | FAILED | Vanguard rejects payment (Step 16) |
| **TrustDividendHistory.payment_status** | — | PENDING | Vanguard creates dividend (Step 19) |
| | PENDING | PAID | Vanguard marks as paid (Step 20) |

---

### Table 5: What the Client Sees at Each Stage

| Portfolio Status | Dashboard Display | Available Actions |
|-----------------|-------------------|-------------------|
| Order `PENDING` | "Pending Review" badge on order card | None (waiting for Vanguard) |
| Order `UNDER_REVIEW` | "Under Review" badge on order card | None (waiting for Vanguard) |
| Order `REJECTED` | "Rejected" badge on order card | "Resubmit" button (future feature) |
| Portfolio `PENDING_PAYMENT` | "Pending Payment" badge on portfolio card | "Upload Payment Receipt", "Manage Bank Details" |
| Portfolio `ACTIVE` | "Active" badge, div rate shown on portfolio card | "View Receipts", "View Agreement" (if exists) |
| Portfolio `MATURED` | "Matured" badge | "Rollover" / "Redemption" (future feature) |

---

### Notes

1. **KYC Automation**: On order creation (Step 5), the system auto-generates KYC PDF forms and emails them to the client as a background task.
2. **Portfolio Auto-Creation**: When Vanguard approves an order (Step 10), the backend automatically creates a `trust_portfolio` record linked to that order. No manual action needed.
3. **S3 Upload Flow**: Receipt upload uses presigned URLs — the client gets a URL from our backend, uploads directly to S3, then confirms the upload. The backend never handles the file bytes.
4. **Transaction List**: The `/transactions/me` endpoint combines PLACEMENT entries (from portfolios with `payment_status=SUCCESS`) and DIVIDEND entries (from `trust_dividend_history` with `payment_status=PAID`), sorted by date descending.
5. **Dividend Rate**: The `dividend_rate` on `trust_portfolio` can be set by Vanguard when approving the order or updated later via `PATCH /portfolios/{id}`.
6. **Vanguard Document Keys**: `projected_yield_schedule_key` and `acknowledgement_receipt_key` are S3 keys for PDF documents that Vanguard uploads. These are stored on `trust_orders` and can be downloaded via presigned URLs.
7. **Irrevocable Termination & Auto-Renewal**: These dates (`irrevocable_termination_notice_date`, `auto_renewal_date`) may not be available at approval time. Vanguard can push them in a subsequent `PATCH /trust-orders/{id}/status` call when the dates are confirmed.