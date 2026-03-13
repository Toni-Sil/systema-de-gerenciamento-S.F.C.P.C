import asyncio
from uuid import uuid4
import sys
import os
import json

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

from llm.agent import AgentOrchestrator
from models.entities import ProductSchema, StockBalanceSchema
from services.stock_service import product_repo, balance_repo
from auth.tenant_context import set_tenant_id

async def verify_llm_agent():
    tenant_id = uuid4()
    set_tenant_id(tenant_id)
    print(f"\n--- Iniciando Teste do Agente LLM (Tenant: {tenant_id}) ---")
    
    # Setup mock product (TEST-001 is hardcoded in agent mock for this phase)
    p_id = uuid4()
    await product_repo.create(ProductSchema(id=p_id, tenant_id=tenant_id, code="TEST-001", description="Teste LLM", unit="UN"))
    await balance_repo.create(StockBalanceSchema(tenant_id=tenant_id, product_id=p_id, balance=50.0))
    
    # Cenário 1: Entrada via Linguagem Natural
    msg = "Acabei de dar entrada em 15 caixas do produto"
    print(f"\n[Usuário]: {msg}")
    resposta = await AgentOrchestrator.process_message(tenant_id, msg)
    print(f"[Agente]: {resposta}")
    resp_obj = json.loads(resposta)
    assert resp_obj["action"] == "Entry"
    assert resp_obj["new_balance"] == 65.0 # 50 + 15
    
    # Cenário 2: Saída
    msg2 = "Vendi 5 peças, dê saída"
    print(f"\n[Usuário]: {msg2}")
    resposta = await AgentOrchestrator.process_message(tenant_id, msg2)
    print(f"[Agente]: {resposta}")
    resp_obj = json.loads(resposta)
    assert resp_obj["action"] == "Exit"
    assert resp_obj["new_balance"] == 60.0 # 65 - 5
    
    # Cenário 3: Resumo
    msg3 = "Me mostre o status do estoque"
    print(f"\n[Usuário]: {msg3}")
    resposta = await AgentOrchestrator.process_message(tenant_id, msg3)
    print(f"[Agente]: {resposta}")
    resp_obj = json.loads(resposta)
    assert resp_obj["action"] == "InventoryStatus"
    assert len(resp_obj["data"]) == 1
    
    # Cenário 4: Não reconhecido
    msg4 = "Me conte uma piada"
    print(f"\n[Usuário]: {msg4}")
    resposta = await AgentOrchestrator.process_message(tenant_id, msg4)
    print(f"[Agente]: {resposta}")
    resp_obj = json.loads(resposta)
    assert resp_obj["action"] == "Unknown"
    assert resp_obj["status"] == "failed"
    assert "logística" in resp_obj["motivo"]
    
    # Cenário 5: Governança - Volume Anômalo (Human-in-the-loop)
    msg5 = "Vendi 1500 peças, dê saída"
    print(f"\n[Usuário]: {msg5}")
    resposta = await AgentOrchestrator.process_message(tenant_id, msg5)
    print(f"[Agente]: {resposta}")
    resp_obj = json.loads(resposta)
    assert resp_obj["action"] == "Exit"
    assert resp_obj["status"] == "needs_approval"
    assert "movimentação atípica" in resp_obj["motivo"].lower()
    
    print("\n--- Todos os testes do Agente LLM PASSERAM! ---")

if __name__ == "__main__":
    asyncio.run(verify_llm_agent())
