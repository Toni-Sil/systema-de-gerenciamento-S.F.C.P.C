"""SQLAlchemy ORM models — the authoritative source of truth for the DB schema.

Naming conventions:
- Table names: snake_case, plural (e.g. products, stock_movements)
- All tenant-scoped tables have a non-nullable tenant_id (UUID, FK to tenants)
- Soft-delete via is_active flag where applicable
"""
from datetime import datetime, date
from typing import Optional
from uuid import uuid4

from sqlalchemy import (
    Boolean, Column, Date, DateTime, Enum as SAEnum,
    Float, ForeignKey, Index, Numeric, String, Text, UniqueConstraint, JSON,
    CheckConstraint,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.entities import (
    AIAdminFeedbackStatus,
    AICommunicationStyle,
    AIProviderType,
    AIPriorityFocus,
    AIAdminTaskStatus,
    AIAdminTaskType,
    MovementType,
    ProductCategory,
    UserRole,
    ExpenseCategory,
)


def _uuid():
    return str(uuid4())


# ---------------------------------------------------------------------------
# Tenant
# ---------------------------------------------------------------------------

class TenantORM(Base):
    __tablename__ = "tenants"

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    name = Column(String(120), nullable=False)
    slug = Column(String(80), nullable=False, unique=True, index=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    users = relationship("UserORM", back_populates="tenant", lazy="noload")
    products = relationship("ProductORM", back_populates="tenant", lazy="noload")


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class UserORM(Base):
    __tablename__ = "users"
    __table_args__ = (
        UniqueConstraint("tenant_id", "username", name="uq_user_tenant_username"),
        UniqueConstraint("tenant_id", "email", name="uq_user_tenant_email"),
        Index("ix_users_tenant_id", "tenant_id"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    username = Column(String(60), nullable=False)
    email = Column(String(255), nullable=False)
    hashed_password = Column(String(255), nullable=False)
    role = Column(SAEnum(UserRole), nullable=False, default=UserRole.OPERATOR)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    tenant = relationship("TenantORM", back_populates="users", lazy="noload")


# ---------------------------------------------------------------------------
# Product
# ---------------------------------------------------------------------------

class ProductORM(Base):
    __tablename__ = "products"
    __table_args__ = (
        UniqueConstraint("tenant_id", "code", name="uq_product_tenant_code"),
        Index("ix_products_tenant_id", "tenant_id"),
        CheckConstraint("min_stock >= 0", name="ck_products_min_stock_non_negative"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(40), nullable=False)
    description = Column(String(255), nullable=False)
    unit = Column(String(20), nullable=False)
    min_stock = Column(Numeric(12, 2, asdecimal=False), default=0.0, nullable=False)
    category = Column(SAEnum(ProductCategory), nullable=True)
    attributes = Column(JSON, nullable=True)  # Flexible: FabricAttributes, FoamAttributes, etc.
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

    tenant = relationship("TenantORM", back_populates="products", lazy="noload")
    stock_balances = relationship("StockBalanceORM", back_populates="product", lazy="noload")
    movements = relationship("StockMovementORM", back_populates="product", lazy="noload")


# ---------------------------------------------------------------------------
# Location & Batch
# ---------------------------------------------------------------------------

class LocationORM(Base):
    __tablename__ = "locations"
    __table_args__ = (Index("ix_locations_tenant_id", "tenant_id"),)

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    corredor = Column(String(40), nullable=False)
    prateleira = Column(String(40), nullable=False)
    nivel = Column(String(20), nullable=True)


class BatchORM(Base):
    __tablename__ = "batches"
    __table_args__ = (
        UniqueConstraint(
            "tenant_id",
            "product_id",
            "batch_number",
            name="uq_batch_tenant_product_number",
        ),
        Index("ix_batches_tenant_product", "tenant_id", "product_id"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    batch_number = Column(String(80), nullable=False)
    validity_date = Column(Date, nullable=True)


# ---------------------------------------------------------------------------
# Stock
# ---------------------------------------------------------------------------

class StockBalanceORM(Base):
    __tablename__ = "stock_balances"
    __table_args__ = (
        UniqueConstraint("tenant_id", "product_id", "batch_id", "location_id", name="uq_balance_key"),
        Index("ix_stock_balance_tenant_product", "tenant_id", "product_id"),
        CheckConstraint("balance >= 0", name="ck_stock_balances_non_negative"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    batch_id = Column(UUID(as_uuid=True), ForeignKey("batches.id"), nullable=True)
    location_id = Column(UUID(as_uuid=True), ForeignKey("locations.id"), nullable=True)
    balance = Column(Numeric(12, 2, asdecimal=False), default=0.0, nullable=False)

    product = relationship("ProductORM", back_populates="stock_balances", lazy="noload")


class StockMovementORM(Base):
    __tablename__ = "stock_movements"
    __table_args__ = (
        Index("ix_movements_tenant_product", "tenant_id", "product_id"),
        Index("ix_movements_created_at", "created_at"),
        Index("ix_movements_tenant_created_at", "tenant_id", "created_at"),
        CheckConstraint("quantity > 0", name="ck_stock_movements_quantity_positive"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)  # Audit trail
    batch_id = Column(UUID(as_uuid=True), ForeignKey("batches.id"), nullable=True)
    location_id = Column(UUID(as_uuid=True), ForeignKey("locations.id"), nullable=True)
    type = Column(SAEnum(MovementType), nullable=False)
    quantity = Column(Numeric(12, 2, asdecimal=False), nullable=False)
    reference_doc = Column(String(120), nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False, index=True)

    product = relationship("ProductORM", back_populates="movements", lazy="noload")


# ---------------------------------------------------------------------------
# Financial
# ---------------------------------------------------------------------------

class ExpenseORM(Base):
    __tablename__ = "expenses"
    __table_args__ = (
        Index("ix_expenses_tenant_date", "tenant_id", "expense_date"),
        Index("ix_expenses_tenant_category_date", "tenant_id", "category", "expense_date"),
        CheckConstraint("value > 0", name="ck_expenses_value_positive"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    value = Column(Numeric(12, 2, asdecimal=False), nullable=False)
    category = Column(SAEnum(ExpenseCategory), nullable=False)
    supplier = Column(String(120), nullable=True)
    description = Column(Text, nullable=True)
    reference_doc = Column(String(120), nullable=True)  # NF number or PDF hash
    expense_date = Column(Date, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class AIAdminTaskORM(Base):
    __tablename__ = "ai_admin_tasks"
    __table_args__ = (
        UniqueConstraint("tenant_id", "task_key", name="uq_ai_admin_task_tenant_key"),
        Index("ix_ai_admin_tasks_tenant_status", "tenant_id", "status"),
        Index("ix_ai_admin_tasks_tenant_due_date", "tenant_id", "due_date"),
        CheckConstraint("priority_score >= 0 AND priority_score <= 100", name="ck_ai_admin_task_priority_range"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    task_type = Column(SAEnum(AIAdminTaskType), nullable=False)
    status = Column(SAEnum(AIAdminTaskStatus), nullable=False, default=AIAdminTaskStatus.SUGGESTED)
    title = Column(String(180), nullable=False)
    description = Column(Text, nullable=False)
    priority_score = Column(Numeric(5, 2, asdecimal=False), nullable=False)
    due_date = Column(DateTime, nullable=True)
    task_key = Column(String(180), nullable=False)
    context_payload = Column(JSON, nullable=True)
    feedback_status = Column(SAEnum(AIAdminFeedbackStatus), nullable=True)
    feedback_note = Column(Text, nullable=True)
    resolved_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    resolved_at = Column(DateTime, nullable=True)
    resolution_time_minutes = Column(Float, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )


class AIAdminProfileORM(Base):
    __tablename__ = "ai_admin_profiles"
    __table_args__ = (
        UniqueConstraint("tenant_id", "user_id", name="uq_ai_admin_profile_tenant_user"),
        Index("ix_ai_admin_profiles_tenant", "tenant_id"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    communication_style = Column(SAEnum(AICommunicationStyle), nullable=False, default=AICommunicationStyle.EXECUTIVE)
    priority_focus = Column(SAEnum(AIPriorityFocus), nullable=False, default=AIPriorityFocus.BALANCED)
    briefing_hour = Column(Numeric(2, 0, asdecimal=False), nullable=False, default=7)
    max_daily_tasks = Column(Numeric(2, 0, asdecimal=False), nullable=False, default=5)
    prefers_whatsapp = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )


class AIAdminBriefingORM(Base):
    __tablename__ = "ai_admin_briefings"
    __table_args__ = (
        Index("ix_ai_admin_briefings_tenant_generated", "tenant_id", "generated_at"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    headline = Column(String(255), nullable=False)
    summary = Column(Text, nullable=False)
    metrics = Column(JSON, nullable=False)
    recommended_task_keys = Column(JSON, nullable=True)
    generated_at = Column(DateTime, default=datetime.utcnow, nullable=False)


class AIProviderConfigORM(Base):
    __tablename__ = "ai_provider_configs"
    __table_args__ = (
        UniqueConstraint("tenant_id", name="uq_ai_provider_config_tenant"),
        Index("ix_ai_provider_configs_active", "tenant_id", "is_active"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    provider = Column(SAEnum(AIProviderType), nullable=False)
    model_name = Column(String(120), nullable=False)
    api_base_url = Column(String(255), nullable=True)
    api_key_encrypted = Column(Text, nullable=True)
    is_active = Column(Boolean, nullable=False, default=True)
    temperature = Column(Numeric(3, 2, asdecimal=False), nullable=False, default=0.2)
    max_tokens = Column(Numeric(5, 0, asdecimal=False), nullable=False, default=1200)
    system_prompt_override = Column(Text, nullable=True)
    updated_by_user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    last_validated_at = Column(DateTime, nullable=True)
    last_validation_status = Column(String(40), nullable=True)
    last_validation_error = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow,
        nullable=False,
    )
