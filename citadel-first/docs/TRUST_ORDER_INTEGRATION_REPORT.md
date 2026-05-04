# Citadel First — Vanguard Trust Order Integration Report

## 1. Overview

This document describes the integration architecture between **Citadel First** (our platform) and **Vanguard Trustee Berhad** (the trustee provider) for the Citadel Wealth Diversification Trust product. The integration enables:

- **Outbound**: Automatically pushing client-submitted trust order details to Vanguard when a new order is created
- **Inbound**: Receiving status updates from Vanguard and reflecting them in the mobile application in real time

---

## 2. Data Flow Architecture

```
┌──────────────┐        ┌──────────────┐        ┌──────────────┐
│  Mobile App  │        │  Citadel API │        │  Vanguard API│
│  (Client)    │        │  (Backend)   │        │  (Vanguard)  │
└──────┬───────┘        └──────┬───────┘        └──────┬───────┘
       │                       │                       │
       │  1. POST /trust-orders │                       │
       │  (submit application)  │                       │
       ├──────────────────────>│                       │
       │                       │                       │
       │                       │  2. Save to DB        │
       │                       │  (trust_orders table) │
       │                       │                       │
       │                       │  3. AUTO PUSH         │
       │                       │  POST to Vanguard API │
       │                       ├──────────────────────>│
       │                       │                       │
       │                       │  4. Vanguard assigns   │
       │                       │     reference ID and   │
       │                       │     processes case     │
       │                       │                       │
       │                       │  5. Vanguard pushes    │
       │                       │     status updates     │
       │                       │<──────────────────────┤
       │                       │                       │
       │                       │  6. Update DB record  │
       │                       │                       │
       │  7. GET /trust-orders/me                      │
       │  (fetch latest status) │                       │
       │<──────────────────────┤                       │
       │                       │                       │
       │  8. Display updated   │                       │
       │     status badge      │                       │
       │     on dashboard      │                       │
```

---

## 3. Data Fields by Direction

### 3.1 Outbound: Citadel → Vanguard (Client-Submitted Fields)

These fields are submitted by the client on the mobile app and pushed to Vanguard automatically upon order creation.

| Field                  | Type         | Required | Description                              |
|------------------------|-------------|----------|------------------------------------------|
| `order_id`             | Integer      | Yes      | Our `trust_orders.id` (correlation key)  |
| `app_user_id`          | Integer      | Yes      | Client user ID                           |
| `date_of_trust_deed`   | Date         | Yes      | Date the trust deed was signed           |
| `trust_asset_amount`   | Decimal(15,2)| Yes      | Amount placed into trust (RM)            |
| `advisor_name`         | String       | No       | Name of the financial advisor            |
| `advisor_nric`         | String       | No       | NRIC of the financial advisor             |

### 3.2 Inbound: Vanguard → Citadel (Vanguard-Side Fields)

These fields are updated by Vanguard and pushed back to our API when the case status changes or new information becomes available.

| Field                                | Type    | Description                                          |
|--------------------------------------|---------|------------------------------------------------------|
| `trust_reference_id`                 | String  | Vanguard's internal reference number                 |
| `case_status`                        | String  | PENDING → UNDER_REVIEW → APPROVED / REJECTED → ACTIVE |
| `kyc_status`                         | String  | KYC verification status                              |
| `deferment_remark`                   | Text    | Notes if the case is deferred                        |
| `advisor_code`                      | String  | Vanguard's advisor code assignment                   |
| `commencement_date`                  | Date    | When the trust commences                             |
| `trust_period_ending_date`           | Date    | End date of the trust period                         |
| `irrevocable_termination_notice_date`| Date    | Date of irrevocable termination notice               |
| `auto_renewal_date`                  | Date    | Date the trust auto-renews                           |
| `projected_yield_schedule_key`       | String  | S3 key for yield schedule document (provided by Vanguard) |
| `acknowledgement_receipt_key`        | String  | S3 key for acknowledgement receipt (provided by Vanguard) |

---

## 4. Correlation Key: Identifying Which Status Belongs to Which User

When multiple clients submit trust orders, Vanguard must be able to match each status update to the correct order in our database.

### Solution: Use Our `trust_orders.id` as the Correlation Key

