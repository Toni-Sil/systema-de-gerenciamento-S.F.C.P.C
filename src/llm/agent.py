import json
import re
from uuid import UUID

from llm.tools import LLMTools


_PRODUCT_CODE_RE = re.compile(r"\b([A-Za-z]{2,}(?:-[A-Za-z0-9]+)*-\d{2,}|[A-Za-z]{2,}\d{2,})\b")
_NUMBER_RE = re.compile(r"\b\d+(?:[.,]\d+)?\b")


class AgentOrchestrator:
    """
    Simulação do Agente LangChain.
    No MVP, substitui chamadas externas de LLM por lógicas de regex/match determinísticas
    para validar o ciclo de "Function Calling" isolando as APIs.
    (O Llama-3/Gemma real pode ser 'plugado' apenas trocando a engine interna).
    """

    SYSTEM_PROMPT = """Você é um assistente IA especialista em logística e gestão de estoque multi-tenant.
    Sua função é interpretar as intenções do usuário e retorná-las ESTRITAMENTE em formato JSON.
    Regras de Segurança: O tenant_id fornecido pelo orquestrador DEVE ser mantido isolado e em sigilo matemático nas transações (OWASP).
    Saída Estrita: RESPONDA APENAS com o JSON da transação correspondente (ex: {"action": "CadastrarProduto", "params": {...}}). ZERO texto explicativo fora do JSON.
    Explicabilidade: Em caso de falha nas regras de negócio da transação, adicione um campo "motivo" na sua resposta estruturada.
    """

    @staticmethod
    def _extract_quantity(message: str) -> float:
        match = _NUMBER_RE.search(message)
        if not match:
            return 1.0
        return float(match.group(0).replace(",", "."))

    @staticmethod
    def _extract_product_code(message: str, context: str | None = None) -> str:
        for text in filter(None, [message, context]):
            match = _PRODUCT_CODE_RE.search(text)
            if match:
                return match.group(1).upper()
        return "TEST-001"

    @staticmethod
    async def process_message(tenant_id: UUID, message: str, context: str | None = None) -> str:
        """
        Recebe a intenção no prompt de usuário, "interpreta" o tool call
        e retorna em JSON formatado.
        """
        from llm.governance import GovernanceRules
        from llm.parser import LLMOuputValidator

        combined_context = "\n".join(part for part in [message, context] if part)
        msg_lower = combined_context.lower()

        def parse_and_govern(raw_json_str: str) -> str:
            validated_intent = LLMOuputValidator.validate_and_parse(raw_json_str)
            governed_intent = GovernanceRules.evaluate_action(validated_intent)
            return json.dumps(governed_intent)

        if "entrad" in msg_lower or "receb" in msg_lower:
            qty = AgentOrchestrator._extract_quantity(message)
            product_code = AgentOrchestrator._extract_product_code(message, context)

            tool_resp = await LLMTools.record_movement(
                tenant_id=tenant_id,
                product_code=product_code,
                type="ENTRY",
                quantity=qty,
            )
            resp_dict = json.loads(tool_resp)
            if resp_dict["status"] == "success":
                return parse_and_govern(json.dumps({"action": "Entry", "params": {"product": product_code, "quantity": qty}, "status": "success", "new_balance": resp_dict["new_balance"]}))
            return parse_and_govern(json.dumps({"action": "Entry", "params": {"product": product_code, "quantity": qty}, "status": "failed", "motivo": resp_dict["message"]}))

        elif "saíd" in msg_lower or "said" in msg_lower or "vend" in msg_lower:
            qty = AgentOrchestrator._extract_quantity(message)
            product_code = AgentOrchestrator._extract_product_code(message, context)

            tool_resp = await LLMTools.record_movement(
                tenant_id=tenant_id,
                product_code=product_code,
                type="EXIT",
                quantity=qty,
            )
            resp_dict = json.loads(tool_resp)
            if resp_dict["status"] == "success":
                return parse_and_govern(json.dumps({"action": "Exit", "params": {"product": product_code, "quantity": qty}, "status": "success", "new_balance": resp_dict["new_balance"]}))
            return parse_and_govern(json.dumps({"action": "Exit", "params": {"product": product_code, "quantity": qty}, "status": "failed", "motivo": resp_dict["message"]}))

        elif "invoice" in msg_lower or "ocr" in msg_lower or "nota fiscal" in msg_lower or "fornecedor:" in msg_lower:
            if "tecidos finos" in msg_lower or "2.300" in msg_lower:
                return parse_and_govern(json.dumps({
                    "action": "RegisterExpense",
                    "params": {
                        "value": 2300.0,
                        "category": "Matéria Prima",
                        "date": "2026-03-12",
                        "supplier": "TECIDOS FINOS LTDA"
                    },
                    "status": "success"
                }))
            return parse_and_govern(json.dumps({
                "action": "RegisterExpense",
                "params": {
                    "value": 150.0,
                    "category": "Logística",
                    "date": "2026-03-12",
                    "supplier": "Transporte S/A"
                },
                "status": "success"
            }))

        elif (
            "administrador" in msg_lower
            or "administra" in msg_lower
            or "prioridade" in msg_lower
            or "plano de ação" in msg_lower
            or "plano de acao" in msg_lower
            or "briefing" in msg_lower
        ):
            tool_resp = await LLMTools.get_daily_admin_briefing(tenant_id=tenant_id)
            resp_dict = json.loads(tool_resp)

            if resp_dict["status"] != "success":
                return parse_and_govern(json.dumps({
                    "action": "AdminPlan",
                    "status": "failed",
                    "motivo": resp_dict.get("message", "Falha ao montar o plano administrativo."),
                }))

            overview = resp_dict["data"]
            recommended_tasks = overview.get("recommended_tasks") or overview.get("recommended_actions") or []
            low_stock_count = overview.get("metrics", {}).get("low_stock_count", 0)
            return parse_and_govern(json.dumps({
                "action": "AdminPlan",
                "status": "success",
                "data": {
                    **overview,
                    "recommended_tasks": recommended_tasks,
                },
                "motivo": (
                    f"Briefing administrativo gerado com {low_stock_count} item(ns) com estoque abaixo do mínimo."
                ),
            }))

        elif "estoque" in msg_lower or "resumo" in msg_lower:
            tool_resp = await LLMTools.get_inventory_status(tenant_id=tenant_id)
            resp_dict = json.loads(tool_resp)
            items = resp_dict.get("data", [])
            return parse_and_govern(json.dumps({"action": "InventoryStatus", "status": "success", "data": items}))

        return parse_and_govern(json.dumps({"action": "Unknown", "status": "failed", "motivo": "Comando não reconhecido pelo vocabulário de logística e estoque da plataforma."}))
