"""Use NUMERIC for inventory and financial precision.

Revision ID: 0003
Revises: 0002
Create Date: 2026-03-21
"""
from alembic import op
import sqlalchemy as sa


revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None


NUMERIC_MONEY = sa.Numeric(12, 2)


def upgrade() -> None:
    op.alter_column(
        "products",
        "min_stock",
        existing_type=sa.Float(),
        type_=NUMERIC_MONEY,
        existing_nullable=False,
        postgresql_using="min_stock::numeric(12,2)",
    )
    op.alter_column(
        "stock_balances",
        "balance",
        existing_type=sa.Float(),
        type_=NUMERIC_MONEY,
        existing_nullable=False,
        postgresql_using="balance::numeric(12,2)",
    )
    op.alter_column(
        "stock_movements",
        "quantity",
        existing_type=sa.Float(),
        type_=NUMERIC_MONEY,
        existing_nullable=False,
        postgresql_using="quantity::numeric(12,2)",
    )
    op.alter_column(
        "expenses",
        "value",
        existing_type=sa.Float(),
        type_=NUMERIC_MONEY,
        existing_nullable=False,
        postgresql_using="value::numeric(12,2)",
    )


def downgrade() -> None:
    op.alter_column(
        "expenses",
        "value",
        existing_type=NUMERIC_MONEY,
        type_=sa.Float(),
        existing_nullable=False,
        postgresql_using="value::double precision",
    )
    op.alter_column(
        "stock_movements",
        "quantity",
        existing_type=NUMERIC_MONEY,
        type_=sa.Float(),
        existing_nullable=False,
        postgresql_using="quantity::double precision",
    )
    op.alter_column(
        "stock_balances",
        "balance",
        existing_type=NUMERIC_MONEY,
        type_=sa.Float(),
        existing_nullable=False,
        postgresql_using="balance::double precision",
    )
    op.alter_column(
        "products",
        "min_stock",
        existing_type=NUMERIC_MONEY,
        type_=sa.Float(),
        existing_nullable=False,
        postgresql_using="min_stock::double precision",
    )
