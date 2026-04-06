"""
Consumidores de Eventos de Estoque — Reagem a movimentações em tempo real.
Registrados no EventBus durante o startup da aplicação.
"""
import logging
from typing import Any, Dict
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)


async def on_movement_created(event: Dict[str, Any]):
    """
    Reage a uma nova movimentação de estoque.
    
    Responsabilidades:
    - Verificar se o novo saldo ficou abaixo do mínimo
    - Publicar evento de alerta de ruptura se necessário
    - Registrar métricas de consumo (observability)
    """
    data = event["data"]
    tenant_id = event.get("tenant_id")
    product_code = data.get("product_code")
    new_balance = data.get("new_balance", 0)
    min_stock = data.get("min_stock", 0)
    movement_type = data.get("movement_type")

    logger.info(
        f"[CONSUMER:stock.movement] tenant={tenant_id} | product={product_code} | "
        f"type={movement_type} | balance={new_balance}"
    )

    # Verificar ruptura de estoque
    if new_balance < min_stock:
        logger.warning(
            f"[ALERT:low_stock] tenant={tenant_id} | {product_code} | "
            f"balance={new_balance} < min={min_stock}"
        )
        # Re-publicar evento de alerta (outros consumidores podem reagir)
        from messaging.event_bus import event_bus
        await event_bus.publish(
            topic="stock.low_stock",
            data={
                "product_code": product_code,
                "new_balance": new_balance,
                "min_stock": min_stock,
                "alert_generated_at": datetime.utcnow().isoformat(),
            },
            tenant_id=tenant_id,
        )


async def on_low_stock(event: Dict[str, Any]):
    """
    Reage a alertas de estoque baixo.
    
    Em produção: enviar e-mail, push notification, ou inserir na tabela de alertas.
    """
    data = event["data"]
    tenant_id = event.get("tenant_id")
    product_code = data.get("product_code")
    balance = data.get("new_balance")
    minimum = data.get("min_stock")

    # TODO: integrar com sistema de notificações (e-mail, webhook, etc.)
    logger.critical(
        f"[NOTIFICATION:low_stock] 🚨 ALERTA DE ESTOQUE BAIXO | "
        f"tenant={tenant_id} | produto={product_code} | "
        f"saldo={balance} (mínimo={minimum})"
    )


def register_stock_consumers():
    """Registra todos os handlers de estoque no EventBus global."""
    from messaging.event_bus import event_bus
    event_bus.subscribe("stock.movement.created", on_movement_created)
    event_bus.subscribe("stock.low_stock", on_low_stock)
    logger.info("[CONSUMERS] Stock consumers registered.")
