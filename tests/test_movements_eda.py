from fastapi.testclient import TestClient
from main import app
from uuid import uuid4
import sys
import os

client = TestClient(app)

def test_stock_movement_and_alerts():
    tenant_id = str(uuid4())
    headers = {"X-Tenant-ID": tenant_id}
    
    # 1. Create a product with min_stock = 5
    product_id = str(uuid4())
    product = {
        "id": product_id,
        "tenant_id": tenant_id,
        "code": "LOW-STOCK-PROD",
        "description": "Product for alert testing",
        "unit": "UN",
        "min_stock": 5.0
    }
    client.post("/products", json=product, headers=headers)
    
    print("\n--- Testing Stock Entry ---")
    # 2. Entry of 10 units
    entry = {
        "id": str(uuid4()),
        "tenant_id": tenant_id,
        "product_id": product_id,
        "type": "ENTRY",
        "quantity": 10.0
    }
    response = client.post("/movements", json=entry, headers=headers)
    assert response.status_code == 200
    assert response.json()["balance"] == 10.0
    
    print("\n--- Testing Stock Exit (Triggers Alert) ---")
    # 3. Exit of 7 units (Remaining: 3, which is < min_stock 5)
    exit_mv = {
        "id": str(uuid4()),
        "tenant_id": tenant_id,
        "product_id": product_id,
        "type": "EXIT",
        "quantity": 7.0
    }
    response = client.post("/movements", json=exit_mv, headers=headers)
    assert response.status_code == 200
    assert response.json()["balance"] == 3.0
    
    print("\n--- Testing Insufficient Stock ---")
    # 4. Try to exit 5 more (should fail)
    exit_fail = {
        "id": str(uuid4()),
        "tenant_id": tenant_id,
        "product_id": product_id,
        "type": "EXIT",
        "quantity": 5.0
    }
    response = client.post("/movements", json=exit_fail, headers=headers)
    assert response.status_code == 400
    assert response.json()["detail"] == "Insufficient stock"

if __name__ == "__main__":
    try:
        test_stock_movement_and_alerts()
        print("\nAll movement and alert tests PASSED!")
    except Exception as e:
        print(f"\nTest FAILED: {e}")
        sys.exit(1)
