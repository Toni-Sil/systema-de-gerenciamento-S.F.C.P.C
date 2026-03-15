"""Initial schema: tenants, users, products, locations, batches,
stock_balances, stock_movements, expenses.

Revision ID: 0001
Revises: (none)
Create Date: 2026-03-15
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ------------------------------------------------------------------
    # tenants
    # ------------------------------------------------------------------
    op.create_table(
        "tenants",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("name", sa.String(120), nullable=False),
        sa.Column("slug", sa.String(80), nullable=False, unique=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_tenants_slug", "tenants", ["slug"], unique=True)

    # ------------------------------------------------------------------
    # users
    # ------------------------------------------------------------------
    op.create_table(
        "users",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("username", sa.String(60), nullable=False),
        sa.Column("email", sa.String(255), nullable=False),
        sa.Column("hashed_password", sa.String(255), nullable=False),
        sa.Column("role", sa.String(20), nullable=False, server_default="operator"),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("tenant_id", "username", name="uq_user_tenant_username"),
        sa.UniqueConstraint("tenant_id", "email", name="uq_user_tenant_email"),
    )
    op.create_index("ix_users_tenant_id", "users", ["tenant_id"])

    # ------------------------------------------------------------------
    # products
    # ------------------------------------------------------------------
    op.create_table(
        "products",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("code", sa.String(40), nullable=False),
        sa.Column("description", sa.String(255), nullable=False),
        sa.Column("unit", sa.String(20), nullable=False),
        sa.Column("min_stock", sa.Float, nullable=False, server_default="0"),
        sa.Column("category", sa.String(30), nullable=True),
        sa.Column("attributes", postgresql.JSONB, nullable=True),
        sa.Column("is_active", sa.Boolean, nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("tenant_id", "code", name="uq_product_tenant_code"),
    )
    op.create_index("ix_products_tenant_id", "products", ["tenant_id"])

    # ------------------------------------------------------------------
    # locations
    # ------------------------------------------------------------------
    op.create_table(
        "locations",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("corredor", sa.String(40), nullable=False),
        sa.Column("prateleira", sa.String(40), nullable=False),
        sa.Column("nivel", sa.String(20), nullable=True),
    )
    op.create_index("ix_locations_tenant_id", "locations", ["tenant_id"])

    # ------------------------------------------------------------------
    # batches
    # ------------------------------------------------------------------
    op.create_table(
        "batches",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("batch_number", sa.String(80), nullable=False),
        sa.Column("validity_date", sa.Date, nullable=True),
    )
    op.create_index("ix_batches_tenant_product", "batches", ["tenant_id", "product_id"])

    # ------------------------------------------------------------------
    # stock_balances
    # ------------------------------------------------------------------
    op.create_table(
        "stock_balances",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("batch_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("batches.id"), nullable=True),
        sa.Column("location_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("locations.id"), nullable=True),
        sa.Column("balance", sa.Float, nullable=False, server_default="0"),
        sa.UniqueConstraint(
            "tenant_id", "product_id", "batch_id", "location_id",
            name="uq_balance_key"
        ),
    )
    op.create_index("ix_stock_balance_tenant_product", "stock_balances", ["tenant_id", "product_id"])

    # ------------------------------------------------------------------
    # stock_movements
    # ------------------------------------------------------------------
    op.create_table(
        "stock_movements",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("product_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("products.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True),
        sa.Column("batch_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("batches.id"), nullable=True),
        sa.Column("location_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("locations.id"), nullable=True),
        sa.Column("type", sa.String(20), nullable=False),
        sa.Column("quantity", sa.Float, nullable=False),
        sa.Column("reference_doc", sa.String(120), nullable=True),
        sa.Column("notes", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_movements_tenant_product", "stock_movements", ["tenant_id", "product_id"])
    op.create_index("ix_movements_created_at", "stock_movements", ["created_at"])

    # ------------------------------------------------------------------
    # expenses
    # ------------------------------------------------------------------
    op.create_table(
        "expenses",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True),
                  sa.ForeignKey("users.id"), nullable=True),
        sa.Column("value", sa.Float, nullable=False),
        sa.Column("category", sa.String(40), nullable=False),
        sa.Column("supplier", sa.String(120), nullable=True),
        sa.Column("description", sa.Text, nullable=True),
        sa.Column("reference_doc", sa.String(120), nullable=True),
        sa.Column("expense_date", sa.Date, nullable=False),
        sa.Column("created_at", sa.DateTime, nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_expenses_tenant_date", "expenses", ["tenant_id", "expense_date"])


def downgrade() -> None:
    op.drop_table("expenses")
    op.drop_table("stock_movements")
    op.drop_table("stock_balances")
    op.drop_table("batches")
    op.drop_table("locations")
    op.drop_table("products")
    op.drop_table("users")
    op.drop_table("tenants")
