import asyncio
from logging.config import fileConfig

from sqlalchemy import pool
from sqlalchemy.engine import Connection
from sqlalchemy.ext.asyncio import async_engine_from_config, create_async_engine

from alembic import context

# Import app settings and all models so Alembic can detect them
from app.core.config import settings
from app.core.database import Base
from app.models.user import AppUser, AdminUser  # noqa: F401
from app.models.user_details import UserDetails  # noqa: F401
from app.models.signup import BankruptcyDeclaration, DisclaimerAcceptance  # noqa: F401
from app.models.face_verification import FaceVerification  # noqa: F401
from app.models.pep_declaration import PepDeclaration  # noqa: F401
from app.models.crs_tax_residency import CrsTaxResidency  # noqa: F401
from app.models.notification import Notification  # noqa: F401
from app.models.beneficiary import Beneficiary  # noqa: F401
from app.models.trust_order import TrustOrder  # noqa: F401
from app.models.trust_portfolio import TrustPortfolio  # noqa: F401
from app.models.bank_details import BankDetails  # noqa: F401
from app.models.trust_payment_receipt import TrustPaymentReceipt  # noqa: F401
from app.models.trust_dividend_history import TrustDividendHistory  # noqa: F401

# this is the Alembic Config object, which provides
# access to the values within the .ini file in use.
config = context.config

# Interpret the config file for Python logging.
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

# Database URL from settings — bypasses ini file to avoid interpolation issues
DB_URL = settings.DATABASE_URL


def run_migrations_offline() -> None:
    """Run migrations in 'offline' mode."""
    context.configure(
        url=DB_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection: Connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata)

    with context.begin_transaction():
        context.run_migrations()


async def run_async_migrations() -> None:
    """Create an async Engine and associate a connection with the context."""

    connectable = create_async_engine(
        DB_URL,
        poolclass=pool.NullPool,
    )

    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)

    await connectable.dispose()


def run_migrations_online() -> None:
    """Run migrations in 'online' mode."""

    asyncio.run(run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()