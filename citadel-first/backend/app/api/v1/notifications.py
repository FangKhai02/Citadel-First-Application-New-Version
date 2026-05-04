import logging

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select, func, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.v1.signup import get_current_signup_user
from app.core.database import get_db
from app.models.notification import Notification
from app.models.user import AppUser
from app.schemas.notification import (
    NotificationListResponse,
    NotificationResponse,
    UnreadCountResponse,
    MarkReadResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/notifications", tags=["Notifications"])


async def create_notification(
    db: AsyncSession,
    user_id: int,
    title: str,
    message: str,
    notif_type: str = "info",
) -> Notification:
    """Create an in-app notification for a user. Call this from other endpoints."""
    record = Notification(
        app_user_id=user_id,
        title=title,
        message=message,
        type=notif_type,
        is_read=0,
    )
    db.add(record)
    await db.commit()
    await db.refresh(record)
    logger.info("NOTIFICATION_CREATED user_id=%d type=%s title=%s", user_id, notif_type, title)
    return record


@router.get(
    "",
    response_model=NotificationListResponse,
    summary="List notifications",
    description="Returns all notifications for the current user, newest first.",
)
async def list_notifications(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(Notification)
        .where(Notification.app_user_id == current_user.id)
        .order_by(Notification.created_at.desc())
    )
    notifications = result.scalars().all()

    unread_result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.app_user_id == current_user.id,
            Notification.is_read == 0,
        )
    )
    unread_count = unread_result.scalar() or 0

    return NotificationListResponse(
        notifications=[NotificationResponse.model_validate(n) for n in notifications],
        unread_count=unread_count,
    )


@router.patch(
    "/{notification_id}/read",
    response_model=NotificationResponse,
    summary="Mark a notification as read",
)
async def mark_notification_read(
    notification_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(Notification).where(
            Notification.id == notification_id,
            Notification.app_user_id == current_user.id,
        )
    )
    notification = result.scalar_one_or_none()
    if not notification:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found.")

    notification.is_read = 1
    await db.commit()
    await db.refresh(notification)
    return NotificationResponse.model_validate(notification)


@router.post(
    "/read-all",
    response_model=MarkReadResponse,
    summary="Mark all notifications as read",
)
async def mark_all_read(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    await db.execute(
        update(Notification)
        .where(Notification.app_user_id == current_user.id, Notification.is_read == 0)
        .values(is_read=1)
    )
    await db.commit()
    return MarkReadResponse(message="All notifications marked as read.")


@router.get(
    "/unread-count",
    response_model=UnreadCountResponse,
    summary="Get unread notification count",
)
async def get_unread_count(
    db: AsyncSession = Depends(get_db),
    current_user: AppUser = Depends(get_current_signup_user),
):
    result = await db.execute(
        select(func.count(Notification.id)).where(
            Notification.app_user_id == current_user.id,
            Notification.is_read == 0,
        )
    )
    return UnreadCountResponse(unread_count=result.scalar() or 0)