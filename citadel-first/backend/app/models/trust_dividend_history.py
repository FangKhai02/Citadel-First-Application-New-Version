from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Date, DateTime, ForeignKey, Numeric, String, UniqueConstraint, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrustDividendHistory(Base):
    """Dividend payout records per portfolio — input by admin or pushed by Vanguard."""

    __tablename__ = "trust_dividend_history"
    __table_args__ = (UniqueConstraint("reference_number", name="uq_dividend_reference_number"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    trust_portfolio_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("trust_portfolios.id"), nullable=False, index=True)
    reference_number: Mapped[str] = mapped_column(String(50), nullable=False)
    dividend_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), nullable=False)
    trustee_fee_amount: Mapped[Decimal] = mapped_column(Numeric(15, 2), server_default="0", nullable=False)
    period_starting_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    period_ending_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    dividend_quarter: Mapped[int] = mapped_column(server_default="0", nullable=False)
    payment_status: Mapped[str] = mapped_column(String(20), server_default="PENDING", nullable=False)
    payment_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), onupdate=func.now())