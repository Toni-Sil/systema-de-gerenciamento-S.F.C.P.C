import httpx
import sys
import os
from uuid import uuid4
import time

API_URL = "http://localhost:8000"

def run_practical_tests():
    tenant_id = str(uuid4())
    headers = {"X-Tenant-ID": tenant_id}
    print(f"\n--- Iniciando Testes Práticos na API (Tenant: {tenant_id}) ---")
    
    with httpx.Client(base_url=API_URL, headers=headers) as client:
        # 1. Healthcheck
        r = client.get("/")
        print(f"Healthcheck: Status {r.status_code}")
        assert r.status_code == 200
        
        # 2. Criar Produto
        product_data = {
            "tenant_id": tenant_id,
            "code": "TEST-001",
            "description": "Produto de Teste Prático",
            "unit": "UN",
            "min_stock": 5.0
        }
        r = client.post("/products", json=product_data)
        print(f"Criar Produto: Status {r.status_code}")
        assert r.status_code == 200
        product_id = r.json()["id"]
        
        # 3. Listar Produtos
        r = client.get("/products")
        print(f"Listar Produtos: Status {r.status_code}, Encontrados: {len(r.json())}")
        assert r.status_code == 200
        assert len(r.json()) >= 1
        
        # 4. Criar Movimentação (Entrada)
        movement_data = {
            "tenant_id": tenant_id,
            "product_id": product_id,
            "type": "ENTRY",
            "quantity": 10.0
        }
        r = client.post("/movements", json=movement_data)
        print(f"Movimentação (Entrada): Status {r.status_code}")
        assert r.status_code == 200
        
        # 5. Listar Saldos
        r = client.get("/balances")
        print(f"Saldos Atuais: Status {r.status_code}")
        assert r.status_code == 200
        balances = r.json()
        assert any(b["product_id"] == product_id and b["balance"] == 10.0 for b in balances)
        # 6. Testar Inteligência (Gold Layer)
        r = client.get("/intelligence/inventory-summary")
        print(f"Resumo do Inventário (Gold): Status {r.status_code}")
        assert r.status_code == 200
        
        # 7. Testar Curva ABC
        r = client.get("/intelligence/abc-analysis")
        print(f"Curva ABC: Status {r.status_code}")
        assert r.status_code == 200
        
        # 8. Testar Previsão de Demanda
        # Primeiro, criamos uma saída para gerar histórico de demanda
        exit_data = {
            "tenant_id": tenant_id,
            "product_id": product_id,
            "type": "EXIT",
            "quantity": 2.0
        }
        client.post("/movements", json=exit_data)
        
        r = client.get("/intelligence/demand-forecast?days=15")
        print(f"Previsão de Demanda (15 dias): Status {r.status_code}, Dados: {r.json()}")
        assert r.status_code == 200

    print("\n--- Todos os testes práticos da API responderam com sucesso! ---")

if __name__ == "__main__":
    try:
        run_practical_tests()
    except Exception as e:
        print(f"Erro durante os testes: {e}")
        sys.exit(1)
