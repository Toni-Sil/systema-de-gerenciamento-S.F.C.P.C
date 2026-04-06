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


class FinancialTools:
    """Ferramentas de IA para o módulo financeiro."""

    @staticmethod
    async def register_expense(
        tenant_id: UUID, 
        value: float, 
        supplier: str, 
        session: AsyncSession
    ) -> str:
        """
        Registra uma despesa financeira vinculada ao tenant.
        """
        try:
            from db.orm_models import ExpenseORM
            from models.entities import ExpenseCategory
            from datetime import date

            expense = ExpenseORM(
                tenant_id=tenant_id,
                value=value,
                supplier=supplier,
                category=ExpenseCategory.OTHER,
                expense_date=date.today(),
            )
            session.add(expense)
            await session.commit()

            # Emitir evento para o consumidor financeiro
            from messaging.event_bus import event_bus
            await event_bus.publish(
                topic="finance.expense.created",
                data={
                    "value": value,
                    "supplier": supplier,
                    "expense_date": str(date.today()),
                },
                tenant_id=str(tenant_id),
            )

            return json.dumps({
                "status": "success", 
                "message": f"Despesa de R$ {value} (Fornecedor: {supplier}) registrada com sucesso."
            })
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})


class ServiceOrderTools:
    """Ferramentas para integração com o sistema externo de Ordem de Serviço."""

    @staticmethod
    async def create_client(
        tenant_id: UUID,
        name: str,
        phone: str,
        session: AsyncSession,
        email: str = "",
        address: str = ""
    ) -> str:
        """Cria um cliente no sistema de OS externo."""
        from services.service_order_service import ServiceOrderService
        res = await ServiceOrderService.create_client(tenant_id, session, name, phone, email, address)
        return json.dumps(res)

    @staticmethod
    async def create_order(
        tenant_id: UUID,
        client_id: str,
        description: str,
        session: AsyncSession,
        priority: str = "normal",
        furniture_type: str = "sofa",
        fabric: str = ""
    ) -> str:
        """Cria uma Ordem de Serviço vinculada a um cliente específico."""
        from services.service_order_service import ServiceOrderService
        res = await ServiceOrderService.create_order(
            tenant_id, session, client_id, description, priority, furniture_type, fabric
        )
        return json.dumps(res)
