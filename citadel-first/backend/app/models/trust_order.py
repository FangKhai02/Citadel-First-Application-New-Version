from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Date, DateTime, Numeric, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class TrustOrder(Base):
    """Trust product purchase orders — submitted by clients, reviewed by Vanguard."""

    __tablename__ = "trust_orders"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)

    # ── Trust Information (from Excel "API - Citadel Trust" sheet) ──
    date_of_trust_deed: Mapped[date | None] = mapped_column(Date)
    trust_asset_amount: Mapped[Decimal | None] = mapped_column(Numeric(15, 2))
    advisor_name: Mapped[str | None] = mapped_column(String(255))
    advisor_nric: Mapped[str | None] = mapped_column(String(50))

    # ── Vanguard-side fields (from Excel "API communicate with Citadel" sheet) ──
    trust_reference_id: Mapped[str | None] = mapped_column(String(50))
    case_status: Mapped[str] = mapped_column(String(30), default="PENDING", nullable=False)
    kyc_status: Mapped[str | None] = mapped_column(String(30))
    deferment_remark: Mapped[str | None] = mapped_column(Text)
    advisor_code: Mapped[str | None] = mapped_column(String(50))
    commencement_date: Mapped[date | None] = mapped_column(Date)
    trust_period_ending_date: Mapped[date | None] = mapped_column(Date)
    irrevocable_termination_notice_date: Mapped[date | None] = mapped_column(Date)
    auto_renewal_date: Mapped[date | None] = mapped_column(Date)

    # ── Attachment S3 keys ──
    projected_yield_schedule_key: Mapped[str | None] = mapped_column(String(500))
    acknowledgement_receipt_key: Mapped[str | None] = mapped_column(String(500))

    # ── Lark (Bitable) integration status ──
    lark_trust_record_id: Mapped[str | None] = mapped_column(String(100))
    lark_submission_status: Mapped[str | None] = mapped_column(String(20), default="PENDING")
    lark_submitted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    lark_error_message: Mapped[str | None] = mapped_column(Text)

    # ── Timestamps ──
    is_deleted: Mapped[bool] = mapped_column(default=False, nullable=False)
    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )