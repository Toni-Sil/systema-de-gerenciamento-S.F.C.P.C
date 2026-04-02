"""Motor de Governança para ações autônomas do Agente IA.

Implementa Human-in-the-Loop para decisões sensíveis e detecção
de padrões anômalos que possam indicar fraude ou erro operacional.
"""
from datetime import datetime, time
from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)


class GovernanceRules:

    # Limites configuráveis
    HIGH_VALUE_THRESHOLD = 5_000.0       # R$ para despesas autônomas
    BULK_EXIT_THRESHOLD = 1_000.0        # unidades para saída em massa
    BULK_ENTRY_THRESHOLD = 5_000.0       # unidades para entrada em massa
    WORK_HOURS_START = time(6, 0)        # início do expediente
    WORK_HOURS_END = time(22, 0)         # fim do expediente
    MAX_AUTONOMOUS_ACTIONS_PER_SESSION = 50

    # Contador simples de ações por sessão (tenant_id -> count)
    _action_counter: Dict[str, int] = {}

    @classmethod
    def evaluate_action(cls, intent: Dict[str, Any]) -> Dict[str, Any]:
        """
        Avalia se a intenção possui riscos que exigem intervenção humana.
        Aplica todas as regras em sequência; para na primeira violação.
        """
        action = intent.get("action")
        params = intent.get("params", {}) or {}
        tenant_id = str(intent.get("tenant_id", "unknown"))

        # --- Regra 1: Despesa de Alto Valor ---
        if action == "RegisterExpense":
            value = params.get("value", 0.0)
            if value >= cls.HIGH_VALUE_THRESHOLD:
                return cls._block(
                    intent,
                    f"Despesa de alto valor (R$ {value:,.2f}) acima do limite autônomo de R$ {cls.HIGH_VALUE_THRESHOLD:,.2f}. Aguardando aprovação do gestor.",
                    rule="HIGH_VALUE_EXPENSE",
                )

        # --- Regra 2: Saída em Massa ---
        elif action == "Exit":
            qty = params.get("quantity", 0)
            if qty >= cls.BULK_EXIT_THRESHOLD:
                return cls._block(
                    intent,
                    f"Saída atípica de {qty} unidades. Suspeita de fraude ou erro operacional.",
                    rule="BULK_EXIT",
                )

        # --- Regra 3: Entrada em Massa ---
        elif action == "Entry":
            qty = params.get("quantity", 0)
            if qty >= cls.BULK_ENTRY_THRESHOLD:
                return cls._block(
                    intent,
                    f"Entrada atípica de {qty} unidades. Requer confirmação do gestor.",
                    rule="BULK_ENTRY",
                )

        # --- Regra 4: Ajuste direto de estoque (sempre exige aprovação) ---
        elif action == "Adjustment":
            return cls._block(
                intent,
                "Ajuste direto de saldo requer aprovação obrigatória do MANAGER ou ADMIN.",
                rule="MANDATORY_ADJUSTMENT_APPROVAL",
            )

        # --- Regra 5: Operação fora do horário de expediente ---
        now_time = datetime.now().time()
        if not (cls.WORK_HOURS_START <= now_time <= cls.WORK_HOURS_END):
            logger.warning(
                f"[GOVERNANÇA] Ação '{action}' fora do expediente ({now_time.strftime('%H:%M')}) — tenant={tenant_id}"
            )
            intent["warning"] = f"Ação executada fora do horário de expediente ({now_time.strftime('%H:%M')}). Registrado para auditoria."

        # --- Regra 6: Limite de ações autônomas por sessão ---
        cls._action_counter[tenant_id] = cls._action_counter.get(tenant_id, 0) + 1
        if cls._action_counter[tenant_id] > cls.MAX_AUTONOMOUS_ACTIONS_PER_SESSION:
            return cls._block(
                intent,
                f"Limite de {cls.MAX_AUTONOMOUS_ACTIONS_PER_SESSION} ações autônomas por sessão atingido. Sessão encerrada por segurança.",
                rule="SESSION_LIMIT_EXCEEDED",
            )

        return intent

    @classmethod
    def _block(cls, intent: Dict[str, Any], motivo: str, rule: str) -> Dict[str, Any]:
        """Marca a intenção como bloqueada e loga o evento."""
        logger.warning(f"[GOVERNANÇA] Bloqueado — rule={rule} | {motivo}")
        intent["status"] = "needs_approval"
        intent["motivo"] = motivo
        intent["governance_rule"] = rule
        return intent

    @classmethod
    def reset_session_counter(cls, tenant_id: str) -> None:
        """Reseta o contador de ações (chamar no logout/início de sessão)."""
        cls._action_counter.pop(tenant_id, None)
