"""add settlor kyc crs pep fields to user_details

Revision ID: 271361af8fb3
Revises:
Create Date: 2026-04-23 10:18:42.289697

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '271361af8fb3'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── Settlor Info (personal details) ──
    op.add_column('user_details', sa.Column('title', sa.String(20), nullable=True))
    op.add_column('user_details', sa.Column('marital_status', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('passport_expiry', sa.Date(), nullable=True))

    # ── Settlor Info (address & contact) ──
    op.add_column('user_details', sa.Column('residential_address', sa.String(500), nullable=True))
    op.add_column('user_details', sa.Column('mailing_address', sa.String(500), nullable=True))
    op.add_column('user_details', sa.Column('mailing_same_as_residential', sa.Boolean(), nullable=True))
    op.add_column('user_details', sa.Column('home_telephone', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('mobile_number', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('email', sa.String(255), nullable=True))

    # ── Settlor Info (employment & financial) ──
    op.add_column('user_details', sa.Column('employment_type', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('occupation', sa.String(100), nullable=True))
    op.add_column('user_details', sa.Column('work_title', sa.String(100), nullable=True))
    op.add_column('user_details', sa.Column('nature_of_business', sa.String(100), nullable=True))
    op.add_column('user_details', sa.Column('employer_name', sa.String(255), nullable=True))
    op.add_column('user_details', sa.Column('employer_address', sa.String(500), nullable=True))
    op.add_column('user_details', sa.Column('employer_telephone', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('annual_income_range', sa.String(50), nullable=True))
    op.add_column('user_details', sa.Column('estimated_net_worth', sa.String(50), nullable=True))

    # ── Settlor KYC ──
    op.add_column('user_details', sa.Column('source_of_trust_fund', sa.String(100), nullable=True))
    op.add_column('user_details', sa.Column('source_of_income', sa.String(255), nullable=True))
    op.add_column('user_details', sa.Column('country_of_birth', sa.String(100), nullable=True))
    op.add_column('user_details', sa.Column('physically_present', sa.Boolean(), nullable=True))
    op.add_column('user_details', sa.Column('main_sources_of_income', sa.String(1000), nullable=True))
    op.add_column('user_details', sa.Column('has_unusual_transactions', sa.Boolean(), nullable=True))
    op.add_column('user_details', sa.Column('marital_history', sa.String(1000), nullable=True))
    op.add_column('user_details', sa.Column('geographical_connections', sa.String(1000), nullable=True))
    op.add_column('user_details', sa.Column('other_relevant_info', sa.String(2000), nullable=True))

    # ── CRS (tax residency) ──
    op.add_column('user_details', sa.Column('crs_tax_residencies', sa.JSON(), nullable=True))

    # ── PEP Declaration ──
    op.add_column('user_details', sa.Column('is_pep', sa.Boolean(), nullable=True))
    op.add_column('user_details', sa.Column('pep_relationship', sa.String(30), nullable=True))
    op.add_column('user_details', sa.Column('pep_name', sa.String(255), nullable=True))
    op.add_column('user_details', sa.Column('pep_position', sa.String(255), nullable=True))
    op.add_column('user_details', sa.Column('pep_organisation', sa.String(255), nullable=True))
    op.add_column('user_details', sa.Column('pep_supporting_doc_key', sa.String(500), nullable=True))


def downgrade() -> None:
    # ── PEP Declaration ──
    op.drop_column('user_details', 'pep_supporting_doc_key')
    op.drop_column('user_details', 'pep_organisation')
    op.drop_column('user_details', 'pep_position')
    op.drop_column('user_details', 'pep_name')
    op.drop_column('user_details', 'pep_relationship')
    op.drop_column('user_details', 'is_pep')

    # ── CRS ──
    op.drop_column('user_details', 'crs_tax_residencies')

    # ── Settlor KYC ──
    op.drop_column('user_details', 'other_relevant_info')
    op.drop_column('user_details', 'geographical_connections')
    op.drop_column('user_details', 'marital_history')
    op.drop_column('user_details', 'has_unusual_transactions')
    op.drop_column('user_details', 'main_sources_of_income')
    op.drop_column('user_details', 'physically_present')
    op.drop_column('user_details', 'country_of_birth')
    op.drop_column('user_details', 'source_of_income')
    op.drop_column('user_details', 'source_of_trust_fund')

    # ── Employment & financial ──
    op.drop_column('user_details', 'estimated_net_worth')
    op.drop_column('user_details', 'annual_income_range')
    op.drop_column('user_details', 'employer_telephone')
    op.drop_column('user_details', 'employer_address')
    op.drop_column('user_details', 'employer_name')
    op.drop_column('user_details', 'nature_of_business')
    op.drop_column('user_details', 'work_title')
    op.drop_column('user_details', 'occupation')
    op.drop_column('user_details', 'employment_type')

    # ── Address & contact ──
    op.drop_column('user_details', 'email')
    op.drop_column('user_details', 'mobile_number')
    op.drop_column('user_details', 'home_telephone')
    op.drop_column('user_details', 'mailing_same_as_residential')
    op.drop_column('user_details', 'mailing_address')
    op.drop_column('user_details', 'residential_address')

    # ── Personal details ──
    op.drop_column('user_details', 'passport_expiry')
    op.drop_column('user_details', 'marital_status')
    op.drop_column('user_details', 'title')