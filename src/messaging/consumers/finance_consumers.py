"""
Consumidores de Eventos Financeiros — Reagem a despesas registradas.
"""
import logging
from typing import Any, Dict

logger = logging.getLogger(__name__)


async def on_expense_created(event: Dict[str, Any]):
    """
    Reage à criação de uma nova despesa (ex: NF processada por OCR).
    
    Responsabilidades:
    - Verificar se o valor supera limites mensais
    - Disparar alerta de anomalia financeira caso necessário
    - Atualizar métricas de observabilidade
    """
    data = event["data"]
    tenant_id = event.get("tenant_id")
    value = data.get("value", 0)
    supplier = data.get("supplier", "Desconhecido")
    MONTHLY_ALERT_THRESHOLD = 5000.0  # R$ 5.000 (Consistent with Governance)

    logger.info(
        f"[CONSUMER:finance.expense] tenant={tenant_id} | "
        f"supplier={supplier} | value=R${value:.2f}"
    )

    if value > MONTHLY_ALERT_THRESHOLD:
        logger.warning(
            f"[ALERT:finance.high_value] 🚨 Despesa elevada detectada | "
            f"tenant={tenant_id} | supplier={supplier} | R${value:.2f} > limite R${MONTHLY_ALERT_THRESHOLD:.2f}"
        )
        from messaging.event_bus import event_bus
        await event_bus.publish(
            topic="governance.action.pending",
            data={
                "action_type": "HighValueExpense",
                "details": f"Despesa de R$ {value:.2f} com {supplier} acima do limite configurado.",
                "value": value,
                "supplier": supplier,
            },
            tenant_id=tenant_id,
        )


async def on_governance_action_pending(event: Dict[str, Any]):
    """
    Centraliza notificações de ações pendentes de governança.
    Em produção: enviar para sistema de tickets, e-mail de gestor, etc.
    """
    data = event["data"]
    tenant_id = event.get("tenant_id")
    action_type = data.get("action_type")
    details = data.get("details")

    logger.critical(
        f"[GOVERNANCE EVENT] 🔒 Ação pendente de aprovação | "
        f"tenant={tenant_id} | type={action_type} | {details}"
    )


def register_finance_consumers():
    """Registra todos os handlers financeiros no EventBus global."""
    from messaging.event_bus import event_bus
    event_bus.subscribe("finance.expense.created", on_expense_created)
    event_bus.subscribe("governance.action.pending", on_governance_action_pending)
    logger.info("[CONSUMERS] Finance consumers registered.")
