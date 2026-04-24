"""Add signature and agreement S3 keys to user_details

Revision ID: a1c2d3e4f5g6
Revises: b3f8c9d2a174
Create Date: 2026-04-24
"""
from alembic import op
import sqlalchemy as sa

revision = "a1c2d3e4f5g6"
down_revision = "b3f8c9d2a174"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("user_details", sa.Column("digital_signature_key", sa.String(500), nullable=True))
    op.add_column("user_details", sa.Column("onboarding_agreement_key", sa.String(500), nullable=True))


def downgrade() -> None:
    op.drop_column("user_details", "onboarding_agreement_key")
    op.drop_column("user_details", "digital_signature_key")