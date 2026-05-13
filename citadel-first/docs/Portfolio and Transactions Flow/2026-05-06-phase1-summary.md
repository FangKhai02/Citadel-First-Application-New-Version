# Phase 1 Summary: Portfolio, Transactions & Dividends

## What Phase 1 Includes

Phase 1 implements the core financial features that let clients view their trust investments after purchasing a trust product:

| Module | Purpose |
|--------|---------|
| **Trust Portfolio** | View all trust investments with status, amounts, and product details |
| **Bank Details** | Manage bank accounts linked to trust placements |
| **Transactions** | See a combined history of placements and dividend payments |
| **Dividends** | View dividend history per portfolio with profit-sharing details |
| **Payment Receipts** | Upload and view payment receipt documents |

---

## Client-Side User Flow

### Step 1: Purchase a Trust Product (Already Implemented)
1. Client logs in → Dashboard
2. Scrolls to **Trust Products** section
3. Taps a product card (e.g., "CITADEL FIRST GROWTH TRUST")
4. Fills in purchase form → Submits order

### Step 2: View Portfolios
1. After Vanguard **approves** the trust order, a portfolio is auto-created
2. Client opens app → Dashboard
3. Sees **Portfolio** section with active investments
4. Taps a portfolio card to see detail view

### Step 3: Portfolio Detail (Overview Tab)
- **Product name**, trust period, status
- **Amount** (from the linked trust order)
- **Bank account** used for this placement
- **Commencement date**, maturity date (if set by Vanguard)

### Step 4: Portfolio Detail (Dividends Tab)
- Lists all dividend payments for this portfolio
- Each row shows: quarter label, amount, trustee fee, net amount, payment status, reference number

### Step 5: View All Transactions
1. From Dashboard → Taps **Transactions** section header
2. Combined list shows:
   - **PLACEMENT** entries (when order was approved and paid)
   - **DIVIDEND** entries (when Vanguard records profit-sharing payments)
3. Sorted by date, most recent first

### Step 6: Manage Bank Accounts
1. From portfolio detail → Can view linked bank account
2. From bank details API → Can create/update/delete bank accounts
3. Bank account is linked to a portfolio at creation time

### Navigation Map

```
Dashboard
├── Portfolio Section → /client/portfolio (list)
│   └── Portfolio Card → /client/portfolio/:id (detail)
│       ├── Overview Tab (portfolio info + bank + order)
│       └── Dividends Tab (dividend history)
└── Transaction Section → /client/transactions (combined list)
```

---

## What Vanguard/Admin Needs to Provide

These are details that must be entered by the Vanguard admin side (not by the client):

### 1. Trust Order Approval
| Field | Required | Notes |
|-------|----------|-------|
| `case_status` | Yes | Must be set to `APPROVED` to trigger portfolio auto-creation |

### 2. Trust Order Fields (for enriched portfolio detail)
| Field | Required | Notes |
|-------|----------|-------|
| `amount` | Recommended | Investment amount shown in portfolio detail |
| `commencement_date` | Optional | Start date of the trust period |
| `maturity_date` | Optional | End date of the trust period |
| `reference_id` | Optional | Vanguard reference number |
| `product_name` | Already set | From product catalog |

### 3. Dividend Creation (Admin API: `POST /api/v1/dividends`)
| Field | Required | Notes |
|-------|----------|-------|
| `trust_portfolio_id` | Yes | Which portfolio this dividend belongs to |
| `dividend_amount` | Yes | Total profit-sharing amount before fees |
| `trustee_fee_amount` | Optional | Fee deducted from dividend |
| `dividend_quarter` | Optional | e.g., Q1, Q2, Q3, Q4 |
| `period_starting_date` | Optional | Start of earning period |
| `period_ending_date` | Optional | End of earning period |
| `payment_status` | Yes | `PENDING`, `PAID`, or `FAILED` |
| `payment_date` | Recommended | When dividend was paid |
| `reference_number` | Optional | Vanguard reference for the payment |

### 4. Dividend Status Update (Admin API: `PATCH /api/v1/dividends/{id}/status`)
- Change status from `PENDING` → `PAID` or `FAILED`
- Set `payment_date` and `reference_number` when marking as PAID

### 5. Payment Receipts (Admin or Client Upload)
| Field | Required | Notes |
|-------|----------|-------|
| `trust_portfolio_id` | Yes | Which portfolio the receipt belongs to |
| `file` | Yes | PDF/image uploaded via presigned S3 URL |
| `receipt_type` | Optional | Categorization of receipt |

---

## Backend API Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/portfolios/me` | List client's portfolios |
| GET | `/api/v1/portfolios/{id}` | Portfolio detail with order + bank info |
| POST | `/api/v1/portfolios` | Create portfolio (or auto-created on approval) |
| PATCH | `/api/v1/portfolios/{id}` | Update portfolio fields |
| DELETE | `/api/v1/portfolios/{id}` | Soft delete portfolio |
| GET | `/api/v1/bank-details/me` | List client's bank accounts |
| POST | `/api/v1/bank-details` | Add a bank account |
| PATCH | `/api/v1/bank-details/{id}` | Update bank account |
| DELETE | `/api/v1/bank-details/{id}` | Soft delete bank account |
| GET | `/api/v1/transactions/me` | Combined placement + dividend transactions |
| POST | `/api/v1/dividends` | Create dividend record (admin) |
| GET | `/api/v1/dividends/portfolio/{id}` | Dividends for a portfolio |
| PATCH | `/api/v1/dividends/{id}/status` | Update dividend payment status |
| POST | `/api/v1/payment-receipts/upload-url` | Get presigned S3 URL |
| POST | `/api/v1/payment-receipts/confirm` | Confirm receipt upload |
| GET | `/api/v1/payment-receipts/{portfolio_id}` | List receipts for portfolio |

---

## Key Data Flow

```
Client purchases trust product
        ↓
Trust Order created (status: PENDING)
        ↓
Vanguard admin approves order (status: APPROVED)
        ↓
Portfolio auto-created from order
        ↓
Client can now:
  - View portfolio details
  - See placement in transactions
  - View linked bank account
        ↓
Vanguard admin creates dividend records
        ↓
Client can now:
  - See dividend entries in transactions
  - View dividend history per portfolio
  - Download payment receipts
```