from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class BankruptcyDeclaration(Base):
    """Records each user's bankruptcy declaration at signup."""

    __tablename__ = "bankruptcy_declarations"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)
    is_not_bankrupt: Mapped[bool] = mapped_column(Boolean, nullable=False)
    declared_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class DisclaimerAcceptance(Base):
    """Records each user's disclaimer agreement at signup."""

    __tablename__ = "disclaimer_acceptances"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)
    agreed: Mapped[bool] = mapped_column(Boolean, nullable=False)
    agreed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ip_address: Mapped[str | None] = mapped_column(String(45))
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
