"""Add signup_completed_at to app_users

Revision ID: c4e5f6a7b8c9
Revises: a1c2d3e4f5g6
Create Date: 2026-04-24
"""
from alembic import op
import sqlalchemy as sa

revision = "c4e5f6a7b8c9"
down_revision = "a1c2d3e4f5g6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "app_users",
        sa.Column("signup_completed_at", sa.DateTime(timezone=True), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("app_users", "signup_completed_at")