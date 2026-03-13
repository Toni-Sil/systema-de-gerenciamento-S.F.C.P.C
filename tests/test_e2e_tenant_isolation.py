import pytest
from fastapi.testclient import TestClient
from uuid import uuid4

# Imports da aplicação FastAPI
from main import app

client = TestClient(app)

def test_tenant_isolation_product_entry_flow():
    """
    Testa de ponta a ponta (E2E) se o fluxo de criação de produtos e 
    lançamento de entradas de estoque respeita o isolamento do tenant.
    """
    tenant_a = str(uuid4())
    tenant_b = str(uuid4())
    
    # --- TENANT A: Criação de Produto ---
    product_data_a = {
        "tenant_id": tenant_a,
        "code": "ISOLATION-001",
        "description": "Product strictly for Tenant A",
        "unit": "KG",
        "min_stock": 10.0
    }
    
    resp_create_a = client.post("/products", json=product_data_a, headers={"X-Tenant-ID": tenant_a})
    assert resp_create_a.status_code == 200, "Tenant A falhou ao criar o produto"
    product_a_id = resp_create_a.json()["id"]
    
    # --- TENANT A: Executa Movimentação de Entrada ---
    movement_data_a = {
        "tenant_id": tenant_a,
        "product_id": product_a_id,
        "type": "ENTRY",
        "quantity": 50.0
    }
    resp_mov_a = client.post("/movements", json=movement_data_a, headers={"X-Tenant-ID": tenant_a})
    assert resp_mov_a.status_code == 200, "Tenant A falhou ao registrar entrada"
    
    # --- TENANT A: Verifica Saldo Atual ---
    resp_bal_a = client.get("/balances", headers={"X-Tenant-ID": tenant_a})
    assert resp_bal_a.status_code == 200
    balances_a = resp_bal_a.json()
    assert len(balances_a) == 1, "Tenant A deveria ter 1 registro de saldo"
    assert balances_a[0]["product_id"] == product_a_id
    assert balances_a[0]["balance"] == 50.0
    
    # --------------------------------------------------------------------------------
    # VALIDAÇÃO ANTI-VAZAMENTO E ISOLAMENTO (TENANT B)
    # --------------------------------------------------------------------------------
    
    # --- TENANT B: Tenta listar Produtos (deve aparecer vazio) ---
    resp_prod_b = client.get("/products", headers={"X-Tenant-ID": tenant_b})
    assert resp_prod_b.status_code == 200
    products_b = resp_prod_b.json()
    assert len(products_b) == 0, "FALHA DE ISOLAMENTO: Tenant B consegue ver produtos do Tenant A!"
    
    # --- TENANT B: Tenta listar Saldos (deve aparecer vazio) ---
    resp_bal_b = client.get("/balances", headers={"X-Tenant-ID": tenant_b})
    assert resp_bal_b.status_code == 200
    balances_b = resp_bal_b.json()
    assert len(balances_b) == 0, "FALHA DE ISOLAMENTO: Tenant B consegue ver saldos do Tenant A!"
    
    # --- TENANT B: Tenta registrar entrada no produto do Tenant A ---
    movement_data_b = {
        "tenant_id": tenant_b,
        "product_id": product_a_id, # Forjando acesso no ID do produto do Tenant A
        "type": "ENTRY",
        "quantity": 20.0
    }
    resp_mov_b = client.post("/movements", json=movement_data_b, headers={"X-Tenant-ID": tenant_b})
    # Espera-se 404 Not Found porque o repositório filtra por Tenant B e não acha o produto
    assert resp_mov_b.status_code == 404, "FALHA DE ISOLAMENTO: Tenant B conseguiu movimentar produto do Tenant A!"
    assert resp_mov_b.json()["detail"] == "Product not found"
    
    # --- TENANT A: Garante que o saldo permaneceu inalterado (Blindagem) ---
    resp_bal_a_final = client.get("/balances", headers={"X-Tenant-ID": tenant_a})
    balances_a_final = resp_bal_a_final.json()
    assert balances_a_final[0]["balance"] == 50.0, "FALHA DE ISOLAMENTO: O saldo do Tenant A sofreu mutação indevida!"
