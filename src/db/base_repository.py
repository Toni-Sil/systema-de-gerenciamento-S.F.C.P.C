from typing import TypeVar, Generic, List, Optional, Type
from uuid import UUID
from pydantic import BaseModel
from auth.tenant_context import get_tenant_id
from fastapi import HTTPException

T = TypeVar("T", bound=BaseModel)

class BaseRepository(Generic[T]):
    """
    Base repository that enforces multi-tenancy by automatically 
    applying tenant_id filters.
    """
    def __init__(self, model: Type[T]):
        self.model = model
        # In a real implementation, this would hold a DB session (SQLAlchemy/Tortoise)
        # For this MVP simulation/boilerplate, we use a mock in-memory storage
        self._storage: List[T] = []

    def _get_current_tenant_id(self) -> UUID:
        tenant_id = get_tenant_id()
        if not tenant_id:
            raise HTTPException(status_code=403, detail="Tenant context missing")
        return tenant_id

    async def create(self, data: T) -> T:
        """Enforces tenant_id on creation."""
        tenant_id = self._get_current_tenant_id()
        # Ensure the data belongs to the current tenant
        if hasattr(data, 'tenant_id') and data.tenant_id != tenant_id:
             raise HTTPException(status_code=403, detail="Tenant ID mismatch")
        
        self._storage.append(data)
        return data

    async def get_all(self) -> List[T]:
        """Automatically filters by tenant_id."""
        tenant_id = self._get_current_tenant_id()
        return [item for item in self._storage if getattr(item, 'tenant_id', None) == tenant_id]

    async def get_by_id(self, id: UUID) -> Optional[T]:
        """Ensures the item belongs to the tenant."""
        tenant_id = self._get_current_tenant_id()
        for item in self._storage:
            if getattr(item, 'id', None) == id and getattr(item, 'tenant_id', None) == tenant_id:
                return item
        return None
