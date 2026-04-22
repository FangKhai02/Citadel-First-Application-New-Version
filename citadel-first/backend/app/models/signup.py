from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, Date, DateTime, LargeBinary, Numeric, String, func
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


class TrustFormB6(Base):
    """Stores B6 Asset Allocation Direction Form data and the generated PDF."""

    __tablename__ = "trust_form_b6"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)
    trust_deed_date: Mapped[date] = mapped_column(Date, nullable=False)
    trust_asset_amount: Mapped[Decimal] = mapped_column(Numeric(18, 2), nullable=False)
    advisor_name: Mapped[str] = mapped_column(String(255), nullable=False)
    advisor_nric: Mapped[str] = mapped_column(String(20), nullable=False)
    pdf_data: Mapped[bytes | None] = mapped_column(LargeBinary)
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
