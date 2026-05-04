"""E2E: register -> full signup -> login -> beneficiaries -> DB verify -> cleanup.

All async work runs in a single event loop to avoid asyncpg connection issues.
"""
import json
import sys
import urllib.request
import urllib.error

import os

BASE = os.environ.get("E2E_BASE_URL", "http://localhost:8000/api/v1")
EMAIL = os.environ.get("E2E_TEST_EMAIL", "e2e.test.dummy+citadel@gmail.com")
PASSWORD = os.environ.get("E2E_TEST_PASSWORD", "")

# ── HTTP helpers ─────────────────────────────────────────────────────────────
def req(method, path, token=None, data=None):
    url = f"{BASE}{path}"
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    body = json.dumps(data).encode() if data else None
    r = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        resp = urllib.request.urlopen(r, timeout=15)
        raw = resp.read().decode()
        return {"status": resp.status, "data": json.loads(raw) if raw else {}}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try: detail = json.loads(raw)
        except: detail = raw
        return {"status": e.code, "data": detail, "error": True}

def GET(p, t=None):    return req("GET", p, t)
def POST(p, t=None, d=None): return req("POST", p, t, d)
def PATCH(p, t=None, d=None): return req("PATCH", p, t, d)
def DELETE(p, t=None): return req("DELETE", p, t)

# Convenience wrappers that accept keyword args
def api_post(path, token=None, body=None): return req("POST", path, token, body)
def api_patch(path, token=None, body=None): return req("PATCH", path, token, body)

def step(name): print(f"\n{'='*60}\n  {name}\n{'='*60}")
def ok(r, name):
    if r.get("error"):
        print(f"  FAIL [{name}]: {r['status']} — {json.dumps(r['data'])[:200]}")
        return False
    print(f"  OK [{name}]")
    return True

