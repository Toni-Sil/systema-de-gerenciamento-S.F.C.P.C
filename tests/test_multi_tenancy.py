from fastapi.testclient import TestClient
from main import app
from uuid import uuid4

client = TestClient(app)

def test_multi_tenancy_isolation():
    tenant_a = str(uuid4())
    tenant_b = str(uuid4())
    
    # 1. Create product for Tenant A
    prod_a = {
        "id": str(uuid4()),
        "tenant_id": tenant_a,
        "code": "A-001",
        "description": "Tenant A Product",
        "unit": "UN"
    }
    response = client.post("/products", json=prod_a, headers={"X-Tenant-ID": tenant_a})
    assert response.status_code == 200
    
    # 2. Create product for Tenant B
    prod_b = {
        "id": str(uuid4()),
        "tenant_id": tenant_b,
        "code": "B-001",
        "description": "Tenant B Product",
        "unit": "UN"
    }
    response = client.post("/products", json=prod_b, headers={"X-Tenant-ID": tenant_b})
    assert response.status_code == 200
    
    # 3. Verify Tenant A only sees their product
    response = client.get("/products", headers={"X-Tenant-ID": tenant_a})
    data = response.json()
    assert len(data) == 1
    assert data[0]["code"] == "A-001"
    
    # 4. Verify Tenant B only sees their product
    response = client.get("/products", headers={"X-Tenant-ID": tenant_b})
    data = response.json()
    assert len(data) == 1
    assert data[0]["code"] == "B-001"
    
    # 5. Verify request without header fails (repository requires it)
    response = client.get("/products")
    # Middleware currently passes through if header is missing, 
    # but repo raises 403 because context is empty.
    assert response.status_code == 403

if __name__ == "__main__":
    test_multi_tenancy_isolation()
    print("Multi-tenancy isolation test PASSED!")
