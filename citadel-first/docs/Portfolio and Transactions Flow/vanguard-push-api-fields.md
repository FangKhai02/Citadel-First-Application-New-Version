# Vanguard → Citadel: API Push Fields Reference

Complete reference of all data Vanguard pushes to Citadel via API, organized by flow stage.

---

## 1. Trust Order Review & Approval

**Endpoint:** `PATCH /api/v1/trust-orders/{order_id}/status`

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `case_status` | string | Yes | Order status. Values: `UNDER_REVIEW`, `APPROVED`, `REJECTED`, `DEFERRED` |
| `kyc_status` | string | No | KYC verification status. Values: `VERIFIED`, `PENDING` |
| `trust_reference_id` | string | On approve | Vanguard reference number (e.g. "VTB-2026-001") |
| `advisor_name` | string | No | Vanguard advisor full name |
| `advisor_nric` | string | No | Vanguard advisor NRIC |
| `advisor_code` | string | No | Vanguard advisor code |
| `commencement_date` | date | Recommended | Trust period start date (YYYY-MM-DD) |
| `trust_period_ending_date` | date | Recommended | Trust period end date (YYYY-MM-DD) |
| `irrevocable_termination_notice_date` | date | No | Date by which termination notice must be given |
| `auto_renewal_date` | date | No | Date the trust auto-renews |
| `deferment_remark` | text | No | Reason for rejection or deferral |
| `projected_yield_schedule_key` | string | No | S3 key for projected yield schedule PDF |
| `acknowledgement_receipt_key` | string | No | S3 key for acknowledgement receipt PDF |

### When Vanguard starts reviewing:

```json
PATCH /api/v1/trust-orders/14/status
{
  "case_status": "UNDER_REVIEW"
}
```

### When Vanguard approves:

```json
PATCH /api/v1/trust-orders/14/status
{
  "case_status": "APPROVED",
  "trust_reference_id": "VTB-2026-001",
  "kyc_status": "VERIFIED",
  "advisor_name": "John Advisor",
  "advisor_nric": "901234567890",
  "advisor_code": "ADV001",
  "commencement_date": "2026-06-01",
  "trust_period_ending_date": "2027-05-31"
}
```

**System auto-action on approval:** Citadel backend auto-creates a `trust_portfolio` record linked to this order with status `PENDING_PAYMENT`.

### When Vanguard rejects:

```json
PATCH /api/v1/trust-orders/14/status
{
  "case_status": "REJECTED",
  "deferment_remark": "Insufficient documentation provided."
}
```

### When Vanguard defers:

```json
PATCH /api/v1/trust-orders/14/status
{
  "case_status": "DEFERRED",
  "deferment_remark": "Awaiting additional beneficiary documentation."
}
```

---

## 2. Payment Verification

**Endpoint:** `PATCH /api/v1/trust-orders/{order_id}/payment-status`

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `payment_status` | string | Yes | Payment result. Values: `SUCCESS`, `FAILED` |

### When payment is verified:

```json
PATCH /api/v1/trust-orders/14/payment-status
{
  "payment_status": "SUCCESS"
}
```

**System auto-action:** Portfolio status changes from `PENDING_PAYMENT` to `ACTIVE`.

### When payment is rejected:

```json
PATCH /api/v1/trust-orders/14/payment-status
{
  "payment_status": "FAILED"
}
```

Portfolio stays at `PENDING_PAYMENT`. Client can re-upload a new receipt.

---

## 3. Dividend Recording

**Endpoint:** `POST /api/v1/dividends`

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `trust_portfolio_id` | integer | Yes | Target portfolio ID |
| `dividend_amount` | decimal(15,2) | Yes | Net amount after trustee fee |
| `trustee_fee_amount` | decimal(15,2) | No | Trustee fee deducted (default: 0) |
| `dividend_quarter` | integer | No | Quarter number: 1, 2, 3, or 4 |
| `period_starting_date` | date | No | Dividend period start (YYYY-MM-DD) |
| `period_ending_date` | date | No | Dividend period end (YYYY-MM-DD) |

### Example: Record Q1 dividend

```json
POST /api/v1/dividends
{
  "trust_portfolio_id": 1,
  "dividend_amount": 2500.00,
  "trustee_fee_amount": 50.00,
  "period_starting_date": "2026-01-01",
  "period_ending_date": "2026-03-31",
  "dividend_quarter": 1
}
```

**System auto-action:** Creates `trust_dividend_history` record with auto-generated `reference_number` and `payment_status = PENDING`.

---

## 4. Dividend Payment Confirmation

**Endpoint:** `PATCH /api/v1/dividends/{dividend_id}/status`

| Field | Type | Required | Description |
|-------|------|:--------:|-------------|
| `payment_status` | string | Yes | Must be `PAID` |
| `payment_date` | date | No | Date the dividend was paid out (YYYY-MM-DD) |
| `reference_number` | string | No | Payment reference number |

### Example: Mark dividend as paid

```json
PATCH /api/v1/dividends/1/status
{
  "payment_status": "PAID",
  "payment_date": "2026-04-01",
  "reference_number": "PAY-20260401-001"
}
```

---

## 5. Later Updates (Post-Approval)

Vanguard can push additional date updates after the initial approval using the same status endpoint:

```json
PATCH /api/v1/trust-orders/14/status
{
  "irrevocable_termination_notice_date": "2027-03-01",
  "auto_renewal_date": "2027-06-01"
}
```

Document uploads (S3 keys) can also be pushed later:

```json
PATCH /api/v1/trust-orders/14/status
{
  "projected_yield_schedule_key": "vanguard-docs/14/projected-yield-schedule.pdf",
  "acknowledgement_receipt_key": "vanguard-docs/14/acknowledgement-receipt.pdf"
}
```

---

## Summary: All Vanguard Push Endpoints

| Endpoint | Method | Purpose | Key Fields |
|----------|--------|---------|------------|
| `/api/v1/trust-orders/{id}/status` | PATCH | Review, approve, reject, or defer order | `case_status`, `trust_reference_id`, `commencement_date`, etc. |
| `/api/v1/trust-orders/{id}/payment-status` | PATCH | Verify or reject client payment | `payment_status` |
| `/api/v1/dividends` | POST | Record quarterly dividend | `trust_portfolio_id`, `dividend_amount`, `trustee_fee_amount` |
| `/api/v1/dividends/{id}/status` | PATCH | Mark dividend as paid | `payment_status`, `payment_date`, `reference_number` |