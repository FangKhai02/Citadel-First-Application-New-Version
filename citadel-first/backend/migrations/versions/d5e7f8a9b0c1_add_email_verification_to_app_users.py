"""Add email verification columns to app_users

Revision ID: d5e7f8a9b0c1
Revises: c4e5f6a7b8c9
Create Date: 2026-04-24
"""
from alembic import op
import sqlalchemy as sa

revision = "d5e7f8a9b0c1"
down_revision = "c4e5f6a7b8c9"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "app_users",
        sa.Column("email_verified_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "app_users",
        sa.Column("email_verification_token", sa.String(), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("app_users", "email_verification_token")
    op.drop_column("app_users", "email_verified_at")