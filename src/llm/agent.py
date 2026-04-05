import os
import json
import logging
from uuid import UUID
from typing import List, Optional, Dict, Any

from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.orm_models import ProductORM
from llm.tools import LLMTools
from llm.parser import LLMOuputValidator
from llm.governance import GovernanceRules
from llm.providers import get_llm_provider

logger = logging.getLogger(__name__)

class AgentOrchestrator:
    """
    Orquestrador do Agente IA - Multiprovedor (Agnóstico).
    Refatorado para suportar Gemini, Ollama e outros através de um sistema de Provedores.
    """

    @staticmethod
    async def get_system_context(tenant_id: UUID, session: AsyncSession) -> str:
        """Busca o catálogo de produtos real para injetar no prompt do modelo."""
        try:
            result = await session.execute(
                select(ProductORM).where(
                    ProductORM.tenant_id == tenant_id,
                    ProductORM.is_active == True
                )
            )
            products = result.scalars().all()
            
            if not products:
                return "Atenção: Não há produtos cadastrados para este estoque."
            
            hint = "CATÁLOGO DE PRODUTOS ATUALIZADO (Use estes códigos exatos):\n"
            for p in products:
                hint += f"- Descrição: {p.description} | Código: {p.code} | Unidade: {p.unit}\n"
            return hint
        except Exception as e:
            logger.error(f"Erro ao buscar contexto do catálogo: {e}")
            return "Erro ao sincronizar catálogo."

    @staticmethod
    async def process_message(tenant_id: UUID, message: str, session: AsyncSession) -> str:
        """
        Interpreta a mensagem do usuário usando o Provedor de LLM configurado.
        """
        # 1. Obter Catalogo Dinamico
        catalog_hint = await AgentOrchestrator.get_system_context(tenant_id, session)

        # 2. Obter Provedor de IA (Gemini, Ollama, OpenAI, etc)
        provider = await get_llm_provider(tenant_id, session)
        
        try:
            system_instruction = (
                "Você é o Especialista Logístico do SFC-PC (Smart System). "
                f"Contexto do Tenant ID: {tenant_id}\n\n"
                f"{catalog_hint}\n"
                "Regras de Ouro:\n"
                "1. Identifique o código do produto no catálogo acima.\n"
                "2. Retorne OBRIGATORIAMENTE um JSON puro (nada mais).\n"
                "3. Formatos válidos:\n"
                "   - Entrada: {'action': 'Entry', 'params': {'product': 'CODIGO', 'quantity': 10}}\n"
                "   - Saída: {'action': 'Exit', 'params': {'product': 'CODIGO', 'quantity': 5}}\n"
                "   - Saldo/Estoque: {'action': 'InventoryStatus', 'params': {}}\n"
                "   - Despesa: {'action': 'RegisterExpense', 'params': {'value': 100.0, 'supplier': 'Nome'}}\n"
            )

            # 3. Gerar Resposta via Provedor Selecionado
            raw_text = await provider.process_prompt(system_instruction, message)
            
            # 4. Validar JSON e Aplicar Governança
            validated_intent = LLMOuputValidator.validate_and_parse(raw_text)
            governed_intent = GovernanceRules.evaluate_action(validated_intent)
            
            # 5. Executar Ação no Banco de Dados
            action = governed_intent.get("action")
            status = governed_intent.get("status")
            params = governed_intent.get("params", {}) or {}
            
            if status == "success":
                if action == "Entry":
                    tool_resp = await LLMTools.record_movement(
                        tenant_id, params.get("product"), "ENTRY", float(params.get("quantity", 1)), session
                    )
                    return AgentOrchestrator._merge_tool_resp(governed_intent, tool_resp)
                
                elif action == "Exit":
                    tool_resp = await LLMTools.record_movement(
                        tenant_id, params.get("product"), "EXIT", float(params.get("quantity", 1)), session
                    )
                    return AgentOrchestrator._merge_tool_resp(governed_intent, tool_resp)
                
                elif action == "InventoryStatus":
                    tool_resp = await LLMTools.get_inventory_status(tenant_id, session)
                    return AgentOrchestrator._merge_tool_resp(governed_intent, tool_resp)

            return json.dumps(governed_intent, ensure_ascii=False)

        except Exception as e:
            logger.error(f"Erro no AgenteOrchestrator via {type(provider).__name__}: {e}")
            return json.dumps({
                "action": "SystemError", 
                "status": "failed", 
                "motivo": f"Indisponibilidade temporária na IA: {str(e)}"
            }, ensure_ascii=False)

    @staticmethod
    async def process_multimodal(
        tenant_id: UUID, 
        message: str, 
        media_bytes: bytes, 
        mime_type: str, 
        session: AsyncSession
    ) -> str:
        """
        Analisa mídia (fotos de documentos, notas fiscais, prints) e extrai intenções logísticas.
        """
        # 1. Obter Catalogo e Provedor
        catalog_hint = await AgentOrchestrator.get_system_context(tenant_id, session)
        provider = await get_llm_provider(tenant_id, session)

        # 2. Instrução de Especialista em Visão de Documentos
        system_instruction = (
            "Você é o Especialista em Visão Computacional do SFC-PC. "
            "Sua tarefa é ler este documento/imagem e extrair movimentações de estoque ou faturas financeiras.\n\n"
            f"{catalog_hint}\n"
            "Retorne APENAS o JSON da intenção:\n"
            "- Se for uma Nota Fiscal de compra: {'action': 'RegisterExpense', 'params': {'value': 0.0, 'supplier': '...'}}\n"
            "- Se for um canhoto de entrega: {'action': 'Entry', 'params': {'product': '...', 'quantity': 0}}\n"
        )

        try:
            raw_text = await provider.process_multimodal(system_instruction, message, media_bytes, mime_type)
            validated_intent = LLMOuputValidator.validate_and_parse(raw_text)
            
            # Aqui não executamos a ferramenta automaticamente (aguardamos confirmação do usuário no UI)
            # Mas aplicamos governança para avisar sobre riscos
            governed_intent = GovernanceRules.evaluate_action(validated_intent)
            return json.dumps(governed_intent, ensure_ascii=False)
        except Exception as e:
            logger.error(f"Erro no processamento Multimodal: {e}")
            return json.dumps({"action": "VisionError", "status": "failed", "motivo": str(e)}, ensure_ascii=False)

    @staticmethod
    async def generate_dashboard_insight(tenant_id: UUID, session: AsyncSession) -> str:
        """Gera um insight rápido utilizando o provedor configurado."""
        from data.gold_service import GoldLayerService
        summary = await GoldLayerService.get_inventory_summary(tenant_id, session)
        
        low_stock_items = [s for s in summary if s['is_low_stock']]
        
        prompt = (
            f"Gerencie: {len(summary)} produtos, {len(low_stock_items)} em falta.\n"
            f"Críticos: {', '.join([i['description'] for i in low_stock_items[:2]])}.\n"
            "Gere uma frase de insight profissional sobre reposição. Seja ultra breve."
        )

        try:
            provider = await get_llm_provider(tenant_id, session)
            return await provider.generate_insight(prompt)
        except:
            return "Estoque sincronizado. Verifique itens críticos."

    @staticmethod
    def _merge_tool_resp(intent: Dict[str, Any], tool_json_str: str) -> str:
        """Une a intenção inicial com o resultado real da execução da ferramenta."""
        try:
            tool_data = json.loads(tool_json_str)
            if tool_data.get("status") == "success":
                intent["data"] = tool_data.get("data")
                intent["new_balance"] = tool_data.get("new_balance")
                intent["motivo"] = tool_data.get("message")
                intent["status"] = "success"
            else:
                intent["status"] = "failed"
                intent["motivo"] = tool_data.get("message")
            return json.dumps(intent, ensure_ascii=False)
        except Exception:
            return json.dumps(intent, ensure_ascii=False)

