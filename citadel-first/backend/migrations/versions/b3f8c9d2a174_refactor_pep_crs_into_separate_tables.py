"""Refactor PEP and CRS into separate tables

Revision ID: b3f8c9d2a174
Revises: 271361af8fb3
Create Date: 2026-04-23 16:00:00.000000

"""
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision = "b3f8c9d2a174"
down_revision = "271361af8fb3"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── Create user_pep_declaration table ──
    op.create_table(
        "user_pep_declaration",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("app_user_id", sa.BigInteger(), nullable=False),
        sa.Column("is_pep", sa.Boolean(), nullable=False),
        sa.Column("pep_relationship", sa.String(30), nullable=True),
        sa.Column("pep_name", sa.String(255), nullable=True),
        sa.Column("pep_position", sa.String(255), nullable=True),
        sa.Column("pep_organisation", sa.String(255), nullable=True),
        sa.Column("pep_supporting_doc_key", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_pep_declaration_app_user_id", "user_pep_declaration", ["app_user_id"], unique=True)

    # ── Create user_crs_tax_residency table ──
    op.create_table(
        "user_crs_tax_residency",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("app_user_id", sa.BigInteger(), nullable=False),
        sa.Column("jurisdiction", sa.String(100), nullable=False),
        sa.Column("tin", sa.String(100), nullable=True),
        sa.Column("no_tin_reason", sa.String(1), nullable=True),
        sa.Column("reason_b_explanation", sa.String(500), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_user_crs_tax_residency_app_user_id", "user_crs_tax_residency", ["app_user_id"], unique=False)

    # ── Drop PEP and CRS columns from user_details ──
    op.drop_column("user_details", "crs_tax_residencies")
    op.drop_column("user_details", "is_pep")
    op.drop_column("user_details", "pep_relationship")
    op.drop_column("user_details", "pep_name")
    op.drop_column("user_details", "pep_position")
    op.drop_column("user_details", "pep_organisation")
    op.drop_column("user_details", "pep_supporting_doc_key")


def downgrade() -> None:
    # ── Re-add PEP and CRS columns to user_details ──
    op.add_column("user_details", sa.Column("crs_tax_residencies", sa.JSON(), nullable=True))
    op.add_column("user_details", sa.Column("is_pep", sa.Boolean(), nullable=True))
    op.add_column("user_details", sa.Column("pep_relationship", sa.String(30), nullable=True))
    op.add_column("user_details", sa.Column("pep_name", sa.String(255), nullable=True))
    op.add_column("user_details", sa.Column("pep_position", sa.String(255), nullable=True))
    op.add_column("user_details", sa.Column("pep_organisation", sa.String(255), nullable=True))
    op.add_column("user_details", sa.Column("pep_supporting_doc_key", sa.String(500), nullable=True))

    # ── Drop new tables ──
    op.drop_index("ix_user_crs_tax_residency_app_user_id", table_name="user_crs_tax_residency")
    op.drop_table("user_crs_tax_residency")
    op.drop_index("ix_user_pep_declaration_app_user_id", table_name="user_pep_declaration")
    op.drop_table("user_pep_declaration")