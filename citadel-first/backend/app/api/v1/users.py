from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import AdminUser, AppUser
from app.schemas.user import MeResponse

router = APIRouter(prefix="/users", tags=["Users"])
bearer = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
    db: AsyncSession = Depends(get_db),
) -> tuple[AppUser | AdminUser, str]:
    payload = decode_token(credentials.credentials)
    if not payload or payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
        )

    user_id = int(payload["sub"])
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

    return user, payload.get("user_type", "CLIENT")


@router.get("/me", response_model=MeResponse, summary="Get current user profile")
async def get_me(current: tuple = Depends(get_current_user)):
    user, user_type = current
    email = getattr(user, "email_address", None) or getattr(user, "email", "")
    name = getattr(user, "name", None)
    signup_completed = (
        user.signup_completed_at is not None
        if isinstance(user, AppUser)
        else True  # AdminUser — signup doesn't apply
    )
    return MeResponse(
        id=user.id,
        email=email,
        user_type=user_type,
        name=name,
        signup_completed=signup_completed,
        created_at=user.created_at,
    )
