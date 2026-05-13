"""set app_users_id_seq to start at 100001

Revision ID: m8n9o0p1q2r3
Revises: l7m8n9o0p1q2
Create Date: 2026-05-13 10:00:00.000000

Ensures new app_users IDs start from 100001 to avoid collisions
with any legacy data that may exist in the table.
"""

from alembic import op
import sqlalchemy as sa

revision = "m8n9o0p1q2r3"
down_revision = "lark_001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Find the actual sequence attached to app_users.id.
    # On legacy DBs the original vendor sequence may still exist alongside a
    # newer one (e.g. app_users_id_seq1). We need to reset whichever sequence
    # the column is currently using.
    conn = op.get_bind()

    # Determine the sequence name used by app_users.id
    result = conn.execute(
        sa.text(
            "SELECT pg_get_serial_sequence('app_users', 'id')"
        )
    )
    seq_name_row = result.fetchone()
    seq_name = seq_name_row[0] if seq_name_row and seq_name_row[0] else "app_users_id_seq"

    # Strip schema prefix if present (e.g. "public.app_users_id_seq" -> "app_users_id_seq")
    if "." in seq_name:
        seq_name = seq_name.split(".")[-1]

    # Reset the sequence so the next inserted ID is 100001.
    # If the current value is already >= 100001 this is a no-op.
    conn.execute(
        sa.text(
            f"SELECT setval('{seq_name}', GREATEST((SELECT COALESCE(MAX(id), 0) FROM app_users), 100000))"
        )
    )


def downgrade() -> None:
    # Cannot reliably determine the original sequence value, so we leave it as-is.
    pass