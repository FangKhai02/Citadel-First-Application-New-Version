# Phase 3 Summary: Payment Receipt Upload

## What Phase 3 Includes

Phase 3 completes the payment lifecycle by giving clients the ability to manage bank accounts, upload payment receipts, and view receipt status — bridging the gap between trust order approval and portfolio activation.

| Module | Purpose |
|--------|---------|
| **Bank Details Screen** | CRUD for client bank accounts (add, view, edit, delete) |
| **Payment Receipt Upload** | Pick file (PDF/image), upload via S3 presigned URL, confirm |
| **Payment Receipt List** | View uploaded receipts with status (Draft/Uploaded) |
| **Portfolio Detail Actions** | Interactive buttons to upload receipts, manage banks, view receipts |
| **Transaction Amount Fix** | Placement transactions now show investment amount from linked trust order |

---

## Client-Side User Flow

### Step 1: Manage Bank Accounts
1. From portfolio detail (PENDING_PAYMENT status) → taps **Manage Bank Details**
2. Arrives at `/client/bank-details`
3. Sees list of bank accounts (or empty state with "Add Bank Account" CTA)
4. Taps **Add Bank Account** → bottom sheet form with fields:
   - Bank Name* (required)
   - Account Holder Name* (required)
   - Account Number* (required)
   - Bank Address, Postcode, City, State, Country, SWIFT Code (optional)
5. Submits → account created → appears in list
6. Can edit via 3-dot menu → Edit (pre-fills form)
7. Can delete via 3-dot menu → Delete (confirmation dialog)

### Step 2: Upload Payment Receipt
1. From portfolio detail (PENDING_PAYMENT status) → taps **Upload Payment Receipt**
2. Arrives at `/client/payment-receipts/{orderId}`
3. Sees "Upload Receipt" button at top + empty receipt list
4. Taps **Upload Receipt** → system file picker opens
5. Selects PDF, JPG, JPEG, or PNG file
6. Upload flow:
   - App requests presigned S3 URL from `POST /trust-orders/{orderId}/payment-receipt/upload-url`
   - App uploads file bytes directly to S3 via presigned URL
   - App confirms upload via `POST /trust-orders/{orderId}/payment-receipt/confirm`
7. Receipt appears in list with status badge (Draft → Uploaded)
8. Can pull-to-refresh to see status updates

### Step 3: View Receipts (Active Portfolio)
1. From portfolio detail (ACTIVE status) → taps **View Receipts**
2. Arrives at receipt list screen for that order
3. Sees all uploaded receipts with file name, upload date, and status

### Navigation Map

```
Portfolio Detail (PENDING_PAYMENT)
├── Upload Payment Receipt → /client/payment-receipts/{orderId}
└── Manage Bank Details → /client/bank-details

Portfolio Detail (ACTIVE)
├── View Receipts → /client/payment-receipts/{orderId}
└── View Agreement (if agreement_key exists)
```

---

## Backend API Endpoints (Already Existed from Phase 1)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/v1/bank-details/me` | List client's bank accounts |
| POST | `/api/v1/bank-details` | Create a bank account |
| PATCH | `/api/v1/bank-details/{id}` | Update bank account |
| DELETE | `/api/v1/bank-details/{id}` | Soft delete bank account |
| POST | `/api/v1/trust-orders/{id}/payment-receipt/upload-url` | Get presigned S3 URL |
| POST | `/api/v1/trust-orders/{id}/payment-receipt/confirm` | Confirm receipt upload |
| GET | `/api/v1/trust-orders/{id}/payment-receipts` | List receipts for an order |

---

## Bank Details Form Fields

| Field | Required | Notes |
|-------|----------|-------|
| Bank Name | Yes | e.g., "Maybank" |
| Account Holder Name | Yes | Full name as on bank account |
| Account Number | Yes | Masked display: `****1234` |
| Bank Address | No | Street address |
| Postcode | No | |
| City | No | |
| State | No | |
| Country | No | |
| SWIFT Code | No | For international transfers |

---

## Payment Receipt Upload Flow

```
Client taps "Upload Receipt"
        ↓
FilePicker opens (PDF, JPG, JPEG, PNG only)
        ↓
Client selects file
        ↓
App calls: POST /trust-orders/{id}/payment-receipt/upload-url
   → Returns: { upload_url, key }
        ↓
App uploads file bytes to S3 presigned URL (PUT request)
        ↓
App calls: GET /trust-orders/{id}/payment-receipts
   → Finds DRAFT receipt matching the key
        ↓
App calls: POST /trust-orders/{id}/payment-receipt/confirm
   → Receipt status changes: DRAFT → UPLOADED
        ↓
Receipt appears in list with "Uploaded" badge
```

---

## Portfolio Detail Action Buttons (by Status)

| Portfolio Status | Action Buttons |
|-----------------|----------------|
| PENDING_PAYMENT | Upload Payment Receipt (primary), Manage Bank Details (outlined) |
| ACTIVE | View Receipts (outlined), View Agreement (outlined, if agreement exists) |
| MATURED | Rollover / Redemption (disabled, future feature) |
| REJECTED | (No action buttons) |

---

## Transaction Amount Fix

Before Phase 3: PLACEMENT transactions returned `amount: null` because the amount lived on the linked `trust_order` table, not on `trust_portfolio`.

After: `/transactions/me` now joins with `trust_orders` to read `trust_asset_amount` for PLACEMENT entries, so clients see "RM 100,000.00" instead of "N/A".

---

## Flutter Files Created in Phase 3

| File | Purpose |
|------|---------|
| `mobile/lib/features/client/bank_details/bank_details_screen.dart` | Bank account CRUD screen (list, add, edit, delete) |
| `mobile/lib/features/client/payment/payment_receipt_screen.dart` | Payment receipt upload + list screen |

## Flutter Files Modified in Phase 3

| File | Change |
|------|--------|
| `mobile/lib/features/client/portfolio/portfolio_detail_screen.dart` | Made action buttons interactive (upload receipt, manage banks, view receipts); fixed `trustOrderId` access path |
| `mobile/lib/core/router/app_router.dart` | Added `/client/bank-details` and `/client/payment-receipts/:orderId` routes |
| `mobile/lib/pubspec.yaml` | Added `file_picker: ^8.3.0` dependency |

## Backend Files Modified in Phase 3

| File | Change |
|------|--------|
| `backend/app/api/v1/transaction.py` | Added `?type=` filter parameter; fixed PLACEMENT amount to read from `trust_order.trust_asset_amount` |

---

## Key Data Flow

```
Vanguard approves trust order → Portfolio created (status: PENDING_PAYMENT)
        ↓
Client opens portfolio detail → Sees "Upload Payment Receipt" + "Manage Bank Details"
        ↓
Client adds bank account → POST /bank-details
Client uploads payment receipt → Presigned URL flow
        ↓
Vanguard admin verifies payment → PATCH /trust-orders/{id}/payment-status { payment_status: "SUCCESS" }
        ↓
Portfolio status → ACTIVE
Client can now: View receipts, see placement in transactions, view dividends
```