Every trust order in our database has a unique auto-incrementing `id`. When we push an order to Vanguard, we include this `id` as `order_id`. Vanguard must include the same `order_id` in every status update they send back.

**Example — 3 clients submit orders:**

| Our DB (`trust_orders.id`) | Client     | Trust Asset Amount |
|----------------------------|------------|--------------------|
| 1                          | User A     | RM 500,000         |
| 2                          | User B     | RM 1,000,000       |
| 3                          | User C     | RM 250,000         |

**Outbound push to Vanguard:**
```json
// Order 1
{ "order_id": 1, "app_user_id": 52, "date_of_trust_deed": "2026-04-29", "trust_asset_amount": "500000.00" }

// Order 2
{ "order_id": 2, "app_user_id": 53, "date_of_trust_deed": "2026-05-01", "trust_asset_amount": "1000000.00" }

// Order 3
{ "order_id": 3, "app_user_id": 54, "date_of_trust_deed": "2026-05-02", "trust_asset_amount": "250000.00" }
```

**Inbound status updates from Vanguard:**
```json
// Update for Order 1
{ "order_id": 1, "case_status": "UNDER_REVIEW", "trust_reference_id": "VTR-2026-00123" }

// Update for Order 2
{ "order_id": 2, "case_status": "APPROVED", "advisor_code": "ADV-456", "commencement_date": "2026-05-15" }

// Update for Order 3
{ "order_id": 3, "case_status": "REJECTED", "deferment_remark": "Insufficient documentation" }
```

Each update includes the `order_id`, so we know exactly which record to update. No ambiguity, no mismatching.

### Correlation Key Summary

| Key                   | Direction            | Purpose                                    |
|-----------------------|----------------------|--------------------------------------------|
| `order_id` (our `id`) | Citadel → Vanguard   | Identifies which order this is              |
| `order_id` (our `id`) | Vanguard → Citadel   | Tells us which order to update              |
| `trust_reference_id`  | Vanguard → Citadel   | Vanguard's own reference (stored for their use) |

---

## 5. Auto-Push Mechanism

### 5.1 How It Works

When a client submits a trust order through the mobile app:

1. Mobile app sends `POST /trust-orders` to our backend
2. Our backend creates the record in `trust_orders` table
3. Our backend **automatically calls Vanguard's API** to push the order details
4. If Vanguard's API is unavailable, the order is still saved — the push is retried later

### 5.2 Implementation Pattern

```
Client submits order
        │
        ▼
POST /trust-orders
        │
        ├── Save to database (always succeeds)
        │
        └── Async push to Vanguard API
              │
              ├── Success → Order marked as "pushed to Vanguard"
              │
              └── Failure → Logged for retry, order still saved locally
```

### 5.3 Retry Strategy

If Vanguard's API is temporarily down, the push should be retried. Options:

| Strategy        | Description                                              |
|-----------------|----------------------------------------------------------|
| **Immediate**   | Attempt push right after order creation                  |
| **Retry queue** | Failed pushes go into a queue, retried every 5 minutes  |
| **Manual fallback** | Admin dashboard shows "pending push" orders for manual retry |

We recommend starting with **immediate + retry queue** for resilience.

---

## 6. Mobile App Status Display

### 6.1 Status Badge Mapping

When the mobile app fetches `GET /trust-orders/me`, the `case_status` field determines the badge shown on the trust product card:

| `case_status`   | Badge Label        | Badge Color | Description                                     |
|-----------------|--------------------|-------------|-------------------------------------------------|
| `PENDING`       | Pending Review     | Amber       | Order submitted, awaiting Vanguard review        |
| `UNDER_REVIEW`  | Under Review       | Cyan/Blue   | Vanguard is reviewing the application            |
| `APPROVED`      | Approved           | Green       | Application approved, proceed to placement        |
| `REJECTED`      | Rejected           | Red         | Application rejected, contact support            |
| `ACTIVE`        | Active             | Green       | Trust is active and running                      |

### 6.2 When the Status Updates

The mobile app fetches the latest order status at these points:

- When the dashboard loads (`initState`)
- When the user returns from the purchase screen
- When the user pulls to refresh the dashboard

