from typing import Optional, Dict, Any
from uuid import UUID
import json
from sqlalchemy.ext.asyncio import AsyncSession
from models.entities import MovementType
from services.stock_service import StockService
from db.orm_models import ProductORM
from sqlalchemy import select
from data.gold_service import GoldLayerService

class LLMTools:
    """Ferramentas (Functions) que o LLM poderá acionar para interagir com o SFC-PC."""
    
    @staticmethod
    async def record_movement(tenant_id: UUID, product_code: str, type: str, quantity: float, session: AsyncSession) -> str:
        """
        Registra uma movimentação de estoque (entrada ou saída).
        """
        try:
            # Buscar produto pelo código
            result = await session.execute(
                select(ProductORM).where(
                    ProductORM.code == product_code,
                    ProductORM.tenant_id == tenant_id,
                    ProductORM.is_active == True
                )
            )
            target_product = result.scalar_one_or_none()
            
            if not target_product:
                return json.dumps({"status": "error", "message": f"Produto com código {product_code} não encontrado no sistema."})
            
            # Registrar
            mov_type = MovementType.ENTRY if type.upper() == "ENTRY" else MovementType.EXIT
            from models.entities import MovementSchema
            import uuid
            
            movement = MovementSchema(
                id=uuid.uuid4(),
                tenant_id=tenant_id,
                product_id=target_product.id,
                type=mov_type,
                quantity=quantity,
                location_id=None,
                batch_id=None
            )

            balance_obj = await StockService.process_movement(movement, session)
            return json.dumps({
                "status": "success", 
                "message": "Movimentação registrada com sucesso.",
                "new_balance": balance_obj.balance
            })
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    @staticmethod
    async def get_inventory_status(tenant_id: UUID, session: AsyncSession) -> str:
        """
        Retorna o resumo da inteligência do estoque atual (Gold Layer).
        """
        try:
            summary = await GoldLayerService.get_inventory_summary(tenant_id, session)
            return json.dumps({"status": "success", "data": summary})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

