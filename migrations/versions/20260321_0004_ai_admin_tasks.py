"""Create AI admin tasks table for proactive administrative work.

Revision ID: 0004
Revises: 0003
Create Date: 2026-03-21
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0004"
down_revision = "0003"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "ai_admin_tasks",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "tenant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tenants.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("task_type", sa.String(40), nullable=False),
        sa.Column("status", sa.String(40), nullable=False, server_default="suggested"),
        sa.Column("title", sa.String(180), nullable=False),
        sa.Column("description", sa.Text(), nullable=False),
        sa.Column("priority_score", sa.Numeric(5, 2), nullable=False),
        sa.Column("due_date", sa.DateTime(), nullable=True),
        sa.Column("task_key", sa.String(180), nullable=False),
        sa.Column("context_payload", sa.JSON(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("tenant_id", "task_key", name="uq_ai_admin_task_tenant_key"),
        sa.CheckConstraint(
            "priority_score >= 0 AND priority_score <= 100",
            name="ck_ai_admin_task_priority_range",
        ),
    )
    op.create_index(
        "ix_ai_admin_tasks_tenant_status",
        "ai_admin_tasks",
        ["tenant_id", "status"],
        unique=False,
    )
    op.create_index(
        "ix_ai_admin_tasks_tenant_due_date",
        "ai_admin_tasks",
        ["tenant_id", "due_date"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_ai_admin_tasks_tenant_due_date", table_name="ai_admin_tasks")
    op.drop_index("ix_ai_admin_tasks_tenant_status", table_name="ai_admin_tasks")
    op.drop_table("ai_admin_tasks")