**Future enhancement**: Real-time updates via push notifications or WebSocket polling, so the user sees status changes without refreshing.

---

## 7. API Endpoints Summary

### 7.1 Existing Endpoints (Already Built)

| Method | Endpoint                                     | Description                           |
|--------|----------------------------------------------|---------------------------------------|
| POST   | `/api/v1/trust-orders`                       | Client submits a trust order           |
| GET    | `/api/v1/trust-orders/me`                    | List current user's trust orders      |
| GET    | `/api/v1/trust-orders/{order_id}`            | Get a single trust order by ID        |
| POST   | `/api/v1/trust-orders/presigned-url`          | Generate S3 upload URL for attachments|
| GET    | `/api/v1/trust-orders/products/cwd-deck-url`  | Get presigned URL for CWD Trust Deck  |

### 7.2 New Endpoints (To Be Built)

| Method | Endpoint                              | Auth           | Description                                     |
|--------|---------------------------------------|----------------|-------------------------------------------------|
| PATCH  | `/api/v1/trust-orders/{order_id}`     | Admin/Vanguard | Update Vanguard-side fields (case status, etc.)  |

**Vanguard update endpoint** — protected by admin API key or Vanguard-specific authentication. Vanguard calls this to push status updates for a specific order identified by `order_id`.

### 7.3 Outbound Vanguard Integration (To Be Built)

| Direction | Endpoint (Vanguard's)     | Description                                    |
|-----------|---------------------------|------------------------------------------------|
| POST      | `{vanguard_base_url}/...` | Push new trust order details to Vanguard        |

**Prerequisite**: Vanguard must provide their API specification (endpoint URL, authentication method, request/response format).

---

## 8. Database Schema Reference

Current `trust_orders` table:

| Column                              | Type          | Direction    | Description                                  |
|-------------------------------------|---------------|--------------|----------------------------------------------|
| `id`                                | BigInteger PK | Both         | Correlation key between Citadel and Vanguard  |
| `app_user_id`                        | BigInteger FK | Outbound     | Client user reference                        |
| `date_of_trust_deed`                | Date          | Outbound     | Date trust deed was signed                    |
| `trust_asset_amount`                | Numeric(15,2) | Outbound     | Trust placement amount (RM)                  |
| `advisor_name`                      | String(255)   | Outbound     | Advisor name                                  |
| `advisor_nric`                      | String(50)    | Outbound     | Advisor NRIC                                  |
| `trust_reference_id`                | String(50)    | Inbound      | Vanguard's reference ID                        |
| `case_status`                       | String(30)    | Inbound      | PENDING / UNDER_REVIEW / APPROVED / REJECTED / ACTIVE |
| `kyc_status`                        | String(30)    | Inbound      | KYC verification status                       |
| `deferment_remark`                  | Text          | Inbound      | Notes on case deferral                         |
| `advisor_code`                      | String(50)    | Inbound      | Vanguard advisor code                          |
| `commencement_date`                 | Date          | Inbound      | Trust commencement date                        |
| `trust_period_ending_date`          | Date          | Inbound      | Trust period end date                           |
| `irrevocable_termination_notice_date`| Date         | Inbound      | Irrevocable termination notice date            |
| `auto_renewal_date`                 | Date          | Inbound      | Auto renewal date                              |
| `projected_yield_schedule_key`      | String(500)   | Inbound      | S3 key for yield schedule (provided by Vanguard) |
| `acknowledgement_receipt_key`       | String(500)   | Inbound      | S3 key for acknowledgement receipt            |
| `is_deleted`                        | Boolean       | Internal     | Soft delete flag                                |
| `created_at`                        | DateTime      | Internal     | Record creation timestamp                       |
| `updated_at`                        | DateTime      | Internal     | Last update timestamp                           |

---

## 9. Next Steps

1. **Get Vanguard's API specification** — endpoint URL, authentication method, request/response format for both inbound and outbound integration
2. **Build the Vanguard update endpoint** — `PATCH /trust-orders/{order_id}` with admin/Vanguard auth
3. **Build the outbound push service** — auto-call Vanguard's API after order creation, with retry queue
4. **Add push notifications** — notify the client when their case status changes
5. **Build admin dashboard** — internal tool for Citadel staff to view and manage trust orders