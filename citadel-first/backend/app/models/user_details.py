from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Date, DateTime, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserDetails(Base):
    """Extended user profile populated during signup — includes identity docs and OCR data."""

    __tablename__ = "user_details"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False, index=True)
    name: Mapped[str | None] = mapped_column(String(255))
    dob: Mapped[date | None] = mapped_column(Date)
    gender: Mapped[str | None] = mapped_column(String(20))
    nationality: Mapped[str | None] = mapped_column(String(100))
    identity_card_number: Mapped[str | None] = mapped_column(String(50))
    identity_doc_type: Mapped[str | None] = mapped_column(String(20))
    identity_card_front_image_key: Mapped[str | None] = mapped_column(String(500))
    identity_card_back_image_key: Mapped[str | None] = mapped_column(String(500))
    selfie_image_key: Mapped[str | None] = mapped_column(String(500))
    ocr_confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 4))
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )
