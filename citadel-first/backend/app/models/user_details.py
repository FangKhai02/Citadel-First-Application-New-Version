from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Boolean, Date, DateTime, Numeric, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UserDetails(Base):
    """Extended user profile populated during signup — identity docs, OCR data, settlor info, and KYC."""

    __tablename__ = "user_details"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False, index=True)

    # ── Identity / OCR fields (populated during document review) ──
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

    # ── Settlor Info (personal details page) ──
    title: Mapped[str | None] = mapped_column(String(20))
    marital_status: Mapped[str | None] = mapped_column(String(30))
    passport_expiry: Mapped[date | None] = mapped_column(Date)

    # ── Settlor Info (address & contact page) ──
    residential_address: Mapped[str | None] = mapped_column(String(500))
    mailing_address: Mapped[str | None] = mapped_column(String(500))
    mailing_same_as_residential: Mapped[bool | None] = mapped_column(Boolean, default=True)
    home_telephone: Mapped[str | None] = mapped_column(String(30))
    mobile_number: Mapped[str | None] = mapped_column(String(30))
    email: Mapped[str | None] = mapped_column(String(255))

    # ── Settlor Info (employment & financial page) ──
    employment_type: Mapped[str | None] = mapped_column(String(30))
    occupation: Mapped[str | None] = mapped_column(String(100))
    work_title: Mapped[str | None] = mapped_column(String(100))
    nature_of_business: Mapped[str | None] = mapped_column(String(100))
    employer_name: Mapped[str | None] = mapped_column(String(255))
    employer_address: Mapped[str | None] = mapped_column(String(500))
    employer_telephone: Mapped[str | None] = mapped_column(String(30))
    annual_income_range: Mapped[str | None] = mapped_column(String(50))
    estimated_net_worth: Mapped[str | None] = mapped_column(String(50))

    # ── Settlor KYC ──
    source_of_trust_fund: Mapped[str | None] = mapped_column(String(100))
    source_of_income: Mapped[str | None] = mapped_column(String(255))
    country_of_birth: Mapped[str | None] = mapped_column(String(100))
    physically_present: Mapped[bool | None] = mapped_column(Boolean)
    main_sources_of_income: Mapped[str | None] = mapped_column(String(1000))
    has_unusual_transactions: Mapped[bool | None] = mapped_column(Boolean)
    marital_history: Mapped[str | None] = mapped_column(String(1000))
    geographical_connections: Mapped[str | None] = mapped_column(String(1000))
    other_relevant_info: Mapped[str | None] = mapped_column(String(2000))

    # ── E-Sign Onboarding Agreement ──
    digital_signature_key: Mapped[str | None] = mapped_column(String(500))
    onboarding_agreement_key: Mapped[str | None] = mapped_column(String(500))

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )
