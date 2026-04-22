from datetime import datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, DateTime, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class FaceVerification(Base):
    """Stores face verification results for eKYC biometric checks."""

    __tablename__ = "faceid_image_validate"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)
    selfie_image_key: Mapped[str] = mapped_column(String(500), nullable=False)
    doc_image_key: Mapped[str] = mapped_column(String(500), nullable=False)
    is_match: Mapped[bool] = mapped_column(Boolean, nullable=False)
    confidence: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False)
    distance: Mapped[Decimal | None] = mapped_column(Numeric(10, 4), nullable=True)
    selfie_face_detected: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    doc_face_detected: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    threshold_used: Mapped[Decimal] = mapped_column(Numeric(5, 4), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )