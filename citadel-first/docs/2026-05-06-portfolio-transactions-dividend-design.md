# Portfolio, Transactions & Dividend Feature Design

**Date:** 2026-05-06  
**Status:** Draft  
**Scope:** Extend the trust product purchase flow with portfolio view, transaction history, dividend display, and payment receipt upload.

---

## 1. Context

The Citadel First app currently has a trust order submission flow (client submits order → Vanguard reviews → case_status changes). After approval, the client has no way to see their portfolio, transaction history, or dividend payments. The old vendor code (Java/Spring backend + Flutter mobile) had a full-featured system with multi-level review, dividend calculation, agreement signing, and portfolio management.

Our app differs from the old vendor in key ways:
- **No product catalog** — clients submit a single trust product (CWD Trust), not select from a list
- **No multi-level review** — Vanguard is the single reviewer (not Finance → Checker → Approver)
- **No internal dividend calculation** — Vanguard manages the trust and provides dividend data
- **Simpler beneficiary model** — beneficiaries are linked to the user, not per-order distribution (for now)

---

## 2. Business Flow

```
Client submits trust_order (existing)
   → case_status = PENDING
   
Vanguard reviews & approves
   → PATCH /trust-orders/{id}/status { case_status: "APPROVED" }
   → Backend auto-creates trust_portfolio record
   → Vanguard provides: trust_reference_id, commencement_date, trust_period_ending_date, advisor_code, dividend_rate
   
Client selects bank & uploads payment receipt
   → POST /bank-details (create bank account)
   → POST /trust-orders/{id}/payment-receipt (upload receipt)
   
Admin/Vanguard verifies payment
   → PATCH /trust-orders/{id}/payment-status { payment_status: "SUCCESS" }
   → Portfolio status = ACTIVE
   
Dividends recorded by admin/Vanguard
   → POST /dividends { portfolio_id, amount, period }
   → Client sees "Q1 Profit Sharing" in transactions
   
At maturity
   → status = MATURED
   → Rollover / Redemption (future feature)
```

---

## 3. Database Schema

### 3.1 New Table: `trust_portfolio`

Created automatically when a trust_order is approved. This is **complementary** to `trust_orders` — it does NOT duplicate fields already in trust_orders (trust_reference_id, case_status, commencement_date, etc. are all on the order). The portfolio tracks the *active investment lifecycle* — payment, dividends, maturity, and agreement status — which are separate from the order submission.

The relationship: `trust_orders` = the application/submission + Vanguard review data. `trust_portfolio` = the active investment after approval. The portfolio links to its source order via `trust_order_id`, and the order's Vanguard fields (trust_reference_id, commencement_date, etc.) are read from the order, not duplicated here.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK, auto | |
| app_user_id | bigint | FK → app_users.id, NOT NULL | |
| trust_order_id | bigint | FK → trust_orders.id, nullable | Source order (Vanguard fields live on the order) |
| product_name | varchar(255) | default 'CWD Trust' | |
| product_code | varchar(50) | default 'CWD' | |
| dividend_rate | numeric(5,2) | nullable | Annual rate % (set by Vanguard or admin) |
| investment_tenure_months | integer | nullable | |
| maturity_date | date | nullable | Derived from commencement_date + tenure |
| payout_frequency | varchar(20) | default 'QUARTERLY' | MONTHLY/QUARTERLY/ANNUALLY |
| is_prorated | boolean | default false | |
| status | varchar(30) | default 'PENDING_PAYMENT' | PENDING_PAYMENT/ACTIVE/MATURED/WITHDRAWN |
| payment_method | varchar(30) | nullable | MANUAL_TRANSFER/ONLINE_BANKING |
| payment_status | varchar(20) | default 'PENDING' | PENDING/SUCCESS/FAILED |
| bank_details_id | bigint | FK → bank_details.id, nullable | |
| agreement_file_name | varchar(255) | nullable | |
| agreement_key | varchar(500) | nullable | S3 key |
| agreement_date | date | nullable | |
| client_agreement_status | varchar(20) | nullable | PENDING/SUCCESS/REJECTED |
| is_deleted | boolean | default false | |
| created_at | timestamptz | server_default now() | |
| updated_at | timestamptz | on update now() | |

**Note:** The following fields already exist in `trust_orders` and are NOT duplicated in `trust_portfolio`:
- `trust_reference_id`, `case_status`, `kyc_status`, `deferment_remark`, `advisor_code`, `advisor_name`, `advisor_nric`
- `commencement_date`, `trust_period_ending_date`, `irrevocable_termination_notice_date`, `auto_renewal_date`
- `projected_yield_schedule_key`, `acknowledgement_receipt_key`
- `trust_asset_amount` (the portfolio references this via `trust_order_id`)
- `date_of_trust_deed`

### 3.2 New Table: `trust_payment_receipt`

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK, auto | |
| trust_portfolio_id | bigint | FK → trust_portfolio.id | |
| file_name | varchar(255) | | |
| file_key | varchar(500) | | S3 key |
| upload_status | varchar(20) | default 'DRAFT' | DRAFT/UPLOADED |
| created_at | timestamptz | server_default now() | |
| updated_at | timestamptz | on update now() | |

### 3.3 New Table: `trust_dividend_history`

Dividend records per portfolio per period. Input by admin or pushed by Vanguard API.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK, auto | |
| trust_portfolio_id | bigint | FK → trust_portfolio.id | |
| reference_number | varchar(50) | unique | e.g., DIV1234567890 |
| dividend_amount | numeric(15,2) | | Net amount after trustee fee |
| trustee_fee_amount | numeric(15,2) | default 0 | |
| period_starting_date | date | | |
| period_ending_date | date | | |
| dividend_quarter | integer | default 0 | Q1=1, Q2=2, Q3=3, Q4=4 |
| payment_status | varchar(20) | default 'PENDING' | PENDING/PAID |
| payment_date | date | nullable | |
| created_at | timestamptz | server_default now() | |
| updated_at | timestamptz | on update now() | |

### 3.4 New Table: `bank_details`

Client bank accounts for payments.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | bigint | PK, auto | |
| app_user_id | bigint | FK → app_users.id, NOT NULL | |
| bank_name | varchar(255) | | |
| bank_account_holder_name | varchar(255) | | |
| bank_account_number | varchar(50) | | |
| is_deleted | boolean | default false | |
| created_at | timestamptz | server_default now() | |
| updated_at | timestamptz | on update now() | |

### 3.5 Modifications to `trust_orders`

**No schema changes needed.** The existing `trust_orders` table already has all the fields Vanguard pushes back (trust_reference_id, case_status, kyc_status, commencement_date, etc.). The `payment_method`, `payment_status`, `bank_details_id`, `client_agreement_status`, and `agreement_key` fields will live on `trust_portfolio` instead, since they belong to the active investment lifecycle, not the order submission.

---

## 4. API Endpoints

### 4.1 Portfolio APIs

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/portfolios/me` | Client | List all portfolios for current user |
| GET | `/portfolios/{id}` | Client | Full portfolio detail (bank, beneficiaries, payment, documents) |
| POST | `/portfolios` | Admin/Vanguard | Create portfolio (auto-called when order approved) |

### 4.2 Payment APIs

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/trust-orders/{id}/payment-receipt` | Client | Upload payment receipt (S3 presigned URL) |
| GET | `/trust-orders/{id}/payment-receipts` | Client | List uploaded receipts |
| PATCH | `/trust-orders/{id}/payment-status` | Admin | Verify payment (PENDING → SUCCESS) |

### 4.3 Transaction APIs

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/transactions/me` | Client | Combined list of placements + dividends, sorted by date desc |

Logic: PLACEMENT entries come from `trust_portfolio` records with `payment_status='SUCCESS'` (joined with trust_orders for product name and order details). DIVIDEND entries come from `trust_dividend_history` records with `payment_status='PAID'`. Both are combined and sorted by transaction date descending.

Response format:
```json
{
  "transactions": [
    {
      "id": 1,
      "history_id": 1,
      "transaction_type": "PLACEMENT",
      "transaction_title": "Placement",
      "product_name": "CWD Trust",
      "amount": 100000.00,
      "transaction_date": "2026-01-15",
      "bank_name": "Maybank",
      "status": "SUCCESS"
    },
    {
      "id": 2,
      "history_id": 1,
      "transaction_type": "DIVIDEND",
      "transaction_title": "Q1 Profit Sharing Earned",
      "product_name": "CWD Trust",
      "amount": 2500.00,
      "trustee_fee": 50.00,
      "transaction_date": "2026-03-31",
      "bank_name": "Maybank",
      "status": "PAID"
    }
  ]
}
```

### 4.4 Dividend APIs (Admin-first, Vanguard API later)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/dividends` | Admin | Create dividend record for a portfolio |
| GET | `/dividends/portfolio/{portfolio_id}` | Client/Admin | List dividends for a portfolio |
| PATCH | `/dividends/{id}/status` | Admin | Mark dividend as PAID |

### 4.5 Bank Details APIs

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/bank-details` | Client | Create bank account |
| GET | `/bank-details/me` | Client | List current user's bank accounts |
| DELETE | `/bank-details/{id}` | Client | Soft delete bank account |

### 4.6 Existing Endpoint Modifications

`PATCH /trust-orders/{id}/status` — when `case_status` changes to `APPROVED`:
- Auto-create a `trust_portfolio` record from the trust_order data
- The portfolio references the order via `trust_order_id` — Vanguard fields (trust_reference_id, commencement_date, etc.) stay on the order and are read from there
- Portfolio stores: app_user_id (from order), product_name ('CWD Trust'), dividend_rate (from Vanguard), investment_tenure_months, payout_frequency, status='PENDING_PAYMENT'

---

## 5. Flutter UI Screens

### Build Order: Phase 1 (Portfolio) → Phase 2 (Transactions) → Phase 3 (Payment)

### Phase 1: Portfolio

**1.1 Portfolio List Screen** (`portfolio_screen.dart`)
- List of all trust_orders/portfolios grouped by status
- Active/Approved cards at top, Pending below, Rejected at bottom
- Each card: product name, amount (RM formatted), status badge, date
- Tappable → Portfolio Detail
- Pull-to-refresh
- Empty state: "No trust products yet. Get started!"
- Reuse existing `TrustOrder` model + new `TrustPortfolio` model

**1.2 Portfolio Detail Screen** (`portfolio_detail_screen.dart`)
- Header: Product name, amount, status badge, agreement number, date
- Sections:
  - **Status & Remark** — current status with contextual remark
  - **Bank Details** — bank name, account holder (edit if PENDING_PAYMENT)
  - **Beneficiaries** — list with distribution % (link to existing beneficiary data)
  - **Payment** — payment method, receipts (upload action if PENDING_PAYMENT)
  - **Actions** — contextual buttons based on status
    - DRAFT → "Delete Draft"
    - REJECTED → "Resubmit for review"
    - PENDING_PAYMENT → "Upload Payment Receipt"
    - APPROVED/ACTIVE → "View Agreement" + "Early Redeem" (future)

**1.3 Update Dashboard**
- Wire `PortfolioSection` to real data from `/trust-orders/me`
- Replace `List<Map<String, dynamic>>` with `List<TrustOrder>`

### Phase 2: Transactions

**2.1 Transaction List Screen** (`transaction_screen.dart`)
- Combined list: PLACEMENT (from trust_orders) + DIVIDEND (from trust_dividend_history)
- Sorted by date descending
- Each row: icon (by type), title, product name, amount, date
- Filter tabs: All | Placement | Dividend
- Empty state: "No transactions yet"

**2.2 Update Dashboard**
- Wire `TransactionSection` to real data from `/transactions/me`
- Replace `List<Map<String, dynamic>>` with `List<TransactionVo>`

### Phase 3: Payment Receipt Upload

**3.1 Bank Details Screen** — CRUD for client bank accounts
**3.2 Payment Receipt Upload** — S3 presigned URL flow, preview, submit
**3.3 Payment Proof Page** — show uploaded receipts in portfolio detail

---

## 6. Vanguard Integration Pattern

Vanguard pushes data to our backend via API. This follows the existing pattern of `PATCH /trust-orders/{id}/status`.

### Flow: Vanguard Approval → Portfolio Creation

```
Vanguard calls: PATCH /trust-orders/{id}/status
  Body: {
    "case_status": "APPROVED",
    "trust_reference_id": "VTB-2026-001",
    "commencement_date": "2026-06-01",
    "trust_period_ending_date": "2027-05-31",
    "advisor_code": "ADV001"
  }

Backend logic (in update_trust_order_status):
  1. Update trust_order fields
  2. IF case_status changed to "APPROVED":
     - Auto-create trust_portfolio record:
       - app_user_id from trust_order
       - trust_order_id from trust_order.id
       - trust_reference_id, commencement_date, etc. from Vanguard data
       - purchased_amount = trust_order.trust_asset_amount
       - product_name = "CWD Trust"
       - status = "PENDING_PAYMENT"
  3. Notify client (existing notification system)
```

### Flow: Dividend Recording

```
Admin/Vanguard calls: POST /dividends
  Body: {
    "trust_portfolio_id": 1,
    "dividend_amount": 2500.00,
    "trustee_fee_amount": 50.00,
    "period_starting_date": "2026-01-01",
    "period_ending_date": "2026-03-31",
    "dividend_quarter": 1
  }

Backend logic:
  1. Create trust_dividend_history record
  2. Generate reference_number (DIV + timestamp + random)
  3. payment_status = PENDING (admin marks as PAID later)
  4. Notify client
```

---

## 7. Implementation Phases

### Phase 1: Portfolio (1-2 weeks)
1. Backend: Create `trust_portfolio`, `bank_details` tables + Alembic migration
2. Backend: Add portfolio auto-creation logic to `update_trust_order_status`
3. Backend: Add `/portfolios/me`, `/portfolios/{id}` endpoints
4. Flutter: Create `TrustPortfolio` model
5. Flutter: Wire `PortfolioSection` to real API data
6. Flutter: Build `PortfolioDetailScreen`
7. Flutter: Add portfolio routes to `app_router.dart`

### Phase 2: Transactions (1 week)
1. Backend: Create `trust_dividend_history` table + migration
2. Backend: Add `/dividends` CRUD endpoints
3. Backend: Add `/transactions/me` endpoint (combined query)
4. Flutter: Create `TransactionVo` model
5. Flutter: Wire `TransactionSection` to real API data
6. Flutter: Build `TransactionScreen` (full list view)
7. Flutter: Add transaction routes

### Phase 3: Payment Receipt (1 week)
1. Backend: Create `trust_payment_receipt` table + migration
2. Backend: Add bank details CRUD endpoints
3. Backend: Add payment receipt upload + verification endpoints
4. Flutter: Build bank details screen
5. Flutter: Build payment receipt upload flow
6. Flutter: Update portfolio detail to show payment section
7. Flutter: Add bank details + payment routes