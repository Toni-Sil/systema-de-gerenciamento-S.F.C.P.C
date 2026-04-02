"""AgentOrchestrator — núcleo do agente LLM do S.F.C.P.C.

Esta versão substitui a lógica de regex fixa por:
  1. Extração dinâmica de produto via search_product (sem hardcode de código)
  2. Memória de contexto multi-turn (sessão por tenant)
  3. Tools completas: Entry, Exit, Adjustment, Transfer, CreateProduct,
     SearchProduct, LowStockAlerts, RegisterExpense, FinancialSummary
  4. Resolução de referências contextuais ("esse produto", "o mesmo item")

A engine interna (regex determinístico) permanece como fallback até que
o LLM real (Llama-3 / Gemma) seja plugado — basta substituir o bloco
marcado com  # [LLM_HOOK]  abaixo.
"""
import json
import re
from uuid import UUID

from llm.tools import LLMTools
from llm import memory as MemoryStore


class AgentOrchestrator:

    SYSTEM_PROMPT = """Você é um assistente IA especialista em logística e gestão de estoque multi-tenant.
    Sua função é interpretar as intenções do usuário e retorná-las ESTRITAMENTE em formato JSON.
    Regras de Segurança: O tenant_id fornecido pelo orquestrador DEVE ser mantido isolado e em sigilo matemático nas transações (OWASP).
    Saída Estrita: RESPONDA APENAS com o JSON da transação (ex: {"action": "Entry", "params": {...}}). ZERO texto explicativo fora do JSON.
    Explicabilidade: Em caso de falha nas regras de negócio, adicione um campo "motivo" na sua resposta estruturada.
    Ações disponíveis: Entry, Exit, Adjustment, Transfer, SearchProduct, CreateProduct, LowStockAlerts, RegisterExpense, FinancialSummary, InventoryStatus.
    """

    # ------------------------------------------------------------------
    # Helpers de extração
    # ------------------------------------------------------------------

    @staticmethod
    def _extract_quantity(text: str) -> float:
        """Extrai o primeiro número encontrado no texto (inteiro ou decimal)."""
        matches = re.findall(r'\b(\d+(?:[.,]\d+)?)\b', text)
        if matches:
            return float(matches[0].replace(",", "."))
        return 1.0

    @staticmethod
    def _extract_product_hint(text: str) -> str | None:
        """
        Tenta extrair um código de produto (ex: TEC-001) ou
        uma palavra-chave de descrição para busca.
        """
        # Código explícito: padrão LETRAS-NÚMEROS
        code_match = re.search(r'\b([A-Za-z]{2,6}-\d{2,6})\b', text)
        if code_match:
            return code_match.group(1).upper()

        # Palavras-chave de produtos do domínio sofá/estofado
        domain_keywords = [
            "tecido", "espuma", "madeira", "ferragem", "mola",
            "fibra", "veludo", "couro", "suede", "chenille",
            "isopor", "mdf", "prego", "parafuso", "cola",
        ]
        text_lower = text.lower()
        for kw in domain_keywords:
            if kw in text_lower:
                return kw
        return None

    # ------------------------------------------------------------------
    # Processador principal
    # ------------------------------------------------------------------

    @staticmethod
    async def process_message(tenant_id: UUID, message: str) -> str:
        from llm.parser import LLMOuputValidator
        from llm.governance import GovernanceRules

        # Salva mensagem do usuário no histórico
        MemoryStore.add_message(tenant_id, "user", message)
        msg_lower = message.lower()

        def parse_and_govern(raw_json_str: str) -> str:
            validated = LLMOuputValidator.validate_and_parse(raw_json_str)
            governed = GovernanceRules.evaluate_action(validated)
            result = json.dumps(governed, ensure_ascii=False)
            # Salva resposta do agente no histórico
            MemoryStore.add_message(tenant_id, "assistant", result)
            return result

        # [LLM_HOOK] -------------------------------------------------------
        # Quando o LLM real for plugado, substituir TODA a lógica abaixo por:
        #
        #   context = MemoryStore.get_context_summary(tenant_id)
        #   full_prompt = AgentOrchestrator.SYSTEM_PROMPT + "\n\nContexto:\n" + context + "\n\nUsuário: " + message
        #   raw_response = llm.invoke(full_prompt)   # Gemma / Llama-3
        #   return parse_and_govern(raw_response)
        #
        # ------------------------------------------------------------------

        qty = AgentOrchestrator._extract_quantity(message)
        product_hint = AgentOrchestrator._extract_product_hint(message)

        # Resolve referência contextual ("esse produto", "o mesmo")
        if product_hint is None:
            contextual_keywords = ["esse", "mesmo", "aquele", "item", "produto"]
            if any(kw in msg_lower for kw in contextual_keywords):
                product_hint = MemoryStore.get_last_product_context(tenant_id)

        # ---- Resetar conversa ----
        if any(k in msg_lower for k in ["resetar conversa", "limpar histórico", "nova sessão"]):
            MemoryStore.clear_history(tenant_id)
            GovernanceRules.reset_session_counter(str(tenant_id))
            return json.dumps({"action": "SessionReset", "status": "success", "message": "Histórico de conversa e contadores resetados."})

        # ---- Busca de produto ----
        if any(k in msg_lower for k in ["buscar produto", "procurar produto", "encontrar produto", "listar produto", "qual o código"]):
            query = product_hint or message
            tool_resp = await LLMTools.search_product(tenant_id=tenant_id, query=query)
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "SearchProduct", "status": resp.get("status"), "data": resp.get("data"), "count": resp.get("count", 0)}))

        # ---- Cadastrar produto ----
        if any(k in msg_lower for k in ["cadastrar produto", "criar produto", "novo produto", "adicionar produto"]):
            # Extrai parâmetros básicos do texto; LLM real fará isso estruturadamente
            code_match = re.search(r'código[:\s]+([\w-]+)', msg_lower)
            desc_match = re.search(r'descrição[:\s]+([^,\.]+)', msg_lower)
            unit_match = re.search(r'unidade[:\s]+(\w+)', msg_lower)
            code = code_match.group(1).upper() if code_match else f"PROD-{abs(hash(message)) % 9999:04d}"
            description = desc_match.group(1).strip().title() if desc_match else message[:80]
            unit = unit_match.group(1).upper() if unit_match else "UN"
            tool_resp = await LLMTools.create_product(tenant_id=tenant_id, code=code, description=description, unit=unit)
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "CreateProduct", "status": resp.get("status"), "params": {"code": code, "description": description}, "motivo": resp.get("message")}))

        # ---- Alertas de estoque baixo ----
        if any(k in msg_lower for k in ["alerta", "estoque baixo", "ruptura", "crítico", "faltando", "acabando"]):
            tool_resp = await LLMTools.get_low_stock_alerts(tenant_id=tenant_id)
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "LowStockAlerts", "status": resp.get("status"), "data": resp.get("data"), "count": resp.get("count", 0)}))

        # ---- Resumo financeiro ----
        if any(k in msg_lower for k in ["resumo financeiro", "financeiro", "despesas", "margem", "custos do mês"]):
            from datetime import date
            today = date.today()
            period_start = today.replace(day=1).isoformat()
            period_end = today.isoformat()
            tool_resp = await LLMTools.get_financial_summary(tenant_id=tenant_id, period_start=period_start, period_end=period_end)
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "FinancialSummary", "status": resp.get("status"), "data": resp.get("data")}))

        # ---- Status do estoque ----
        if any(k in msg_lower for k in ["estoque", "resumo", "saldo", "inventário"]):
            tool_resp = await LLMTools.get_inventory_status(tenant_id=tenant_id)
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "InventoryStatus", "status": resp.get("status"), "data": resp.get("data")}))

        # ---- Entrada de estoque ----
        if any(k in msg_lower for k in ["entrad", "receb", "comprei", "chegou", "entrada de"]):
            if product_hint is None:
                return parse_and_govern(json.dumps({
                    "action": "Entry",
                    "status": "failed",
                    "motivo": "Não consegui identificar o produto. Informe o código (ex: TEC-001) ou uma palavra-chave da descrição."
                }))

            # Resolve produto via busca dinâmica
            search_resp = json.loads(await LLMTools.search_product(tenant_id=tenant_id, query=product_hint))
            if search_resp["status"] != "success" or not search_resp["data"]:
                return parse_and_govern(json.dumps({"action": "Entry", "status": "failed", "motivo": f"Produto '{product_hint}' não encontrado no catálogo."}))

            product_code = search_resp["data"][0]["code"]
            tool_resp = await LLMTools.record_movement(tenant_id=tenant_id, product_code=product_code, type="ENTRY", quantity=qty)
            resp = json.loads(tool_resp)
            status = resp.get("status") if resp.get("status") != "error" else "failed"
            return parse_and_govern(json.dumps({"action": "Entry", "params": {"product": product_code, "quantity": qty}, "status": status, "new_balance": resp.get("new_balance"), "motivo": resp.get("message") if status == "failed" else None}))

        # ---- Saída de estoque ----
        if any(k in msg_lower for k in ["saíd", "said", "vend", "consumi", "retirei", "saída de"]):
            if product_hint is None:
                return parse_and_govern(json.dumps({
                    "action": "Exit",
                    "status": "failed",
                    "motivo": "Não consegui identificar o produto. Informe o código (ex: TEC-001) ou uma palavra-chave da descrição."
                }))

            search_resp = json.loads(await LLMTools.search_product(tenant_id=tenant_id, query=product_hint))
            if search_resp["status"] != "success" or not search_resp["data"]:
                return parse_and_govern(json.dumps({"action": "Exit", "status": "failed", "motivo": f"Produto '{product_hint}' não encontrado no catálogo."}))

            product_code = search_resp["data"][0]["code"]
            tool_resp = await LLMTools.record_movement(tenant_id=tenant_id, product_code=product_code, type="EXIT", quantity=qty)
            resp = json.loads(tool_resp)
            status = resp.get("status") if resp.get("status") != "error" else "failed"
            return parse_and_govern(json.dumps({"action": "Exit", "params": {"product": product_code, "quantity": qty}, "status": status, "new_balance": resp.get("new_balance"), "motivo": resp.get("message") if status == "failed" else None}))

        # ---- OCR / Nota Fiscal ----
        if any(k in msg_lower for k in ["invoice", "ocr", "nota fiscal", "fornecedor:", "nf "]):
            value_match = re.search(r'r\$\s*([\d.,]+)', msg_lower)
            supplier_match = re.search(r'fornecedor[:\s]+([^,\.\n]+)', msg_lower, re.IGNORECASE)
            value = float(value_match.group(1).replace(".", "").replace(",", ".")) if value_match else 0.0
            supplier = supplier_match.group(1).strip().upper() if supplier_match else None
            tool_resp = await LLMTools.register_expense(
                tenant_id=tenant_id,
                value=value,
                category="Matéria Prima",
                supplier=supplier,
            )
            resp = json.loads(tool_resp)
            return parse_and_govern(json.dumps({"action": "RegisterExpense", "params": {"value": value, "supplier": supplier}, "status": resp.get("status"), "motivo": resp.get("message")}))

        # ---- Fallback ----
        context_hint = MemoryStore.get_context_summary(tenant_id)
        return parse_and_govern(json.dumps({
            "action": "Unknown",
            "status": "failed",
            "motivo": "Comando não reconhecido. Tente: 'entrada de 10 tecidos', 'alertas de estoque', 'resumo financeiro', 'buscar produto espuma'.",
            "context_available": bool(context_hint),
        }))
