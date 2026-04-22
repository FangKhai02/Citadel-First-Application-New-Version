from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    verify_password,
)
from app.models.user import AdminUser, AppUser
from app.schemas.auth import (
    AdminLoginRequest,
    MessageResponse,
    MobileLoginRequest,
    RefreshRequest,
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

    if not user or not verify_password(body.password, user.password):
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
