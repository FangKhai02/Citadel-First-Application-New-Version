"""add trust_orders table

Revision ID: j3k4l5m6n7o8
Revises: i2j3k4l5m6n7
Create Date: 2026-04-30 17:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "j3k4l5m6n7o8"
down_revision = "i2j3k4l5m6n7"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "trust_orders",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("app_user_id", sa.BigInteger(), nullable=False),
        sa.Column("date_of_trust_deed", sa.Date(), nullable=True),
        sa.Column("trust_asset_amount", sa.Numeric(15, 2), nullable=True),
        sa.Column("advisor_name", sa.String(255), nullable=True),
        sa.Column("advisor_nric", sa.String(50), nullable=True),
        sa.Column("trust_reference_id", sa.String(50), nullable=True),
        sa.Column("case_status", sa.String(30), nullable=False, server_default="PENDING"),
        sa.Column("kyc_status", sa.String(30), nullable=True),
        sa.Column("deferment_remark", sa.Text(), nullable=True),
        sa.Column("advisor_code", sa.String(50), nullable=True),
        sa.Column("commencement_date", sa.Date(), nullable=True),
        sa.Column("trust_period_ending_date", sa.Date(), nullable=True),
        sa.Column("irrevocable_termination_notice_date", sa.Date(), nullable=True),
        sa.Column("auto_renewal_date", sa.Date(), nullable=True),
        sa.Column("projected_yield_schedule_key", sa.String(500), nullable=True),
        sa.Column("acknowledgement_receipt_key", sa.String(500), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_trust_orders_app_user_id", "trust_orders", ["app_user_id"])


def downgrade() -> None:
    op.drop_index("ix_trust_orders_app_user_id", table_name="trust_orders")
    op.drop_table("trust_orders")