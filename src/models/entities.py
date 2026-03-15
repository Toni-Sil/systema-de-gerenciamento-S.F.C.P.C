from datetime import datetime, date
from typing import Optional, List, Any
from uuid import UUID, uuid4
from pydantic import BaseModel, Field, ConfigDict, field_validator
from enum import Enum
import re


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class MovementType(str, Enum):
    ENTRY = "ENTRY"
    EXIT = "EXIT"
    TRANSFER = "TRANSFER"
    ADJUSTMENT = "ADJUSTMENT"


class ProductCategory(str, Enum):
    FABRIC = "TECIDOS"
    FOAM = "ESPUMAS"
    WOOD = "MADEIRAS"
    HARDWARE = "FERRAGENS"


class UserRole(str, Enum):
    ADMIN = "admin"
    MANAGER = "manager"
    OPERATOR = "operator"
    AUDITOR = "auditor"


class ExpenseCategory(str, Enum):
    RAW_MATERIAL = "Matéria Prima"
    LOGISTICS = "Logística"
    LABOR = "Mão de Obra"
    OVERHEAD = "Overhead"
    OTHER = "Outros"


# ---------------------------------------------------------------------------
# Domain attribute models
# ---------------------------------------------------------------------------

class FabricAttributes(BaseModel):
    tonalidade: Optional[str] = None
    metragem: Optional[float] = None
    gramatura: Optional[float] = None


class FoamAttributes(BaseModel):
    densidade: Optional[str] = None  # Ex: D23, D28, D33
    dimensoes_cm: Optional[str] = None


class ProductAttributes(BaseModel):
    tecido: Optional[FabricAttributes] = None
    espuma: Optional[FoamAttributes] = None
    outros: Optional[dict] = None


# ---------------------------------------------------------------------------
# Base
# ---------------------------------------------------------------------------

class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# ---------------------------------------------------------------------------
# Tenant
# ---------------------------------------------------------------------------

class TenantSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    name: str = Field(..., min_length=2, max_length=120)
    slug: str = Field(..., pattern=r"^[a-z0-9\-]+$")
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# User
# ---------------------------------------------------------------------------

class UserCreateSchema(BaseSchema):
    """Input model for creating a user — accepts plain-text password."""
    tenant_id: UUID
    username: str = Field(..., min_length=3, max_length=60)
    email: str
    role: UserRole = UserRole.OPERATOR
    plain_password: str = Field(..., min_length=8)

    @field_validator("email")
    @classmethod
    def email_must_be_valid(cls, v: str) -> str:
        if not re.match(r"^[\w.+-]+@[\w-]+\.[\w.]+$", v):
            raise ValueError("Invalid e-mail address")
        return v.lower()


class UserSchema(BaseSchema):
    """Persisted user model — stores hashed password only."""
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    username: str
    email: str
    role: UserRole = UserRole.OPERATOR
    hashed_password: str
    is_active: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Product
# ---------------------------------------------------------------------------

class ProductSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    code: str = Field(..., min_length=1, max_length=40)
    description: str = Field(..., min_length=1, max_length=255)
    unit: str = Field(..., min_length=1, max_length=20)
    min_stock: float = Field(default=0.0, ge=0.0)
    category: Optional[ProductCategory] = None
    attributes: Optional[ProductAttributes] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Location & Batch
# ---------------------------------------------------------------------------

class LocationDetailSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    corredor: str
    prateleira: str
    nivel: Optional[str] = None


class BatchSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    product_id: UUID
    batch_number: str
    validity_date: Optional[date] = None


# ---------------------------------------------------------------------------
# Stock
# ---------------------------------------------------------------------------

class StockBalanceSchema(BaseSchema):
    tenant_id: UUID
    product_id: UUID
    batch_id: Optional[UUID] = None
    location_id: Optional[UUID] = None
    balance: float = Field(default=0.0, ge=0.0)


class MovementSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    product_id: UUID
    user_id: Optional[UUID] = None  # Audit trail: who triggered the movement
    batch_id: Optional[UUID] = None
    location_id: Optional[UUID] = None
    type: MovementType
    quantity: float = Field(..., gt=0.0)  # Quantity must always be positive
    reference_doc: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)


# ---------------------------------------------------------------------------
# Financial module (Fase 1 antecipada)
# ---------------------------------------------------------------------------

class ExpenseSchema(BaseSchema):
    """Records a financial expense extracted from OCR or entered manually."""
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    user_id: Optional[UUID] = None
    value: float = Field(..., gt=0.0)
    category: ExpenseCategory
    supplier: Optional[str] = None
    description: Optional[str] = None
    reference_doc: Optional[str] = None  # NF number or PDF hash
    expense_date: date
    created_at: datetime = Field(default_factory=datetime.utcnow)


class FinancialSummarySchema(BaseSchema):
    """Aggregated financial snapshot (Gold Layer output)."""
    tenant_id: UUID
    period_start: date
    period_end: date
    total_expenses: float
    expenses_by_category: dict[str, float]
    total_entries_value: float
    total_exits_value: float
    gross_margin: float  # = total_exits_value - total_expenses
