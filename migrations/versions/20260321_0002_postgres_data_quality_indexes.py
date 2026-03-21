"""Add Postgres-focused data quality constraints and tenant indexes.

Revision ID: 0002
Revises: 0001
Create Date: 2026-03-21
"""
from alembic import op


revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_unique_constraint(
        "uq_batch_tenant_product_number",
        "batches",
        ["tenant_id", "product_id", "batch_number"],
    )

    op.create_check_constraint(
        "ck_products_min_stock_non_negative",
        "products",
        "min_stock >= 0",
    )
    op.create_check_constraint(
        "ck_stock_balances_non_negative",
        "stock_balances",
        "balance >= 0",
    )
    op.create_check_constraint(
        "ck_stock_movements_quantity_positive",
        "stock_movements",
        "quantity > 0",
    )
    op.create_check_constraint(
        "ck_expenses_value_positive",
        "expenses",
        "value > 0",
    )

    op.create_index(
        "ix_movements_tenant_created_at",
        "stock_movements",
        ["tenant_id", "created_at"],
        unique=False,
    )
    op.create_index(
        "ix_expenses_tenant_category_date",
        "expenses",
        ["tenant_id", "category", "expense_date"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_expenses_tenant_category_date", table_name="expenses")
    op.drop_index("ix_movements_tenant_created_at", table_name="stock_movements")

    op.drop_constraint("ck_expenses_value_positive", "expenses", type_="check")
    op.drop_constraint(
        "ck_stock_movements_quantity_positive",
        "stock_movements",
        type_="check",
    )
    op.drop_constraint(
        "ck_stock_balances_non_negative",
        "stock_balances",
        type_="check",
    )
    op.drop_constraint(
        "ck_products_min_stock_non_negative",
        "products",
        type_="check",
    )

    op.drop_constraint(
        "uq_batch_tenant_product_number",
        "batches",
        type_="unique",
    )
