from contextvars import ContextVar
from uuid import UUID
from typing import Optional

# Context variable to store the tenant_id for the current request
_tenant_id_ctx: ContextVar[Optional[UUID]] = ContextVar("tenant_id", default=None)

def set_tenant_id(tenant_id: UUID) -> None:
    """Sets the tenant_id for the current request context."""
    _tenant_id_ctx.set(tenant_id)

def get_tenant_id() -> Optional[UUID]:
    """Gets the tenant_id from the current request context."""
    return _tenant_id_ctx.get()
