"""Add admin memory tables and feedback columns.

Revision ID: 0005
Revises: 0004
Create Date: 2026-03-21
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "0005"
down_revision = "0004"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("ai_admin_tasks", sa.Column("feedback_status", sa.String(40), nullable=True))
    op.add_column("ai_admin_tasks", sa.Column("feedback_note", sa.Text(), nullable=True))
    op.add_column("ai_admin_tasks", sa.Column("resolved_by_user_id", postgresql.UUID(as_uuid=True), nullable=True))
    op.add_column("ai_admin_tasks", sa.Column("resolved_at", sa.DateTime(), nullable=True))
    op.add_column("ai_admin_tasks", sa.Column("resolution_time_minutes", sa.Float(), nullable=True))
    op.create_foreign_key(
        "fk_ai_admin_tasks_resolved_by_user",
        "ai_admin_tasks",
        "users",
        ["resolved_by_user_id"],
        ["id"],
    )

    op.create_table(
        "ai_admin_profiles",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("user_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("communication_style", sa.String(40), nullable=False, server_default="executive"),
        sa.Column("priority_focus", sa.String(40), nullable=False, server_default="balanced"),
        sa.Column("briefing_hour", sa.Numeric(2, 0), nullable=False, server_default="7"),
        sa.Column("max_daily_tasks", sa.Numeric(2, 0), nullable=False, server_default="5"),
        sa.Column("prefers_whatsapp", sa.Boolean(), nullable=False, server_default="true"),
        sa.Column("created_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
        sa.UniqueConstraint("tenant_id", "user_id", name="uq_ai_admin_profile_tenant_user"),
    )
    op.create_index("ix_ai_admin_profiles_tenant", "ai_admin_profiles", ["tenant_id"], unique=False)

    op.create_table(
        "ai_admin_briefings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column("tenant_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False),
        sa.Column("headline", sa.String(255), nullable=False),
        sa.Column("summary", sa.Text(), nullable=False),
        sa.Column("metrics", sa.JSON(), nullable=False),
        sa.Column("recommended_task_keys", sa.JSON(), nullable=True),
        sa.Column("generated_at", sa.DateTime(), nullable=False, server_default=sa.func.now()),
    )
    op.create_index("ix_ai_admin_briefings_tenant_generated", "ai_admin_briefings", ["tenant_id", "generated_at"], unique=False)


def downgrade() -> None:
    op.drop_index("ix_ai_admin_briefings_tenant_generated", table_name="ai_admin_briefings")
    op.drop_table("ai_admin_briefings")

    op.drop_index("ix_ai_admin_profiles_tenant", table_name="ai_admin_profiles")
    op.drop_table("ai_admin_profiles")

    op.drop_constraint("fk_ai_admin_tasks_resolved_by_user", "ai_admin_tasks", type_="foreignkey")
    op.drop_column("ai_admin_tasks", "resolution_time_minutes")
    op.drop_column("ai_admin_tasks", "resolved_at")
    op.drop_column("ai_admin_tasks", "resolved_by_user_id")
    op.drop_column("ai_admin_tasks", "feedback_note")
    op.drop_column("ai_admin_tasks", "feedback_status")
