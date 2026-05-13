"""add lark submission tracking to trust orders

Revision ID: lark_001
Revises: l7m8n9o0p1q2
Create Date: 2026-05-11
"""
from alembic import op
import sqlalchemy as sa

revision = "lark_001"
down_revision = "l7m8n9o0p1q2"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "trust_orders",
        sa.Column("lark_trust_record_id", sa.String(100), nullable=True),
    )
    op.add_column(
        "trust_orders",
        sa.Column(
            "lark_submission_status",
            sa.String(20),
            nullable=True,
            server_default="PENDING",
        ),
    )
    op.add_column(
        "trust_orders",
        sa.Column("lark_submitted_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.add_column(
        "trust_orders",
        sa.Column("lark_error_message", sa.Text, nullable=True),
    )


def downgrade() -> None:
    op.drop_column("trust_orders", "lark_error_message")
    op.drop_column("trust_orders", "lark_submitted_at")
    op.drop_column("trust_orders", "lark_submission_status")
    op.drop_column("trust_orders", "lark_trust_record_id")