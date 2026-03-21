"""Create tenant AI provider configuration table.

Revision ID: 0006
Revises: 0005
Create Date: 2026-03-21
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0006"
down_revision = "0005"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ai_provider_configs",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("provider", sa.String(40), nullable=False),
        sa.Column("model_name", sa.String(120), nullable=False),
        sa.Column("api_base_url", sa.String(255), nullable=True),
        sa.Column("api_key_encrypted", sa.Text(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("temperature", sa.Numeric(3, 2), nullable=False, server_default="0.2"),
        sa.Column("max_tokens", sa.Numeric(5, 0), nullable=False, server_default="1200"),
        sa.Column("system_prompt_override", sa.Text(), nullable=True),
        sa.Column("updated_by_user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("last_validated_at", sa.DateTime(), nullable=True),
        sa.Column("last_validation_status", sa.String(40), nullable=True),
        sa.Column("last_validation_error", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("tenant_id", name="uq_ai_provider_config_tenant"),
    )
    op.create_index(
        "ix_ai_provider_configs_active",
        "ai_provider_configs",
        ["tenant_id", "is_active"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_ai_provider_configs_active", table_name="ai_provider_configs")
    op.drop_table("ai_provider_configs")
