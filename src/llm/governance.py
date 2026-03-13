from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

class GovernanceRules:
    """
    Motor de Governança para ações autônomas do Agente IA.
    Implementa o "Human-in-the-Loop" (Aprovação Manual) para decisões sensíveis.
    """
    
    HIGH_VALUE_THRESHOLD = 5000.0  # R$ 5.000,00

    @classmethod
    def evaluate_action(cls, intent: Dict[str, Any]) -> Dict[str, Any]:
        """
        Avalia se a intenção parseada pela IA possui riscos que exigem intervenção humana.
        """
        action = intent.get("action")
        params = intent.get("params", {})
        
        if action == "RegisterExpense":
            value = params.get("value", 0.0)
            if value >= cls.HIGH_VALUE_THRESHOLD:
                logger.warning(f" [GOVERNANÇA] Ação Bloqueada: Despesa de Alto Valor (R$ {value}). Exigindo aprovação Humana.")
                intent["status"] = "needs_approval"
                intent["motivo"] = "Ação bloqueada pelas políticas de Governança corporativa (Valor Superior ao Limite Autônomo)."
                
        elif action == "Exit":
            # Example: Exiting more than 1000 units of anything requires manager approval
            qty = params.get("quantity", 0)
            if qty >= 1000:
                logger.warning(f" [GOVERNANÇA] Ação Bloqueada: Movimentação Atípica (Qtd {qty}). Exigindo aprovação Humana.")
                intent["status"] = "needs_approval"
                intent["motivo"] = "Detecção de fraude ou movimentação atípica em massa."
                
        return intent
