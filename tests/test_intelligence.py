import asyncio
from uuid import uuid4
from datetime import datetime, timedelta
import sys
import os

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

from data.gold_service import GoldLayerService
from ml.abc_analysis import ABCAnalysis
from ml.demand_forecasting import DemandForecasting
from ml.mlops_monitor import MLOpsMonitor
from models.entities import ProductSchema, MovementSchema, MovementType, StockBalanceSchema
from services.stock_service import product_repo, balance_repo, movement_repo
from auth.tenant_context import set_tenant_id

async def verify_ml_intelligence():
    tenant_id = uuid4()
    set_tenant_id(tenant_id)
    print(f"\n--- Iniciando Verificação de Inteligência (Tenant: {tenant_id}) ---")
    
    # 1. Setup Mock Data
    p1_id = uuid4()
    p2_id = uuid4()
    p3_id = uuid4()
    
    products = [
        ProductSchema(id=p1_id, tenant_id=tenant_id, code="A-HIGH", description="Item Caro", unit="UN", min_stock=10),
        ProductSchema(id=p2_id, tenant_id=tenant_id, code="B-MED", description="Item Médio", unit="UN", min_stock=5),
        ProductSchema(id=p3_id, tenant_id=tenant_id, code="C-LOW", description="Item Barato", unit="UN", min_stock=2)
    ]
    for p in products: await product_repo.create(p)
    
    # 2. Setup Balances (Gold Layer aggregation test)
    balances = [
        StockBalanceSchema(tenant_id=tenant_id, product_id=p1_id, balance=100.0),
        StockBalanceSchema(tenant_id=tenant_id, product_id=p2_id, balance=20.0),
        StockBalanceSchema(tenant_id=tenant_id, product_id=p3_id, balance=5.0)
    ]
    for b in balances: await balance_repo.create(b)
    
    # 3. Test Gold Layer
    print("\n[INFO] Verificando Gold Layer...")
    gold_summary = await GoldLayerService.get_inventory_summary(tenant_id)
    assert len(gold_summary) == 3
    print("  OK: Gold Layer agregou 3 produtos.")
    
    # 4. Test ABC Analysis
    print("\n[INFO] Verificando Curva ABC...")
    abc_data = ABCAnalysis.calculate(gold_summary)
    # P1 (balance 100) deve ser 'A', P2 (20) 'B', P3 (5) 'C' approx
    # Total = 125. A: 100/125 = 80%. B: 120/125 = 96%.
    for item in abc_data:
        if item["code"] == "A-HIGH": assert item["abc_class"] == "A"
        print(f"  Produto {item['code']}: Classe {item['abc_class']}")
    print("  OK: Curva ABC calculada com sucesso.")
    
    # 5. Test Demand Forecasting
    print("\n[INFO] Verificando Previsão de Demanda...")
    # Mock movements history (only exits)
    history = [
        {"product_id": p1_id, "type": "EXIT", "quantity": 10.0, "created_at": datetime.now() - timedelta(days=5)},
        {"product_id": p1_id, "type": "EXIT", "quantity": 10.0, "created_at": datetime.now()}
    ]
    predictions = DemandForecasting.predict_next_period(history, days=30)
    # Media = 20 / 6 dias (aprox) = 3.33/dia. 30 dias = ~100.
    print(f"  Previsão P1 (30 dias): {predictions.get(str(p1_id))}")
    assert float(predictions.get(str(p1_id))) > 0
    print("  OK: Previsão de demanda gerada.")
    
    # 6. Test MLOps Monitoring (Drift)
    print("\n[INFO] Verificando Monitoramento de Drift...")
    baseline = {"total_volume": 100.0}
    current_high_drift = {"total_volume": 200.0} # 100% de aumento
    
    has_drift = MLOpsMonitor.check_data_drift(baseline, current_high_drift)
    assert has_drift is True
    
    acc_ok = MLOpsMonitor.check_model_accuracy(100.0, 110.0) # 10% erro (abaixo de 20%)
    assert acc_ok is False # No alert
    
    acc_fail = MLOpsMonitor.check_model_accuracy(100.0, 150.0) # 50% erro
    assert acc_fail is True # Alert triggered
    
    print("\n--- Todos os testes de Inteligência e MLOps PASSERAM! ---")

if __name__ == "__main__":
    asyncio.run(verify_ml_intelligence())
