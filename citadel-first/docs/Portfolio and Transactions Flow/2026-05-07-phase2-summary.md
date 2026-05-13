# Phase 2 Summary: Transactions

## What Phase 2 Includes

Phase 2 builds on the portfolio foundation from Phase 1, adding a dedicated transaction history screen with filtering, and ensuring the transaction data pipeline works end-to-end from backend to client.

| Module | Purpose |
|--------|---------|
| **Transaction List Screen** | Full-page view of all placements and dividends with filter tabs |
| **Transaction Filter Tabs** | Toggle between All, Placements, and Dividends views |
| **Backend Type Filter** | Server-side `?type=` query parameter on `/transactions/me` |
| **Placement Amount Fix** | Investment amount now properly read from linked `trust_order` |

---

## Client-Side User Flow

### Step 1: View Recent Transactions (Dashboard)
1. Client opens app → Dashboard
2. Sees **Recent Transactions** section showing last 3 transactions
3. Each row shows: type icon, transaction type label, product name + date, amount with +/- prefix
4. Taps **View All** → navigates to full Transaction Screen

### Step 2: Full Transaction Screen
1. Arrives at `/client/transactions`
2. Sees **filter tabs**: All | Placements | Dividends
3. Default tab is **All** — shows combined list sorted by date descending
4. Taps **Placements** tab — shows only PLACEMENT type transactions
5. Taps **Dividends** tab — shows only DIVIDEND type transactions
6. Each transaction card shows:
   - Type-colored icon (green for dividends, blue for placements, amber for withdrawals/redemptions)
   - Transaction type label (e.g., "Placement", "Profit Sharing")
   - Product name + date (e.g., "CWD Trust • 15/06/2026")
   - Amount with prefix (+ for dividends, - for withdrawals)
   - Status badge (SUCCESS/PAID = green, PENDING = amber)

### Step 3: Empty States
- **No transactions at all**: "No transactions yet — Your transaction history will appear here."
- **No placements (filter active)**: "No placements — Placement transactions will appear here once approved."
- **No dividends (filter active)**: "No dividends — Dividend payments will appear here once paid."

### Step 4: Pull-to-Refresh
- On both dashboard and transaction screen, user can pull down to refresh data
- Calls `/transactions/me` and updates the list

### Navigation Map

```
Dashboard
├── Recent Transactions (last 3) → /client/transactions
│   ├── Filter: All (combined list)
│   ├── Filter: Placements (PLACEMENT only)
│   └── Filter: Dividends (DIVIDEND only)
└── Portfolio Section → /client/portfolio (Phase 1)
    └── Portfolio Card → /client/portfolio/:id
```

---

## What Vanguard/Admin Needs to Provide

No new admin actions beyond Phase 1. Transactions appear when:

| Trigger | What Happens |
|---------|-------------|
| Vanguard approves trust order | Portfolio auto-created with `payment_status=SUCCESS` → PLACEMENT transaction appears |
| Vanguard records dividend | `POST /api/v1/dividends` creates record with `payment_status=PENDING` → not yet visible |
| Vanguard marks dividend as PAID | `PATCH /api/v1/dividends/{id}/status` → DIVIDEND transaction appears |

---

## Backend API Endpoints Summary (Phase 2 Additions)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/transactions/me` | Combined placement + dividend transactions |
| GET | `/api/v1/transactions/me?type=PLACEMENT` | Filter to placements only |
| GET | `/api/v1/transactions/me?type=DIVIDEND` | Filter to dividends only |

### Transaction Response Fields

```json
{
  "transactions": [
    {
      "id": 1,
      "transaction_type": "PLACEMENT",
      "transaction_title": "Placement",
      "product_name": "CWD Trust",
      "amount": 100000.00,
      "trustee_fee": null,
      "transaction_date": "2026-01-15",
      "bank_name": "Maybank",
      "reference_number": null,
      "status": "SUCCESS",
      "portfolio_id": 1,
      "trust_order_id": 11
    },
    {
      "id": 2,
      "transaction_type": "DIVIDEND",
      "transaction_title": "Q1 Profit Sharing Earned",
      "product_name": "CWD Trust",
      "amount": 2500.00,
      "trustee_fee": 50.00,
      "transaction_date": "2026-03-31",
      "bank_name": "Maybank",
      "reference_number": "DIV1234567890",
      "status": "PAID",
      "portfolio_id": 1,
      "trust_order_id": 11,
      "dividend_quarter": 1,
      "period_starting_date": "2026-01-01",
      "period_ending_date": "2026-03-31"
    }
  ]
}
```

---

## Transaction Type Color Coding

| Type | Icon | Color | Amount Prefix |
|------|------|-------|--------------|
| Placement | arrow_upward | Blue (primary) | (none) |
| Dividend | trending_up | Green (success) | + |
| Withdrawal | arrow_downward | Amber (warning) | - |
| Redemption | arrow_downward | Amber (warning) | - |
| Rollover | autorenew | Grey (secondary) | (none) |
| Reallocation | swap_horiz | Grey (secondary) | (none) |

---

## Files Modified in Phase 2

| File | Change |
|------|--------|
| `backend/app/api/v1/transaction.py` | Added `?type=` query filter; fixed placement amount to read from linked `trust_order.trust_asset_amount` |
| `mobile/lib/features/client/transactions/transaction_screen.dart` | Full rewrite with filter tabs, improved cards, context-aware empty states, pull-to-refresh |
| `mobile/lib/services/portfolio_service.dart` | Added optional `type` parameter to `getMyTransactions()` |

---

## Key Data Flow

```
Vanguard approves order → Portfolio created (payment_status=SUCCESS)
        ↓
GET /transactions/me returns PLACEMENT entry (amount from trust_order)
        ↓
Client sees placement in:
  - Dashboard Recent Transactions (last 3)
  - Full Transaction Screen (All / Placements tab)
        ↓
Vanguard records dividend → Marks as PAID
        ↓
GET /transactions/me returns both PLACEMENT + DIVIDEND entries
        ↓
Client sees all transactions in:
  - Dashboard Recent Transactions
  - Full Transaction Screen (All / Dividends tab)
```