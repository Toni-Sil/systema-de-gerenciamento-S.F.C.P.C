from fastapi.testclient import TestClient
from main import app
from uuid import uuid4
import time

client = TestClient(app)

def test_rate_limiting_per_tenant():
    tenant_a = str(uuid4())
    tenant_b = str(uuid4())
    
    print(f"\n--- Testing Rate Limit for Tenant A (Limit: 60) ---")
    for i in range(60):
        response = client.get("/", headers={"X-Tenant-ID": tenant_a})
        assert response.status_code == 200
    print("Request 60: Success")

    # 61st request should fail for Tenant A
    response = client.get("/", headers={"X-Tenant-ID": tenant_a})
    assert response.status_code == 429
    print("Request 61: Blocked as expected (429)")

    print(f"\n--- Testing Tenant B (Should not be blocked) ---")
    # Tenant B should still be able to make requests
    response = client.get("/", headers={"X-Tenant-ID": tenant_b})
    assert response.status_code == 200
    print("Tenant B Request: Success (Isolation working)")

if __name__ == "__main__":
    try:
        test_rate_limiting_per_tenant()
        print("\nRate Limiting and Isolation test PASSED!")
    except Exception as e:
        print(f"\nTest FAILED: {e}")
        import sys
        sys.exit(1)
