from fastapi import APIRouter

from app.api.v1 import auth, beneficiary, notifications, signup, trust_order, users

router = APIRouter(prefix="/api/v1")
router.include_router(auth.router)
router.include_router(users.router)
router.include_router(signup.router)
router.include_router(beneficiary.router)
router.include_router(notifications.router)
router.include_router(trust_order.router)
