"""alter notifications table to match new schema

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
    # Rename camelCase columns to snake_case
    op.alter_column("notifications", "hasRead", new_column_name="is_read")
    op.alter_column("notifications", "createdAt", new_column_name="created_at")

    # Change is_read from smallint to integer and set default
    op.alter_column(
        "notifications", "is_read",
        type_=sa.Integer(),
        existing_type=sa.SmallInteger(),
        nullable=False,
        server_default="0",
    )

    # Change created_at from timestamp without tz to timestamp with tz
    op.alter_column(
        "notifications", "created_at",
        type_=sa.DateTime(timezone=True),
        existing_type=sa.DateTime(),
        existing_server_default=None,
        server_default=sa.func.now(),
    )

    # Make title and message NOT NULL (add defaults first to handle any NULLs)
    op.execute("UPDATE notifications SET title = '' WHERE title IS NULL")
    op.execute("UPDATE notifications SET message = '' WHERE message IS NULL")
    op.alter_column("notifications", "title", nullable=False)
    op.alter_column("notifications", "message", nullable=False)

    # Drop unused columns
    op.drop_column("notifications", "one_signal_notification_id")
    op.drop_column("notifications", "imageUrl")
    op.drop_column("notifications", "launchUrl")

    # Drop old index on one_signal_notification_id (already dropped with column)
    # Add new index on app_user_id if not already present (old table has one named "app_user_id")
    # The existing index "app_user_id" on column app_user_id already exists, so no new index needed.


def downgrade() -> None:
    # Re-add dropped columns
    op.add_column("notifications", sa.Column("one_signal_notification_id", sa.String(255), nullable=True))
    op.add_column("notifications", sa.Column("imageUrl", sa.String(500), nullable=True))
    op.add_column("notifications", sa.Column("launchUrl", sa.String(500), nullable=True))

    # Revert title and message to nullable
    op.alter_column("notifications", "message", nullable=True)
    op.alter_column("notifications", "title", nullable=True)

    # Revert created_at to timestamp without tz
    op.alter_column(
        "notifications", "created_at",
        type_=sa.DateTime(),
        existing_type=sa.DateTime(timezone=True),
        server_default=None,
        existing_server_default=sa.func.now(),
    )

    # Revert is_read to smallint
    op.alter_column(
        "notifications", "is_read",
        type_=sa.SmallInteger(),
        existing_type=sa.Integer(),
        nullable=True,
        server_default=None,
    )

    # Rename back to camelCase
    op.alter_column("notifications", "created_at", new_column_name="createdAt")
    op.alter_column("notifications", "is_read", new_column_name="hasRead")