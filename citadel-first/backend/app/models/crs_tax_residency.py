from datetime import datetime

from sqlalchemy import BigInteger, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class CrsTaxResidency(Base):
    """CRS tax residency rows — many per AppUser (1–5 jurisdictions)."""

    __tablename__ = "user_crs_tax_residency"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(
        BigInteger, nullable=False, index=True
    )

    jurisdiction: Mapped[str] = mapped_column(String(100), nullable=False)
    tin: Mapped[str | None] = mapped_column(String(100))
    no_tin_reason: Mapped[str | None] = mapped_column(String(1))
    reason_b_explanation: Mapped[str | None] = mapped_column(String(500))

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )