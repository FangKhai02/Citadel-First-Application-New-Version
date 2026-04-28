import logging
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    generate_verification_token,
    hash_password,
    verify_password,
)
from app.models.user import AdminUser, AppUser
from app.models.user_details import UserDetails
from app.models.signup import BankruptcyDeclaration, DisclaimerAcceptance
from app.models.pep_declaration import PepDeclaration
from app.models.crs_tax_residency import CrsTaxResidency
from app.models.face_verification import FaceVerification
from app.schemas.auth import (
    AdminLoginRequest,
    MessageResponse,
    MobileLoginRequest,
    RefreshRequest,
    RegisterRequest,
    ResendVerificationRequest,
    TokenResponse,
)
from app.services.email_service import send_verification_email

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/auth", tags=["Authentication"])

_TEMPLATES_DIR = Path("app/templates")


@router.post("/login", response_model=TokenResponse, summary="Mobile login (clients & agents)")
async def mobile_login(body: MobileLoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AppUser).where(
            AppUser.email_address == body.email,
            AppUser.is_deleted == 0,
        )
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email is not registered. Please proceed to sign up.",
        )

    if not verify_password(body.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if user.email_verified_at is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Email not verified. Please check your email for the verification link.",
        )

    token_data = {"sub": str(user.id), "user_type": user.user_type, "source": "mobile"}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_type=user.user_type,
        user_id=user.id,
    )


@router.post(
    "/register",
    response_model=TokenResponse,
    summary="Register a new mobile user",
    description="Creates an AppUser account and UserDetails stub, then returns JWT tokens.",
)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AppUser).where(AppUser.email_address == body.email)
    )
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists.",
        )

    user = AppUser(
        email_address=body.email,
        password=hash_password(body.password),
        user_type=body.user_type,
        email_verification_token=generate_verification_token(),
    )
    db.add(user)
    await db.flush()

    details = UserDetails(app_user_id=user.id)
    db.add(details)

    await db.commit()
    await db.refresh(user)

    token_data = {"sub": str(user.id), "user_type": user.user_type, "source": "mobile"}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_type=user.user_type,
        user_id=user.id,
    )


@router.post("/admin/login", response_model=TokenResponse, summary="Web admin login")
async def admin_login(body: AdminLoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(AdminUser).where(AdminUser.email == body.email))
    user = result.scalar_one_or_none()

    if not user or not verify_password(body.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    token_data = {"sub": str(user.id), "user_type": "ADMIN", "source": "admin"}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_type="ADMIN",
        user_id=user.id,
    )


@router.post("/refresh", response_model=TokenResponse, summary="Refresh access token")
async def refresh_token(body: RefreshRequest, db: AsyncSession = Depends(get_db)):
    payload = decode_token(body.refresh_token)
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    user_id = int(payload["sub"])
    user_type = payload["user_type"]
    source = payload.get("source", "mobile")

    if source == "admin":
        result = await db.execute(select(AdminUser).where(AdminUser.id == user_id))
        user = result.scalar_one_or_none()
    else:
        result = await db.execute(
            select(AppUser).where(AppUser.id == user_id, AppUser.is_deleted == 0)
        )
        user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")

    token_data = {"sub": str(user_id), "user_type": user_type, "source": source}
    return TokenResponse(
        access_token=create_access_token(token_data),
        refresh_token=create_refresh_token(token_data),
        user_type=user_type,
        user_id=user_id,
    )


@router.post("/logout", response_model=MessageResponse, summary="Logout (client-side token discard)")
async def logout():
    return MessageResponse(message="Logged out successfully")


@router.get(
    "/verify-email",
    summary="Verify email address",
    response_class=HTMLResponse,
)
async def verify_email(token: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(AppUser).where(AppUser.email_verification_token == token)
    )
    user = result.scalar_one_or_none()

    if not user:
        error_html = (_TEMPLATES_DIR / "verification_error.html").read_text()
        return HTMLResponse(content=error_html)

    user.email_verified_at = datetime.now(timezone.utc)
    user.email_verification_token = None
    await db.commit()

    success_html = (_TEMPLATES_DIR / "verification_success.html").read_text()
    return HTMLResponse(content=success_html)


@router.post(
    "/resend-verification",
    response_model=MessageResponse,
    summary="Resend verification email",
)
async def resend_verification(
    body: ResendVerificationRequest,
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(AppUser).where(
            AppUser.email_address == body.email,
            AppUser.is_deleted == 0,
        )
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Email is not registered.",
        )

    if user.email_verified_at is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email is already verified.",
        )

    user.email_verification_token = generate_verification_token()
    await db.commit()
    await db.refresh(user)

    try:
        await send_verification_email(user.email_address, user.email_verification_token)
    except Exception:
        logger.exception("Failed to resend verification email to %s", user.email_address)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to send verification email. Please try again later.",
        )

    return MessageResponse(message="Verification email sent. Please check your inbox.")


_bearer = HTTPBearer()


@router.delete(
    "/incomplete-signup",
    response_model=MessageResponse,
    summary="Delete incomplete signup data",
    description="Deletes all signup-related records and the user account when signup has not been completed. "
    "The client must discard stored tokens after calling this endpoint.",
)
async def delete_incomplete_signup(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: AsyncSession = Depends(get_db),
):
    payload = decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = int(payload["sub"])
    result = await db.execute(
        select(AppUser).where(AppUser.id == user_id, AppUser.is_deleted == 0)
    )
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found.",
        )

    if user.signup_completed_at is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Cannot delete a user whose signup is already completed.",
        )

    # Delete all signup-related rows (no FK constraints, order doesn't matter)
    await db.execute(
        BankruptcyDeclaration.__table__.delete().where(
            BankruptcyDeclaration.user_id == user_id
        )
    )
    await db.execute(
        DisclaimerAcceptance.__table__.delete().where(
            DisclaimerAcceptance.user_id == user_id
        )
    )
    await db.execute(
        CrsTaxResidency.__table__.delete().where(
            CrsTaxResidency.app_user_id == user_id
        )
    )
    await db.execute(
        PepDeclaration.__table__.delete().where(
            PepDeclaration.app_user_id == user_id
        )
    )
    await db.execute(
        FaceVerification.__table__.delete().where(
            FaceVerification.app_user_id == user_id
        )
    )
    await db.execute(
        UserDetails.__table__.delete().where(UserDetails.app_user_id == user_id)
    )

    # Delete the user account itself
    await db.execute(AppUser.__table__.delete().where(AppUser.id == user_id))

    await db.commit()

    return MessageResponse(
        message="Incomplete signup data deleted successfully. Please re-register."
    )