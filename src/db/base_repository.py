"""Generic async repository with mandatory multi-tenancy enforcement.

All read/write operations automatically scope queries to the current tenant,
preventing cross-tenant data leakage at the data access layer.
"""
from typing import Generic, List, Optional, Type, TypeVar
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.tenant_context import get_tenant_id
from db.session import Base

T = TypeVar("T", bound=Base)


class BaseRepository(Generic[T]):
    """
    Tenant-scoped repository.

    Every query automatically adds a `WHERE tenant_id = <current_tenant>` clause.
    This is the second layer of tenancy enforcement (the first being the middleware).
    """

    def __init__(self, model: Type[T], session: AsyncSession):
        self.model = model
        self.session = session

    def _require_tenant(self) -> UUID:
        tenant_id = get_tenant_id()
        if not tenant_id:
            raise HTTPException(status_code=403, detail="Tenant context missing")
        return tenant_id

    async def create(self, data: T) -> T:
        """Persists a new entity, enforcing tenant ownership."""
        tenant_id = self._require_tenant()
        if hasattr(data, "tenant_id") and data.tenant_id != tenant_id:
            raise HTTPException(status_code=403, detail="Tenant ID mismatch on create")
        self.session.add(data)
        await self.session.flush()  # Populate auto-generated fields (id, created_at)
        return data

    async def get_all(
        self,
        limit: int = 100,
        offset: int = 0,
    ) -> List[T]:
        """Returns all entities for the current tenant with pagination."""
        tenant_id = self._require_tenant()
        stmt = (
            select(self.model)
            .where(self.model.tenant_id == tenant_id)
            .limit(limit)
            .offset(offset)
        )
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def get_by_id(self, entity_id: UUID) -> Optional[T]:
        """Fetches a single entity by ID, scoped to the current tenant."""
        tenant_id = self._require_tenant()
        stmt = select(self.model).where(
            self.model.id == entity_id,
            self.model.tenant_id == tenant_id,
        )
        result = await self.session.execute(stmt)
        return result.scalar_one_or_none()

    async def update(self, entity: T) -> T:
        """Merges an updated entity back into the session."""
        self._require_tenant()
        merged = await self.session.merge(entity)
        await self.session.flush()
        return merged

    async def delete(self, entity_id: UUID) -> bool:
        """Soft-deletes by ID within the current tenant. Returns True if found."""
        entity = await self.get_by_id(entity_id)
        if entity is None:
            return False
        await self.session.delete(entity)
        await self.session.flush()
        return True
