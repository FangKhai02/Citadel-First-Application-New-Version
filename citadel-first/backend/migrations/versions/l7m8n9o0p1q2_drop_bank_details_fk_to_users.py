"""drop_bank_details_fk_to_users

Revision ID: l7m8n9o0p1q2
Revises: k5l6m7n8o9p0
Create Date: 2026-05-06 16:44:50.107519

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'l7m8n9o0p1q2'
down_revision: Union[str, None] = 'k5l6m7n8o9p0'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Drop the old FK from bank_details -> users (admin table) if it exists.
    # On fresh installs this constraint won't exist, so skip gracefully.
    conn = op.get_bind()
    result = conn.execute(
        sa.text(
            "SELECT 1 FROM information_schema.table_constraints "
            "WHERE constraint_name = 'bank_details_user_id_foreign' "
            "AND table_name = 'bank_details'"
        )
    )
    if result.fetchone() is not None:
        op.drop_constraint('bank_details_user_id_foreign', 'bank_details', type_='foreignkey')


def downgrade() -> None:
    # Re-add FK only if bank_details has an app_user_id column referencing users
    try:
        op.create_foreign_key('bank_details_user_id_foreign', 'bank_details', 'users', ['app_user_id'], ['id'])
    except Exception:
        pass