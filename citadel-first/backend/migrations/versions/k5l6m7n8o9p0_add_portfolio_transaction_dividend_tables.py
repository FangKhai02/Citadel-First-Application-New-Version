"""add portfolio transaction dividend tables

Revision ID: k5l6m7n8o9p0
Revises: j3k4l5m6n7o8
Create Date: 2026-05-06 18:00:00.000000

Note: bank_details table already exists from old vendor schema.
This migration only creates the new tables that reference it.

"""
from alembic import op
import sqlalchemy as sa

revision = "k5l6m7n8o9p0"
down_revision = "j3k4l5m6n7o8"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # trust_portfolios table (references existing bank_details table)
    op.create_table(
        "trust_portfolios",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("app_user_id", sa.BigInteger(), nullable=False),
        sa.Column("trust_order_id", sa.BigInteger(), nullable=True),
        sa.Column("product_name", sa.String(255), server_default="CWD Trust", nullable=False),
        sa.Column("product_code", sa.String(50), server_default="CWD", nullable=False),
        sa.Column("dividend_rate", sa.Numeric(5, 2), nullable=True),
        sa.Column("investment_tenure_months", sa.Integer(), nullable=True),
        sa.Column("maturity_date", sa.Date(), nullable=True),
        sa.Column("payout_frequency", sa.String(20), server_default="QUARTERLY", nullable=False),
        sa.Column("is_prorated", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("status", sa.String(30), server_default="PENDING_PAYMENT", nullable=False),
        sa.Column("payment_method", sa.String(30), nullable=True),
        sa.Column("payment_status", sa.String(20), server_default="PENDING", nullable=False),
        sa.Column("bank_details_id", sa.BigInteger(), nullable=True),
        sa.Column("agreement_file_name", sa.String(255), nullable=True),
        sa.Column("agreement_key", sa.String(500), nullable=True),
        sa.Column("agreement_date", sa.Date(), nullable=True),
        sa.Column("client_agreement_status", sa.String(20), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), server_default="false", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["app_user_id"], ["app_users.id"]),
        sa.ForeignKeyConstraint(["trust_order_id"], ["trust_orders.id"]),
        sa.ForeignKeyConstraint(["bank_details_id"], ["bank_details.id"]),
    )
    op.create_index("ix_trust_portfolios_app_user_id", "trust_portfolios", ["app_user_id"])

    # trust_payment_receipts table
    op.create_table(
        "trust_payment_receipts",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("trust_portfolio_id", sa.BigInteger(), nullable=False),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_key", sa.String(500), nullable=False),
        sa.Column("upload_status", sa.String(20), server_default="DRAFT", nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["trust_portfolio_id"], ["trust_portfolios.id"]),
    )
    op.create_index("ix_trust_payment_receipts_portfolio_id", "trust_payment_receipts", ["trust_portfolio_id"])

    # trust_dividend_history table
    op.create_table(
        "trust_dividend_history",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("trust_portfolio_id", sa.BigInteger(), nullable=False),
        sa.Column("reference_number", sa.String(50), nullable=False),
        sa.Column("dividend_amount", sa.Numeric(15, 2), nullable=False),
        sa.Column("trustee_fee_amount", sa.Numeric(15, 2), server_default="0", nullable=False),
        sa.Column("period_starting_date", sa.Date(), nullable=True),
        sa.Column("period_ending_date", sa.Date(), nullable=True),
        sa.Column("dividend_quarter", sa.Integer(), server_default="0", nullable=False),
        sa.Column("payment_status", sa.String(20), server_default="PENDING", nullable=False),
        sa.Column("payment_date", sa.Date(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        sa.ForeignKeyConstraint(["trust_portfolio_id"], ["trust_portfolios.id"]),
        sa.UniqueConstraint("reference_number", name="uq_dividend_reference_number"),
    )
    op.create_index("ix_trust_dividend_history_portfolio_id", "trust_dividend_history", ["trust_portfolio_id"])


def downgrade() -> None:
    op.drop_index("ix_trust_dividend_history_portfolio_id", table_name="trust_dividend_history")
    op.drop_table("trust_dividend_history")

    op.drop_index("ix_trust_payment_receipts_portfolio_id", table_name="trust_payment_receipts")
    op.drop_table("trust_payment_receipts")

    op.drop_index("ix_trust_portfolios_app_user_id", table_name="trust_portfolios")
    op.drop_table("trust_portfolios")