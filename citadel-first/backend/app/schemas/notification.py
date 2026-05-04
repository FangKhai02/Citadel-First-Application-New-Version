from datetime import datetime

from pydantic import BaseModel


class NotificationResponse(BaseModel):
    model_config = {"from_attributes": True}

    id: int
    app_user_id: int
    title: str
    message: str
    type: str  # "info", "warning", "success"
    is_read: bool
    created_at: datetime | None


class NotificationListResponse(BaseModel):
    notifications: list[NotificationResponse]
    unread_count: int


class UnreadCountResponse(BaseModel):
    unread_count: int


class MarkReadResponse(BaseModel):
    message: str