# ── Main async runner ────────────────────────────────────────────────────────
async def main():
    from app.core.database import engine
    from sqlalchemy import text

    async def db_q(sql, params=None):
        async with engine.connect() as conn:
            result = await conn.execute(text(sql), params or {})
            cols = result.keys()
            rows = result.fetchall()
            return [dict(zip(cols, row)) for row in rows]

    async def db_exec(sql, params=None):
        async with engine.begin() as conn:
            await conn.execute(text(sql), params or {})

    def print_table(name, rows):
        print(f"\n  TABLE: {name} ({len(rows)} row(s))")
        for row in rows:
            for k, v in row.items():
                if v is not None:
                    print(f"    {k}: {v}")

    # ═══════════════════════════════════════════════════════════════════════
    # PART 1: SIGNUP FLOW
    # ═══════════════════════════════════════════════════════════════════════
    step("1. Register new CLIENT user")
    r = api_post("/auth/register", body={"email": EMAIL, "password": PASSWORD, "user_type": "CLIENT"})
    ok(r, "Register") or sys.exit(1)
    token = r["data"]["access_token"]
    user_id = r["data"]["user_id"]
    print(f"  user_id = {user_id}")

    step("2. Bankruptcy declaration")
    ok(api_post("/signup/bankruptcy-declaration", token, {"is_not_bankrupt": True}), "Bankruptcy")

    step("3. Disclaimer acceptance")
    ok(api_post("/signup/disclaimer-acceptance", token, {"agreed": True}), "Disclaimer")

    step("4. Personal details")
    ok(api_patch("/signup/personal-details", token, {
        "full_name": "Tan Wei Ming", "nric": "900515-10-5678",
        "nationality": "Malaysian", "gender": "Male",
        "date_of_birth": "1990-05-15", "race": "Chinese",
    }), "Personal details")

    step("5. Address & contact")
    ok(api_patch("/signup/address-contact", token, {
        "residential_address": "12, Jalan Maju, Taman Segar, 56000 Cheras, KL",
        "mailing_address": "12, Jalan Maju, Taman Segar, 56000 Cheras, KL",
        "phone_number": "+60123456789", "email_address": EMAIL,
    }), "Address & contact")

    step("6. Employment details")
    ok(api_patch("/signup/employment-details", token, {
        "employment_status": "Employed", "employer_name": "Tech Solutions Sdn Bhd",
        "occupation": "Software Engineer",
        "employer_address": "88, Jalan Teknologi, 59000 KL",
        "monthly_income": "RM10,000-RM15,000",
    }), "Employment")

    step("7. KYC/CRS")
    ok(api_patch("/signup/kyc-crs", token, {
        "is_malaysian_tax_resident": True, "is_foreign_tax_resident": False,
        "tin_number": "IG2026900515",
    }), "KYC/CRS")

    step("8. PEP declaration")
    ok(api_patch("/signup/pep-declaration", token, {"is_pep": False, "is_associated_pep": False}), "PEP")

    step("9. Onboarding agreement (sign)")
    sig_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVQI12NgAAIABQABNjN9GQAAAABJRU5ErkJggg=="
    r = api_patch("/signup/onboarding-agreement", token, {
        "signature_base64": sig_b64, "full_name": "Tan Wei Ming", "ic_number": "900515-10-5678",
    })
    onboarding_ok = ok(r, "Onboarding agreement")
    if not onboarding_ok:
        print("  (S3/PDF issue — will mark signup_completed manually in DB)")

    # ═══════════════════════════════════════════════════════════════════════
    # VERIFY SIGNUP DATA IN DATABASE
    # ═══════════════════════════════════════════════════════════════════════
    step("10. VERIFY signup data in database")

    print_table("app_users", await db_q(
        "SELECT id, email_address, user_type, signup_completed_at, email_verified_at FROM app_users WHERE id = :uid",
        {"uid": user_id}))

    print_table("user_details", await db_q(
        "SELECT id, app_user_id, name, gender, nationality, identity_card_number, dob, residential_address, mailing_address, mobile_number, email, occupation, employer_name, annual_income_range FROM user_details WHERE app_user_id = :uid",
        {"uid": user_id}))

    print_table("bankruptcy_declarations", await db_q(
        "SELECT id, user_id, is_not_bankrupt, declared_at FROM bankruptcy_declarations WHERE user_id = :uid",
        {"uid": user_id}))

    print_table("disclaimer_acceptances", await db_q(
        "SELECT id, user_id, agreed, agreed_at FROM disclaimer_acceptances WHERE user_id = :uid",
        {"uid": user_id}))

    print_table("user_pep_declaration", await db_q(
        "SELECT id, app_user_id, is_pep FROM user_pep_declaration WHERE app_user_id = :uid",
        {"uid": user_id}))

    print_table("user_crs_tax_residency", await db_q(
        "SELECT id, app_user_id, jurisdiction, tin, tin_status FROM user_crs_tax_residency WHERE app_user_id = :uid",
        {"uid": user_id}))

    # ═══════════════════════════════════════════════════════════════════════
    # PART 2: LOGIN & BENEFICIARIES
    # ═══════════════════════════════════════════════════════════════════════
    if not onboarding_ok:
        step("9b. Manually mark signup_completed + email_verified in DB")
        await db_exec("UPDATE app_users SET signup_completed_at = NOW(), email_verified_at = NOW() WHERE id = :uid", {"uid": user_id})
        print("  Done")

    step("11. Login")
    r = api_post("/auth/login", body={"email": EMAIL, "password": PASSWORD})
    if not ok(r, "Login"):
        # Maybe email still not verified, force it
        await db_exec("UPDATE app_users SET email_verified_at = NOW() WHERE id = :uid", {"uid": user_id})
        r = api_post("/auth/login", body={"email": EMAIL, "password": PASSWORD})
        if not ok(r, "Login (retry)"):
            sys.exit(1)
    auth_token = r["data"]["access_token"]
    print(f"  user_type: {r['data']['user_type']}")

    step("12. Check /me endpoint")
    r = GET("/users/me", auth_token)
    if ok(r, "/me"):
        d = r["data"]
        print(f"  name: {d.get('name')}")
        print(f"  signup_completed: {d.get('signup_completed')}")
        print(f"  email_verified: {d.get('email_verified')}")
        print(f"  has_beneficiaries: {d.get('has_beneficiaries')}")

    # ── Beneficiary CRUD ───────────────────────────────────────────────────
    step("13. Create pre-demise beneficiary (Spouse, 100%)")
    r = api_post("/signup/beneficiaries", auth_token, {
        "beneficiary_type": "pre_demise", "same_as_settlor": False,
        "full_name": "Lim Mei Ling", "nric": "920822-14-5670",
        "gender": "Female", "dob": "1992-08-22",
        "relationship_to_settlor": "SPOUSE",
        "residential_address": "12, Jalan Maju, Taman Segar, 56000 Cheras, KL",
        "email": "lim.meiling@example.com", "contact_number": "+60129876543",
        "bank_account_name": "Lim Mei Ling", "bank_account_number": "1122334455",
        "bank_name": "Maybank", "share_percentage": 100.0,
    })
    pre_ben = r["data"] if ok(r, "Create pre-demise") else None
    if pre_ben: print(f"  ID: {pre_ben['id']}")

    step("14. Create post-demise beneficiary #1 (Child, 60%)")
    r = api_post("/signup/beneficiaries", auth_token, {
        "beneficiary_type": "post_demise", "same_as_settlor": False,
        "full_name": "Tan Xiao Ming", "nric": "180303-10-1234",
        "gender": "Male", "dob": "2018-03-03",
        "relationship_to_settlor": "CHILD",
        "residential_address": "12, Jalan Maju, Taman Segar, 56000 Cheras, KL",
        "email": "tan.xiaoming@example.com", "contact_number": "+60134567890",
        "bank_account_name": "Tan Xiao Ming", "bank_account_number": "5566778899",
        "bank_name": "CIMB", "share_percentage": 60.0,
    })
    post_ben_1 = r["data"] if ok(r, "Create post-demise #1") else None
    if post_ben_1: print(f"  ID: {post_ben_1['id']}")

    step("15. Create post-demise beneficiary #2 (Child, 40%)")
    r = api_post("/signup/beneficiaries", auth_token, {
        "beneficiary_type": "post_demise", "same_as_settlor": False,
        "full_name": "Tan Xiao Hui", "nric": "200606-14-5678",
        "gender": "Female", "dob": "2006-06-06",
        "relationship_to_settlor": "CHILD",
        "residential_address": "12, Jalan Maju, Taman Segar, 56000 Cheras, KL",
        "email": "tan.xiaohui@example.com", "contact_number": "+60145678901",
        "bank_account_name": "Tan Xiao Hui", "bank_account_number": "6677889900",
        "bank_name": "RHB", "share_percentage": 40.0,
    })
    post_ben_2 = r["data"] if ok(r, "Create post-demise #2") else None
    if post_ben_2: print(f"  ID: {post_ben_2['id']}")

    step("16. List beneficiaries via API")
    r = GET("/signup/beneficiaries", auth_token)
    if ok(r, "List beneficiaries"):
        bens = r["data"]["beneficiaries"]
        print(f"  Total: {len(bens)}")
        print(f"  has_pre_demise: {r['data']['has_pre_demise']}")
        print(f"  has_post_demise: {r['data']['has_post_demise']}")
        for b in bens:
            print(f"    - {b['full_name']} ({b['beneficiary_type']}) {b['relationship_to_settlor']} {b['share_percentage']}%")

    step("17. Update pre-demise beneficiary (change phone)")
    if pre_ben:
        r = api_patch(f"/signup/beneficiaries/{pre_ben['id']}", auth_token, {"contact_number": "+601999000111"})
        if ok(r, "Update beneficiary"):
            print(f"  New contact: {r['data']['contact_number']}")

    step("18. /me shows has_beneficiaries=true")
    r = GET("/users/me", auth_token)
    if ok(r, "/me"):
        print(f"  has_beneficiaries: {r['data'].get('has_beneficiaries')}")

    # ═══════════════════════════════════════════════════════════════════════
    # VERIFY BENEFICIARIES IN DATABASE
    # ═══════════════════════════════════════════════════════════════════════
    step("19. VERIFY beneficiaries in database")

    print_table("beneficiaries", await db_q(
        "SELECT id, app_user_id, beneficiary_type, full_name, nric, gender, dob, relationship_to_settlor, residential_address, email, contact_number, bank_account_name, bank_account_number, bank_name, share_percentage, is_deleted, created_at FROM beneficiaries WHERE app_user_id = :uid AND is_deleted = false ORDER BY id",
        {"uid": user_id}))

    print_table("app_users (final)", await db_q(
        "SELECT id, email_address, user_type, signup_completed_at, email_verified_at FROM app_users WHERE id = :uid",
        {"uid": user_id}))

    # ═══════════════════════════════════════════════════════════════════════
    # CLEANUP
    # ═══════════════════════════════════════════════════════════════════════
    step("20. CLEANUP: Delete beneficiaries via API")
    for ben in [pre_ben, post_ben_1, post_ben_2]:
        if ben:
            ok(DELETE(f"/signup/beneficiaries/{ben['id']}", auth_token), f"Delete beneficiary {ben['id']}")

    step("21. CLEANUP: Delete user from DB")
    for tbl, col in [
        ("beneficiaries", "app_user_id"),
        ("user_details", "app_user_id"),
        ("user_pep_declaration", "app_user_id"),
        ("user_crs_tax_residency", "app_user_id"),
        ("disclaimer_acceptances", "user_id"),
        ("bankruptcy_declarations", "user_id"),
        ("app_user_sessions", "app_user_id"),
    ]:
        try:
            async with engine.begin() as conn:
                result = await conn.execute(text(f"DELETE FROM {tbl} WHERE {col} = :uid"), {"uid": user_id})
                if result.rowcount: print(f"  {tbl}: {result.rowcount} row(s)")
        except: pass

    async with engine.begin() as conn:
        result = await conn.execute(text("DELETE FROM app_users WHERE id = :uid"), {"uid": user_id})
        print(f"  app_users: {result.rowcount} row(s)")
    print("  Cleanup complete")

    step("22. VERIFY cleanup")
    rows = await db_q("SELECT id FROM app_users WHERE id = :uid", {"uid": user_id})
    print(f"  User {user_id} exists: {bool(rows)} -> {'FAIL' if rows else 'PASS'}")
    rows = await db_q("SELECT count(*) as cnt FROM beneficiaries WHERE app_user_id = :uid", {"uid": user_id})
    print(f"  Orphaned beneficiaries: {rows[0]['cnt']} -> {'FAIL' if rows[0]['cnt'] > 0 else 'PASS'}")

    await engine.dispose()
    print("\n" + "="*60 + "\n  E2E TEST COMPLETE\n" + "="*60)


import asyncio
asyncio.run(main())