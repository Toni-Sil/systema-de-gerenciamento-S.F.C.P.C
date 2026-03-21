from typing import Any, Dict, List
from uuid import UUID

from sqlalchemy import select

from db.orm_models import ProductORM, StockBalanceORM, StockMovementORM
from db.session import get_session


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
        async with get_session() as session:
            product_rows = await session.execute(
                select(ProductORM).where(
                    ProductORM.tenant_id == tenant_id,
                    ProductORM.is_active == True,
                )
            )
            balance_rows = await session.execute(
                select(StockBalanceORM).where(
                    StockBalanceORM.tenant_id == tenant_id,
                )
            )

            products = list(product_rows.scalars().all())
            balances = list(balance_rows.scalars().all())

        balances_by_product: dict[UUID, float] = {}
        for balance in balances:
            balances_by_product[balance.product_id] = (
                balances_by_product.get(balance.product_id, 0.0) + float(balance.balance)
            )

        gold_data = []
        for product in products:
            total_balance = balances_by_product.get(product.id, 0.0)

            gold_data.append({
                "product_id": str(product.id),
                "code": product.code,
                "description": product.description,
                "category": product.category.value if product.category else None,
                "attributes": product.attributes,
                "total_balance": total_balance,
                "min_stock": float(product.min_stock),
                "is_low_stock": total_balance < float(product.min_stock),
            })

        return gold_data

    @staticmethod
    async def get_movement_history(tenant_id: UUID) -> List[Dict[str, Any]]:
        """
        Retorna histórico de movimentações pronto para análise de ML.
        """
        async with get_session() as session:
            rows = await session.execute(
                select(StockMovementORM).where(
                    StockMovementORM.tenant_id == tenant_id,
                )
            )
            movements = list(rows.scalars().all())

        return [
            {
                "id": str(m.id),
                "tenant_id": str(m.tenant_id),
                "product_id": str(m.product_id),
                "user_id": str(m.user_id) if m.user_id else None,
                "batch_id": str(m.batch_id) if m.batch_id else None,
                "location_id": str(m.location_id) if m.location_id else None,
                "type": m.type.value,
                "quantity": float(m.quantity),
                "reference_doc": m.reference_doc,
                "notes": m.notes,
                "created_at": m.created_at.isoformat(),
            }
            for m in movements
        ]
