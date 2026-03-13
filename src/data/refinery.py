import json
import os
import sys
from typing import List, Dict
from uuid import UUID

# Add src to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../')))

from models.entities import ProductSchema, TenantSchema, ProductCategory

def refine_bronze_to_silver(bronze_path: str, tenant_id: UUID):
    """
    Simulates refining raw JSON data into validated Pydantic models (Silver layer).
    """
    if not os.path.exists(bronze_path):
        print(f"Error: {bronze_path} not found.")
        return []

    with open(bronze_path, 'r') as f:
        raw_data = json.load(f)

    refined_products = []
    print(f"Refining {len(raw_data)} records from {bronze_path}...")

    for record in raw_data:
        try:
            # Rule: Standardize units for sofa-bed logic
            unit = record.get("unit", "UN").upper()
            if unit in ["UNIT", "UNITS", "PIECE", "PIECES", "PECAS"]:
                unit = "UN"
            elif unit in ["METROS", "METERS"]:
                unit = "M"

            category_map = {
                "TECIDOS": ProductCategory.FABRIC,
                "ESPUMAS": ProductCategory.FOAM,
                "MADEIRAS": ProductCategory.WOOD,
                "FERRAGENS": ProductCategory.HARDWARE
            }
            category_str = record.get("category", "").upper()
            category = category_map.get(category_str)

            # Create Pydantic model for validation
            product = ProductSchema(
                tenant_id=tenant_id,
                code=record.get("sku"),
                description=record.get("desc"),
                unit=unit,
                category=category,
                attributes=record.get("attributes")
            )
            refined_products.append(product)
            print(f"  [VALID] {product.code} - {product.description} ({product.unit})")
        except Exception as e:
            print(f"  [INVALID] Record {record.get('sku')}: {e}")

    return refined_products

if __name__ == "__main__":
    # Mock tenant for demonstration
    mock_tenant_id = UUID("12345678-1234-5678-1234-567812345678")
    bronze_file = "data/bronze/initial_stock.json"
    
    refined = refine_bronze_to_silver(bronze_file, mock_tenant_id)
    print(f"\nSuccessfully refined {len(refined)} products to Silver layer.")
