"""add notifications table

Revision ID: i2j3k4l5m6n7
Revises: h1i2j3k4l5m6
Create Date: 2026-04-29 14:00:00.000000

"""
from alembic import op
import sqlalchemy as sa

revision = "i2j3k4l5m6n7"
down_revision = "h1i2j3k4l5m6"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Check if the notifications table already exists (from old vendor schema)
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename='notifications'"
        )
    )
    notifications_exists = result.fetchone() is not None

    if notifications_exists:
        # Migrate from old vendor schema: rename camelCase columns
        op.alter_column("notifications", "hasRead", new_column_name="is_read")
        op.alter_column("notifications", "createdAt", new_column_name="created_at")

        op.alter_column(
            "notifications", "is_read",
            type_=sa.Integer(),
            existing_type=sa.SmallInteger(),
            nullable=False,
            server_default="0",
        )
        op.alter_column(
            "notifications", "created_at",
            type_=sa.DateTime(timezone=True),
            existing_type=sa.DateTime(),
            existing_server_default=None,
            server_default=sa.func.now(),
        )

        op.execute("UPDATE notifications SET title = '' WHERE title IS NULL")
        op.execute("UPDATE notifications SET message = '' WHERE message IS NULL")
        op.alter_column("notifications", "title", nullable=False)
        op.alter_column("notifications", "message", nullable=False)

        op.drop_column("notifications", "one_signal_notification_id")
        op.drop_column("notifications", "imageUrl")
        op.drop_column("notifications", "launchUrl")
    else:
        # Create fresh notifications table with the new schema
        op.create_table(
            "notifications",
            sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
            sa.Column("app_user_id", sa.BigInteger(), nullable=False),
            sa.Column("title", sa.String(255), nullable=False),
            sa.Column("message", sa.String(500), nullable=False),
            sa.Column("type", sa.String(50), nullable=False, server_default="info"),
            sa.Column("is_read", sa.Integer(), nullable=False, server_default="0"),
            sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
            sa.PrimaryKeyConstraint("id"),
        )
        op.create_index("ix_notifications_app_user_id", "notifications", ["app_user_id"])


def downgrade() -> None:
    # Drop the notifications table entirely on downgrade
    # (Old vendor data is not preserved on fresh installs)
    op.drop_index("ix_notifications_app_user_id", table_name="notifications")
    op.drop_table("notifications")