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
    # The existing bank_details.app_user_id FK points to users (admin table),
    # but our app associates bank accounts with app_users.
    # Drop the wrong FK — existing data has app_user_id referencing admin users table,
    # so we can't add a new FK to app_users without cleaning up orphaned data first.
    # We'll handle this relationship at the application level instead.
    op.drop_constraint('bank_details_user_id_foreign', 'bank_details', type_='foreignkey')


def downgrade() -> None:
    op.create_foreign_key('bank_details_user_id_foreign', 'bank_details', 'users', ['app_user_id'], ['id'])
