"""drop nature_of_business_other and widen nature_of_business

Revision ID: g0h1i2j3k4l5
Revises: f8a9b0c1d2e3
Create Date: 2026-04-28 07:30:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "g0h1i2j3k4l5"
down_revision = "f8a9b0c1d2e3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.drop_column("user_details", "nature_of_business_other")
    op.alter_column(
        "user_details",
        "nature_of_business",
        existing_type=sa.String(100),
        type_=sa.String(200),
        existing_nullable=True,
    )


def downgrade() -> None:
    op.alter_column(
        "user_details",
        "nature_of_business",
        existing_type=sa.String(200),
        type_=sa.String(100),
        existing_nullable=True,
    )
    op.add_column(
        "user_details",
        sa.Column("nature_of_business_other", sa.String(200), nullable=True),
    )