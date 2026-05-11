from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, Date, DateTime, ForeignKey, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrustPortfolio(Base):
    """Active trust investment — created when a trust_order is approved."""

    __tablename__ = "trust_portfolios"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, ForeignKey("app_users.id"), nullable=False, index=True)
    trust_order_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("trust_orders.id"), nullable=True)

    product_name: Mapped[str] = mapped_column(String(255), server_default="CWD Trust")
    product_code: Mapped[str] = mapped_column(String(50), server_default="CWD")
    dividend_rate: Mapped[Decimal | None] = mapped_column(Numeric(5, 2), nullable=True)
    investment_tenure_months: Mapped[int | None] = mapped_column(nullable=True)
    maturity_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    payout_frequency: Mapped[str] = mapped_column(String(20), server_default="QUARTERLY")
    is_prorated: Mapped[bool] = mapped_column(Boolean, server_default="false", nullable=False)

    status: Mapped[str] = mapped_column(String(30), server_default="PENDING_PAYMENT", nullable=False)
    payment_method: Mapped[str | None] = mapped_column(String(30), nullable=True)
    payment_status: Mapped[str] = mapped_column(String(20), server_default="PENDING", nullable=False)
    bank_details_id: Mapped[int | None] = mapped_column(BigInteger, ForeignKey("bank_details.id"), nullable=True)

    agreement_file_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    agreement_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    agreement_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    client_agreement_status: Mapped[str | None] = mapped_column(String(20), nullable=True)

    is_deleted: Mapped[bool] = mapped_column(Boolean, server_default="false", nullable=False)
    created_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), onupdate=func.now())