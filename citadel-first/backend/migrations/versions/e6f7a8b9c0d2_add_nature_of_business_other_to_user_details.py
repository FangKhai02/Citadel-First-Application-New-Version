"""Add nature_of_business_other column to user_details

Revision ID: e6f7a8b9c0d2
Revises: d5e7f8a9b0c1
Create Date: 2026-04-27
"""
from alembic import op
import sqlalchemy as sa

revision = "e6f7a8b9c0d2"
down_revision = "d5e7f8a9b0c1"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "user_details",
        sa.Column("nature_of_business_other", sa.String(200), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("user_details", "nature_of_business_other")