"""add beneficiaries table

Revision ID: h1i2j3k4l5m6
Revises: g0h1i2j3k4l5
Create Date: 2026-04-28 20:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "h1i2j3k4l5m6"
down_revision = "g0h1i2j3k4l5"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "beneficiaries",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("app_user_id", sa.BigInteger(), nullable=False),
        sa.Column("beneficiary_type", sa.String(20), nullable=False),
        sa.Column("same_as_settlor", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("nric", sa.String(50), nullable=True),
        sa.Column("id_number", sa.String(50), nullable=True),
        sa.Column("gender", sa.String(10), nullable=True),
        sa.Column("dob", sa.Date(), nullable=True),
        sa.Column("relationship_to_settlor", sa.String(50), nullable=True),
        sa.Column("residential_address", sa.String(500), nullable=True),
        sa.Column("mailing_address", sa.String(500), nullable=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("contact_number", sa.String(30), nullable=True),
        sa.Column("bank_account_name", sa.String(255), nullable=True),
        sa.Column("bank_account_number", sa.String(50), nullable=True),
        sa.Column("bank_name", sa.String(255), nullable=True),
        sa.Column("bank_swift_code", sa.String(20), nullable=True),
        sa.Column("bank_address", sa.String(500), nullable=True),
        sa.Column("share_percentage", sa.Numeric(5, 2), nullable=True),
        sa.Column("settlor_nric_key", sa.String(500), nullable=True),
        sa.Column("proof_of_address_key", sa.String(500), nullable=True),
        sa.Column("beneficiary_id_key", sa.String(500), nullable=True),
        sa.Column("bank_statement_key", sa.String(500), nullable=True),
        sa.Column("is_deleted", sa.Boolean(), nullable=False, server_default="false"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_beneficiaries_app_user_id", "beneficiaries", ["app_user_id"])


def downgrade() -> None:
    op.drop_index("ix_beneficiaries_app_user_id", table_name="beneficiaries")
    op.drop_table("beneficiaries")