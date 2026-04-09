from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.ext.asyncio import AsyncSession
from db.session import get_session
from typing import Optional
import logging
import json
from uuid import UUID

from db.orm_models import TenantSettingsORM, PendingActionORM
from sqlalchemy import select

router = APIRouter(prefix="/api/v1/webhooks", tags=["Webhooks"])
logger = logging.getLogger(__name__)

@router.post("/external-os")
async def external_os_webhook(
    request: Request,
    x_api_key: Optional[str] = Header(None),
    db: AsyncSession = Depends(get_session)
):
    """
    Recebe atualizações de status do sistema de Ordem de Serviço externo.
    Se uma OS for finalizada, sugere a baixa de materiais no estoque via Governança.
    """
    payload = await request.json()
    logger.info(f"Webhook received from External OS: {payload}")

    # 1. Validar segurança (O webhook deve enviar a chave configurada no tenant)
    # Como o webhook pode vir de múltiplos tenants, precisamos identificar qual tenant é dono desta chave
    result = await db.execute(
        select(TenantSettingsORM).where(TenantSettingsORM.service_order_api_key == x_api_key)
    )
    settings = result.scalar_one_or_none()
    
    if not settings:
        logger.warning(f"Webhook rejected: Invalid API Key {x_api_key}")
        raise HTTPException(status_code=401, detail="Invalid integration key")

    tenant_id = settings.tenant_id
    event_type = payload.get("event") # ex: "order.status_changed"
    order_data = payload.get("order", {})
    new_status = order_data.get("status")

    # 2. Lógica de Negócio: Se a OS foi FINALIZADA, sugerir consumo de estoque
    if event_type == "order.status_changed" and new_status == "FINISHED":
        description = order_data.get("description", "")
        fabric = order_data.get("fabric", "")
        
        # Criar uma ação pendente na Governança para o gestor aprovar a baixa de materiais
        # A IA pode ser usada aqui para "adivinhar" quais materiais foram usados, 
        # mas por enquanto vamos sugerir baseado no que veio no payload.
        
        proposed_params = {
            "order_id": order_data.get("id"),
            "suggestion": f"Baixa de estoque referente à OS {order_data.get('id')} finalizada.",
            "items_to_check": [fabric] if fabric else []
        }

        new_action = PendingActionORM(
            tenant_id=tenant_id,
            action_type="MaterialUsageSuggestion",
            raw_message=f"OS {order_data.get('id')} foi finalizada no sistema externo. Descrição: {description}",
            proposed_params=proposed_params,
            risk_level="medium",
            risk_reason="Auto-sugestão baseada em evento externo de conclusão de serviço.",
            status="pending"
        )
        db.add(new_action)
        await db.commit()
        logger.info(f"Governance action created for OS {order_data.get('id')}")

    return {"status": "received"}
