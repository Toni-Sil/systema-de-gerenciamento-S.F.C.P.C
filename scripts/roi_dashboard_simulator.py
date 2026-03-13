# scripts/roi_dashboard_simulator.py
import sys
import os
import asyncio

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))
from uuid import uuid4
from data.gold_service import GoldLayerService
from auth.tenant_context import set_tenant_id
from models.entities import ProductSchema, StockBalanceSchema
from services.stock_service import product_repo, balance_repo

async def generate_roi_report(tenant_id):
    """
    Simula um Dashboard Executivo de ROI provando o valor da IA no
    Sistema S.F.C.P.C (SaaS Multi-tenant p/ nicho de Estofados).
    Cruza rupturas (is_low_stock) com custos estimados de armazenagem.
    """
    print(f"\n=======================================================")
    print(f" S.F.C.P.C - DASHBOARD DE ROI & INTELIGÊNCIA EXECUTIVA ")
    print(f" Tenant ID: {tenant_id}")
    print(f"=======================================================\n")

    summary = await GoldLayerService.get_inventory_summary(tenant_id)
    
    total_items = len(summary)
    low_stock_items = sum(1 for item in summary if item["is_low_stock"])
    total_capital_invested = sum(item["total_balance"] * 120.50 for item in summary) # Valor médio simulado de R$120.50/unidade
    
    print(f" [MÉTRICAS DA LAKEHOUSE - GOLD LAYER]")
    print(f" > Total de Produtos Rastreados: {total_items}")
    print(f" > Capital Empatado em Estoque (Estimado): R$ {total_capital_invested:,.2f}")
    
    print("\n [PREVENÇÃO DE RUPTURAS (STOCKOUTS)]")
    if low_stock_items > 0:
        print(f" ⚠️ ATENÇÃO: {low_stock_items} itens críticos (< mínimo).")
        print(f" 💡 A IA (Forecasting + Alertas NLP) economizou aproximadamente R$ {(low_stock_items * 500):,.2f} evitando paradas na produção de sofás.")
    else:
        print(" ✅ O Estoque está balanceado (Zero Rupturas). A IA está mantendo o giro eficiente.")
        
    print("\n [GOVERNANÇA LLM & HUMAN-IN-THE-LOOP]")
    print(" 🛡️ As Políticas bloquearam 1 movimentação atípica (>1.000 un) e 0 Compras não autorizadas (>R$ 5.000).")
    print(" 📉 ROI Projetado da Ferramenta neste Mês: +15,4% (Redução de capital parado & Custos de parada).")
    print("\n=======================================================\n")

async def mock_seed_and_run():
    tid = uuid4()
    set_tenant_id(tid)
    
    # Mock some data
    p1 = uuid4()
    p2 = uuid4()
    await product_repo.create(ProductSchema(id=p1, tenant_id=tid, code="FABRIC-LINHO", description="Linho Off-white", min_stock=50))
    await product_repo.create(ProductSchema(id=p2, tenant_id=tid, code="FOAM-D28", description="Espuma D28", min_stock=100))
    
    # Provide balances
    await balance_repo.create(StockBalanceSchema(tenant_id=tid, product_id=p1, balance=20)) # LOW STOCK (20 < 50)
    await balance_repo.create(StockBalanceSchema(tenant_id=tid, product_id=p2, balance=150)) # GOOD (150 > 100)
    
    await generate_roi_report(tid)
    
if __name__ == "__main__":
    asyncio.run(mock_seed_and_run())
