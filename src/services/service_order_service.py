import httpx
import logging
from typing import Optional, Dict, Any
from uuid import UUID
from sqlalchemy import select
from db.orm_models import TenantSettingsORM

logger = logging.getLogger(__name__)

class ServiceOrderService:
    """Consome a API do sistema externo 'sistema-de-ordem-de-servi-o'."""

    @staticmethod
    async def _get_credentials(tenant_id: UUID, session: Any) -> tuple[Optional[str], Optional[str]]:
        result = await session.execute(
            select(TenantSettingsORM).where(TenantSettingsORM.tenant_id == tenant_id)
        )
        settings = result.scalar_one_or_none()
        if not settings or not settings.service_order_url or not settings.service_order_api_key:
            return None, None
        return settings.service_order_url.rstrip("/"), settings.service_order_api_key

    @staticmethod
    async def create_client(
        tenant_id: UUID,
        session: Any,
        name: str,
        phone: str,
        email: Optional[str] = None,
        address: Optional[str] = None
    ) -> Dict[str, Any]:
        """Cria um cliente no sistema externo."""
        base_url, api_key = await ServiceOrderService._get_credentials(tenant_id, session)
        if not base_url:
            return {"status": "error", "message": "Configurações de integração OS pendentes."}

        url = f"{base_url}/api/v1/clients"
        headers = {"x-api-key": api_key, "Content-Type": "application/json"}
        payload = {
            "name": name,
            "phone": phone,
            "email": email or "",
            "address": address or ""
        }

        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.post(url, json=payload, headers=headers)
                resp.raise_for_status()
                return {"status": "success", "data": resp.json()}
            except Exception as e:
                logger.error(f"Error creating client in external OS: {e}")
                return {"status": "error", "message": str(e)}

    @staticmethod
    async def create_order(
        tenant_id: UUID,
        session: Any,
        client_id: str,
        description: str,
        priority: str = "normal",
        furniture_type: str = "sofa",
        fabric: Optional[str] = None
    ) -> Dict[str, Any]:
        """Cria uma ordem de serviço no sistema externo."""
        base_url, api_key = await ServiceOrderService._get_credentials(tenant_id, session)
        if not base_url:
            return {"status": "error", "message": "Configurações de integração OS pendentes."}

        url = f"{base_url}/api/v1/orders"
        headers = {"x-api-key": api_key, "Content-Type": "application/json"}
        payload = {
            "client_id": client_id,
            "description": description,
            "priority": priority,
            "furnitureType": furniture_type,
            "fabric": fabric or ""
        }

        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                resp = await client.post(url, json=payload, headers=headers)
                resp.raise_for_status()
                return {"status": "success", "data": resp.json()}
            except Exception as e:
                logger.error(f"Error creating order in external OS: {e}")
                return {"status": "error", "message": str(e)}
