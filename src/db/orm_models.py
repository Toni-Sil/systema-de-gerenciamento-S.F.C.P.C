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
    Float, ForeignKey, Index, String, Text, UniqueConstraint
)
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import relationship

from db.session import Base
from models.entities import MovementType, ProductCategory, UserRole, ExpenseCategory


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
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    code = Column(String(40), nullable=False)
    description = Column(String(255), nullable=False)
    unit = Column(String(20), nullable=False)
    min_stock = Column(Float, default=0.0, nullable=False)
    category = Column(SAEnum(ProductCategory), nullable=True)
    attributes = Column(JSONB, nullable=True)  # Flexible: FabricAttributes, FoamAttributes, etc.
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
    __table_args__ = (Index("ix_batches_tenant_product", "tenant_id", "product_id"),)

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
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    batch_id = Column(UUID(as_uuid=True), ForeignKey("batches.id"), nullable=True)
    location_id = Column(UUID(as_uuid=True), ForeignKey("locations.id"), nullable=True)
    balance = Column(Float, default=0.0, nullable=False)

    product = relationship("ProductORM", back_populates="stock_balances", lazy="noload")


class StockMovementORM(Base):
    __tablename__ = "stock_movements"
    __table_args__ = (
        Index("ix_movements_tenant_product", "tenant_id", "product_id"),
        Index("ix_movements_created_at", "created_at"),
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)  # Audit trail
    batch_id = Column(UUID(as_uuid=True), ForeignKey("batches.id"), nullable=True)
    location_id = Column(UUID(as_uuid=True), ForeignKey("locations.id"), nullable=True)
    type = Column(SAEnum(MovementType), nullable=False)
    quantity = Column(Float, nullable=False)
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
    )

    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(UUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(UUID(as_uuid=True), ForeignKey("users.id"), nullable=True)
    value = Column(Float, nullable=False)
    category = Column(SAEnum(ExpenseCategory), nullable=False)
    supplier = Column(String(120), nullable=True)
    description = Column(Text, nullable=True)
    reference_doc = Column(String(120), nullable=True)  # NF number or PDF hash
    expense_date = Column(Date, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
