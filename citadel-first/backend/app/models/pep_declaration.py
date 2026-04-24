from datetime import datetime

from sqlalchemy import BigInteger, Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class PepDeclaration(Base):
    """PEP (Politically Exposed Person) declaration — 1:1 with AppUser."""

    __tablename__ = "user_pep_declaration"

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    app_user_id: Mapped[int] = mapped_column(
        BigInteger, unique=True, nullable=False, index=True
    )

    is_pep: Mapped[bool] = mapped_column(Boolean, nullable=False)
    pep_relationship: Mapped[str | None] = mapped_column(String(30))
    pep_name: Mapped[str | None] = mapped_column(String(255))
    pep_position: Mapped[str | None] = mapped_column(String(255))
    pep_organisation: Mapped[str | None] = mapped_column(String(255))
    pep_supporting_doc_key: Mapped[str | None] = mapped_column(String(500))

    created_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), onupdate=func.now()
    )