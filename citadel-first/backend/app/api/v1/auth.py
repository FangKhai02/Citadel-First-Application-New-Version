from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
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
    TokenResponse,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


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
    # JWT is stateless — client must discard tokens on their end.
    # For server-side revocation, store token JTI in a blocklist table.
    return MessageResponse(message="Logged out successfully")


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
