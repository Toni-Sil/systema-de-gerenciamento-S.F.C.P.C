"""SQLAlchemy ORM models mapped to the PostgreSQL schema.

Naming conventions:
  - Tables use snake_case plural (products, movements, expenses).
  - All tenant-scoped tables carry an indexed `tenant_id` column.
  - `created_at` is always server-side UTC to avoid client clock skew.
"""
from datetime import datetime, date
from uuid import uuid4
from typing import Optional

from sqlalchemy import (
    Boolean, Column, Date, DateTime, Enum, Float,
    ForeignKey, Index, String, Text, func,
)
from sqlalchemy.dialects.postgresql import UUID as PGUUID, JSONB
from sqlalchemy.orm import relationship

from db.session import Base
from models.entities import MovementType, ProductCategory, UserRole, ExpenseCategory


# ---------------------------------------------------------------------------
# Tenant
# ---------------------------------------------------------------------------

class TenantORM(Base):
    __tablename__ = "tenants"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    name = Column(String(120), nullable=False)
    slug = Column(String(80), unique=True, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    users = relationship("UserORM", back_populates="tenant", cascade="all, delete-orphan")
    products = relationship("ProductORM", back_populates="tenant", cascade="all, delete-orphan")


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class UserORM(Base):
    __tablename__ = "users"
    __table_args__ = (
        Index("ix_users_tenant_username", "tenant_id", "username", unique=True),
        Index("ix_users_tenant_email", "tenant_id", "email", unique=True),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    username = Column(String(60), nullable=False)
    email = Column(String(255), nullable=False)
    role = Column(Enum(UserRole), nullable=False, default=UserRole.OPERATOR)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    tenant = relationship("TenantORM", back_populates="users")


# ---------------------------------------------------------------------------
# Product
# ---------------------------------------------------------------------------

class ProductORM(Base):
    __tablename__ = "products"
    __table_args__ = (
        Index("ix_products_tenant_code", "tenant_id", "code", unique=True),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    code = Column(String(40), nullable=False)
    description = Column(String(255), nullable=False)
    unit = Column(String(20), nullable=False)
    min_stock = Column(Float, nullable=False, default=0.0)
    category = Column(Enum(ProductCategory), nullable=True)
    # Flexible attributes stored as JSONB for query efficiency (e.g. fabric tonality, foam density)
    attributes = Column(JSONB, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)

    tenant = relationship("TenantORM", back_populates="products")
    batches = relationship("BatchORM", back_populates="product", cascade="all, delete-orphan")
    movements = relationship("MovementORM", back_populates="product")


# ---------------------------------------------------------------------------
# Location
# ---------------------------------------------------------------------------

class LocationORM(Base):
    __tablename__ = "locations"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    corredor = Column(String(20), nullable=False)
    prateleira = Column(String(20), nullable=False)
    nivel = Column(String(20), nullable=True)


# ---------------------------------------------------------------------------
# Batch
# ---------------------------------------------------------------------------

class BatchORM(Base):
    __tablename__ = "batches"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(PGUUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    batch_number = Column(String(80), nullable=False)
    validity_date = Column(Date, nullable=True)

    product = relationship("ProductORM", back_populates="batches")


# ---------------------------------------------------------------------------
# Stock Balance
# ---------------------------------------------------------------------------

class StockBalanceORM(Base):
    __tablename__ = "stock_balances"
    __table_args__ = (
        # Unique balance per (tenant, product, batch, location) combination
        Index("ix_balance_unique", "tenant_id", "product_id", "batch_id", "location_id", unique=True),
    )

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(PGUUID(as_uuid=True), ForeignKey("products.id", ondelete="CASCADE"), nullable=False)
    batch_id = Column(PGUUID(as_uuid=True), ForeignKey("batches.id", ondelete="SET NULL"), nullable=True)
    location_id = Column(PGUUID(as_uuid=True), ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    balance = Column(Float, nullable=False, default=0.0)


# ---------------------------------------------------------------------------
# Movement  (append-only ledger)
# ---------------------------------------------------------------------------

class MovementORM(Base):
    __tablename__ = "movements"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    product_id = Column(PGUUID(as_uuid=True), ForeignKey("products.id", ondelete="RESTRICT"), nullable=False)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)  # Audit trail
    batch_id = Column(PGUUID(as_uuid=True), ForeignKey("batches.id", ondelete="SET NULL"), nullable=True)
    location_id = Column(PGUUID(as_uuid=True), ForeignKey("locations.id", ondelete="SET NULL"), nullable=True)
    type = Column(Enum(MovementType), nullable=False)
    quantity = Column(Float, nullable=False)
    unit_value = Column(Float, nullable=True, default=0.0)  # Unit cost/price for financial summary
    reference_doc = Column(String(120), nullable=True)       # NF number or external reference
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False, index=True)

    product = relationship("ProductORM", back_populates="movements")


# ---------------------------------------------------------------------------
# Expense  (financial module)
# ---------------------------------------------------------------------------

class ExpenseORM(Base):
    __tablename__ = "expenses"

    id = Column(PGUUID(as_uuid=True), primary_key=True, default=uuid4)
    tenant_id = Column(PGUUID(as_uuid=True), ForeignKey("tenants.id", ondelete="CASCADE"), nullable=False, index=True)
    user_id = Column(PGUUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    value = Column(Float, nullable=False)
    category = Column(Enum(ExpenseCategory), nullable=False)
    supplier = Column(String(200), nullable=True)
    description = Column(Text, nullable=True)
    reference_doc = Column(String(120), nullable=True)  # NF hash / PDF reference (LGPD: no raw doc stored)
    expense_date = Column(Date, nullable=False, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now(), nullable=False)
