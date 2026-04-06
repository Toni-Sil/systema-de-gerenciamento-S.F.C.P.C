from contextvars import ContextVar
from uuid import UUID
from typing import Optional

# Context variable to store the tenant_id for the current request
_tenant_id_ctx: ContextVar[Optional[UUID]] = ContextVar("tenant_id", default=None)

def set_tenant_id(tenant_id: UUID) -> None:
    """Sets the tenant_id for the current request context."""
    _tenant_id_ctx.set(tenant_id)

from fastapi import HTTPException

def get_tenant_id() -> Optional[UUID]:
    """Gets the tenant_id from the current request context."""
    return _tenant_id_ctx.get()

def get_validated_tenant_id() -> UUID:
    """Retorna o tenant_id do contexto ou lança 403 se ausente."""
    tenant_id = get_tenant_id()
    if not tenant_id:
        raise HTTPException(status_code=403, detail="Tenant context missing")
    return tenant_id
