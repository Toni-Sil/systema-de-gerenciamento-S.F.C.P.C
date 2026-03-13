from datetime import datetime, date
from typing import Optional, List
from uuid import UUID, uuid4
from pydantic import BaseModel, Field, ConfigDict
from enum import Enum

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

class FabricAttributes(BaseModel):
    tonalidade: Optional[str] = None
    metragem: Optional[float] = None
    gramatura: Optional[float] = None

class FoamAttributes(BaseModel):
    densidade: Optional[str] = None # Ex: D23, D28, D33
    dimensoes_cm: Optional[str] = None

class ProductAttributes(BaseModel):
    tecido: Optional[FabricAttributes] = None
    espuma: Optional[FoamAttributes] = None
    outros: Optional[dict] = None

class BaseSchema(BaseModel):
    model_config = ConfigDict(from_attributes=True)

class TenantSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    name: str
    slug: str
    created_at: datetime = Field(default_factory=datetime.now)

class ProductSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    code: str
    description: str
    unit: str
    min_stock: float = 0.0
    category: Optional[ProductCategory] = None
    attributes: Optional[ProductAttributes] = None
    created_at: datetime = Field(default_factory=datetime.now)

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

class StockBalanceSchema(BaseSchema):
    tenant_id: UUID
    product_id: UUID
    batch_id: Optional[UUID] = None
    location_id: Optional[UUID] = None
    balance: float

class MovementSchema(BaseSchema):
    id: UUID = Field(default_factory=uuid4)
    tenant_id: UUID
    product_id: UUID
    batch_id: Optional[UUID] = None
    location_id: Optional[UUID] = None
    type: MovementType
    quantity: float
    reference_doc: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.now)
