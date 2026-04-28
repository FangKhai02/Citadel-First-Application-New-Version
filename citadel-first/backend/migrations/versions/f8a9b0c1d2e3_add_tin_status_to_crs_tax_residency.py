"""Add tin_status column to user_crs_tax_residency table

Revision ID: f8a9b0c1d2e3
Revises: e6f7a8b9c0d2
Create Date: 2026-04-27
"""
from alembic import op
import sqlalchemy as sa

revision = "f8a9b0c1d2e3"
down_revision = "e6f7a8b9c0d2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_crs_tax_residency",
        sa.Column("tin_status", sa.String(10), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("user_crs_tax_residency", "tin_status")