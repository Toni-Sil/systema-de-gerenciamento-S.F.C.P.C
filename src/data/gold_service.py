import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../')))

from typing import List, Dict, Any
from uuid import UUID
from models.entities import StockBalanceSchema, ProductSchema, MovementSchema
from services.stock_service import product_repo, balance_repo, movement_repo

class GoldLayerService:
    """
    Serviço que consolida dados da Silver Layer para a Gold Layer.
    Focado em fornecer dados limpos para IA e Dashboards.
    """
    
    @staticmethod
    async def get_inventory_summary(tenant_id: UUID) -> List[Dict[str, Any]]:
        """
        Gera um resumo do inventário (Gold) cruzando produtos com saldos.
        """
        products = await product_repo.get_all()
        balances = await balance_repo.get_all()
        
        gold_data = []
        for product in products:
            # Filtra saldos deste produto
            prod_balances = [b for b in balances if b.product_id == product.id]
            total_balance = sum(b.balance for b in prod_balances)
            
            gold_data.append({
                "product_id": str(product.id),
                "code": product.code,
                "description": product.description,
                "category": product.category,
                "attributes": product.attributes.model_dump() if product.attributes else None,
                "total_balance": total_balance,
                "min_stock": product.min_stock,
                "is_low_stock": total_balance < product.min_stock
            })
            
        return gold_data

    @staticmethod
    async def get_movement_history(tenant_id: UUID) -> List[Dict[str, Any]]:
        """
        Retorna histórico de movimentações pronto para análise de ML.
        """
        movements = await movement_repo.get_all()
        return [m.model_dump() for m in movements]
