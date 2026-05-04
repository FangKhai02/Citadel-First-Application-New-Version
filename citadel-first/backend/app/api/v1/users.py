from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from sqlalchemy import func as sa_func

from app.core.database import get_db
from app.core.security import decode_token
from app.models.user import AdminUser, AppUser
from app.models.user_details import UserDetails
from app.models.beneficiary import Beneficiary
from app.models.notification import Notification
from app.schemas.user import MeResponse, SettlorProfileResponse

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
async def get_me(
    current: tuple = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    user, user_type = current
    email = getattr(user, "email_address", None) or getattr(user, "email", "")
    signup_completed = (
        user.signup_completed_at is not None
        if isinstance(user, AppUser)
        else True
    )
    email_verified = (
        user.email_verified_at is not None
        if isinstance(user, AppUser)
        else True
    )

    name = None
    if isinstance(user, AppUser):
        ud_result = await db.execute(
            select(UserDetails).where(UserDetails.app_user_id == user.id)
        )
        user_details = ud_result.scalar_one_or_none()
        name = user_details.name if user_details else None
    else:
        name = getattr(user, "name", None)

    has_beneficiaries = False
    unread_notification_count = 0
    if isinstance(user, AppUser):
        ben_result = await db.execute(
            select(Beneficiary).where(
                Beneficiary.app_user_id == user.id,
                Beneficiary.is_deleted == False,
            ).limit(1)
        )
        has_beneficiaries = ben_result.scalar_one_or_none() is not None

        notif_result = await db.execute(
            select(sa_func.count(Notification.id)).where(
                Notification.app_user_id == user.id,
                Notification.is_read == 0,
            )
        )
        unread_notification_count = notif_result.scalar() or 0

    return MeResponse(
        id=user.id,
        email=email,
        user_type=user_type,
        name=name,
        signup_completed=signup_completed,
        email_verified=email_verified,
        has_beneficiaries=has_beneficiaries,
        unread_notification_count=unread_notification_count,
        created_at=user.created_at,
    )


@router.get("/me/details", response_model=SettlorProfileResponse, summary="Get current user's settlor profile")
async def get_settlor_profile(
    current: tuple = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Returns the full settlor profile for 'Same as Settlor' beneficiary auto-population."""
    user, _ = current
    if not isinstance(user, AppUser):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only app users can access settlor profile")

    result = await db.execute(
        select(UserDetails).where(UserDetails.app_user_id == user.id)
    )
    user_details = result.scalar_one_or_none()
    if not user_details:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User details not found")

    return SettlorProfileResponse.model_validate(user_details)
