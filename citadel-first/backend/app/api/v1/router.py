from fastapi import APIRouter

from app.api.v1 import (
    auth,
    bank_details,
    beneficiary,
    lark_integration,
    notifications,
    signup,
    transaction,
    trust_dividend,
    trust_order,
    trust_payment_receipt,
    trust_portfolio,
    users,
    vanguard,
    vtb_kyc,
)

router = APIRouter(prefix="/api/v1")
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(signup.router)
router.include_router(beneficiary.router)
router.include_router(notifications.router)
router.include_router(trust_order.router)
router.include_router(vtb_kyc.router)
router.include_router(trust_portfolio.router)
router.include_router(bank_details.router)
router.include_router(transaction.router)
router.include_router(trust_dividend.router)
router.include_router(trust_payment_receipt.router)
router.include_router(lark_integration.router)
router.include_router(vanguard.router)
