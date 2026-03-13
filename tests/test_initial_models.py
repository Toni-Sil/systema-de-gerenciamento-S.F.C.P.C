import sys
import os
from uuid import uuid4

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../src')))

from models.entities import TenantSchema, ProductSchema, MovementSchema, MovementType, ProductCategory

def test_pydantic_models():
    print("Testing Pydantic models...")
    
    # Test Tenant
    tenant = TenantSchema(name="Test Tenant", slug="test-tenant")
    print(f"Created Tenant: {tenant.name} (ID: {tenant.id})")
    
    # Test Product
    product = ProductSchema(
        tenant_id=tenant.id,
        code="PROD-001",
        description="Test Product",
        unit="UN",
        category=ProductCategory.FABRIC
    )
    print(f"Created Product: {product.code}")
    
    # Test Movement
    movement = MovementSchema(
        tenant_id=tenant.id,
        product_id=product.id,
        type=MovementType.ENTRY,
        quantity=10.0,
        notes="Initial stock"
    )
    print(f"Created Movement: {movement.type} of {movement.quantity}")
    
    print("All basic model tests passed!")

if __name__ == "__main__":
    test_pydantic_models()
