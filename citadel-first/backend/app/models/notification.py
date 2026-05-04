from datetime import datetime

from sqlalchemy import BigInteger, DateTime, Integer, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Notification(Base):
    """In-app notifications for users — beneficiary reminders, status updates, etc."""

    __tablename__ = "notifications"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)

    title: Mapped[str] = mapped_column(String(255), nullable=False)
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    type: Mapped[str] = mapped_column(String(50), nullable=False, default="info")  # "info", "warning", "success"

    is_read: Mapped[int] = mapped_column(Integer, default=0, nullable=False)  # 0 = unread, 1 = read

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )