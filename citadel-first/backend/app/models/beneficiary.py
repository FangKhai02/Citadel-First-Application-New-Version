from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, Date, DateTime, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class Beneficiary(Base):
    """Client beneficiaries for trust product placements — pre-demise and post-demise."""

    __tablename__ = "beneficiaries"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, nullable=False, index=True)

    # ── Type ──
    beneficiary_type: Mapped[str] = mapped_column(String(20), nullable=False)  # "pre_demise" or "post_demise"
    same_as_settlor: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Personal Details ──
    full_name: Mapped[str | None] = mapped_column(String(255))
    nric: Mapped[str | None] = mapped_column(String(50))
    id_number: Mapped[str | None] = mapped_column(String(50))  # Passport no if non-Malaysian
    gender: Mapped[str | None] = mapped_column(String(10))
    dob: Mapped[date | None] = mapped_column(Date)
    relationship_to_settlor: Mapped[str | None] = mapped_column(String(50))

    # ── Address & Contact ──
    residential_address: Mapped[str | None] = mapped_column(String(500))
    mailing_address: Mapped[str | None] = mapped_column(String(500))
    email: Mapped[str | None] = mapped_column(String(255))
    contact_number: Mapped[str | None] = mapped_column(String(30))

    # ── Bank Details ──
    bank_account_name: Mapped[str | None] = mapped_column(String(255))
    bank_account_number: Mapped[str | None] = mapped_column(String(50))
    bank_name: Mapped[str | None] = mapped_column(String(255))
    bank_swift_code: Mapped[str | None] = mapped_column(String(20))
    bank_address: Mapped[str | None] = mapped_column(String(500))

    # ── Share Percentage ──
    share_percentage: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))

    # ── Attachments (S3 keys) ──
    settlor_nric_key: Mapped[str | None] = mapped_column(String(500))
    proof_of_address_key: Mapped[str | None] = mapped_column(String(500))
    beneficiary_id_key: Mapped[str | None] = mapped_column(String(500))
    bank_statement_key: Mapped[str | None] = mapped_column(String(500))

    # ── Soft Delete ──
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )