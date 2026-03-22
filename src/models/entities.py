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


class AIAdminTaskStatus(str, Enum):
    SUGGESTED = "suggested"
    PENDING_APPROVAL = "pending_approval"
    APPROVED = "approved"
    EXECUTED = "executed"
    DISMISSED = "dismissed"


class AIAdminTaskType(str, Enum):
    REPLENISHMENT = "replenishment"
    AUDIT = "audit"
    FOLLOW_UP = "follow_up"
    BRIEFING = "briefing"


class AIAdminFeedbackStatus(str, Enum):
    USEFUL = "useful"
    IRRELEVANT = "irrelevant"
    INCORRECT = "incorrect"
    AUTOMATED = "automated"


class AICommunicationStyle(str, Enum):
    EXECUTIVE = "executive"
    DETAILED = "detailed"


class AIPriorityFocus(str, Enum):
    RUPTURE = "rupture"
    COST = "cost"
    BALANCED = "balanced"


class AIProviderType(str, Enum):
    OPENAI = "openai"
    ANTHROPIC = "anthropic"
    AZURE_OPENAI = "azure_openai"
    LOCAL = "local"


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


class ChatInputSchema(BaseSchema):
    message: str = Field(..., min_length=1)


class AIAdminTaskSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    task_type: AIAdminTaskType
    status: AIAdminTaskStatus = AIAdminTaskStatus.SUGGESTED
    title: str
    description: str
    priority_score: float = Field(..., ge=0.0, le=100.0)
    due_date: Optional[datetime] = None
    task_key: str
    context_payload: Optional[dict[str, Any]] = None
    feedback_status: Optional[AIAdminFeedbackStatus] = None
    feedback_note: Optional[str] = None
    resolved_by_user_id: Optional[UUID] = None
    resolved_at: Optional[datetime] = None
    resolution_time_minutes: Optional[int] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AIAdminBriefingSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    generated_at: datetime = Field(default_factory=datetime.utcnow)
    headline: str
    summary: str
    metrics: dict[str, Any]
    recommended_tasks: list[AIAdminTaskSchema] = Field(default_factory=list)


class AIAdminProfileSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    user_id: Optional[UUID] = None
    communication_style: AICommunicationStyle = AICommunicationStyle.EXECUTIVE
    priority_focus: AIPriorityFocus = AIPriorityFocus.BALANCED
    briefing_hour: int = Field(default=7, ge=0, le=23)
    max_daily_tasks: int = Field(default=5, ge=1, le=20)
    prefers_whatsapp: bool = True
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AIProviderConfigSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    provider: AIProviderType
    model_name: str
    api_base_url: Optional[str] = None
    api_key_masked: Optional[str] = None
    is_active: bool = True
    temperature: float = Field(default=0.2, ge=0.0, le=2.0)
    max_tokens: int = Field(default=1200, ge=128, le=32000)
    system_prompt_override: Optional[str] = None
    updated_by_user_id: Optional[UUID] = None
    last_validated_at: Optional[datetime] = None
    last_validation_status: Optional[str] = None
    last_validation_error: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class AIProviderConfigUpsertSchema(BaseSchema):
    provider: AIProviderType
    model_name: str = Field(..., min_length=2, max_length=120)
    api_base_url: Optional[str] = Field(default=None, max_length=255)
    api_key: Optional[str] = Field(default=None, min_length=8, max_length=255)
    is_active: bool = True
    temperature: float = Field(default=0.2, ge=0.0, le=2.0)
    max_tokens: int = Field(default=1200, ge=128, le=32000)
    system_prompt_override: Optional[str] = Field(default=None, max_length=4000)
