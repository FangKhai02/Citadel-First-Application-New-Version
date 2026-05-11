from datetime import datetime

from sqlalchemy import BigInteger, DateTime, SmallInteger, String, Text, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class BankDetails(Base):
    """Client bank accounts — maps to existing bank_details table from old vendor schema."""

    __tablename__ = "bank_details"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True, index=True)
    individual_beneficiary_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    corporate_shareholders_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    bank_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_number: Mapped[str | None] = mapped_column(String(255), nullable=True)
    account_holder_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    bank_address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    postcode: Mapped[str | None] = mapped_column(String(255), nullable=True)
    city: Mapped[str | None] = mapped_column(String(255), nullable=True)
    state: Mapped[str | None] = mapped_column(String(255), nullable=True)
    country: Mapped[str | None] = mapped_column(String(255), nullable=True)
    swift_code: Mapped[str | None] = mapped_column(String(255), nullable=True)
    bank_account_proof_key: Mapped[str | None] = mapped_column(Text, nullable=True)
    is_deleted: Mapped[int | None] = mapped_column(SmallInteger, nullable=True, default=0)
    agency_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    corporate_client_id: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    created_at: Mapped[datetime | None] = mapped_column(DateTime, server_default=func.now(), nullable=True)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime, onupdate=func.now(), nullable=True)