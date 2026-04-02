"""Gold Layer Service — consolida dados reais do banco para IA e Dashboards.

Corrige:
- Uso de repos in-memory obsoletos substituídos por queries SQLAlchemy reais
- tenant_id agora é obrigatório e aplicado em todas as queries
- Assinatura atualizada: get_inventory_summary(tenant_id, session)
                         get_movement_history(tenant_id, session)
"""
from typing import List, Dict, Any
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.orm_models import ProductORM, StockBalanceORM, StockMovementORM


class GoldLayerService:
    """
    Serviço que consolida dados da Silver Layer para a Gold Layer.
    Focado em fornecer dados limpos para IA e Dashboards.
    """

    @staticmethod
    async def get_inventory_summary(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> List[Dict[str, Any]]:
        """
        Gera resumo do inventário (Gold) cruzando produtos com saldos reais do banco.
        Filtra obrigatoriamente pelo tenant_id.
        """
        # Busca todos os produtos ativos do tenant
        products_result = await session.execute(
            select(ProductORM).where(
                ProductORM.tenant_id == tenant_id,
                ProductORM.is_active == True,
            )
        )
        products = products_result.scalars().all()

        # Busca todos os saldos do tenant
        balances_result = await session.execute(
            select(StockBalanceORM).where(
                StockBalanceORM.tenant_id == tenant_id,
            )
        )
        balances = balances_result.scalars().all()

        # Indexa saldos por product_id para lookup O(1)
        balance_map: Dict[UUID, float] = {}
        for b in balances:
            balance_map[b.product_id] = balance_map.get(b.product_id, 0.0) + b.balance

        gold_data = []
        for product in products:
            total_balance = balance_map.get(product.id, 0.0)
            gold_data.append({
                "product_id": str(product.id),
                "code": product.code,
                "description": product.description,
                "category": product.category.value if product.category else None,
                "attributes": product.attributes,
                "total_balance": total_balance,
                "min_stock": product.min_stock,
                "is_low_stock": total_balance < product.min_stock,
            })

        return gold_data

    @staticmethod
    async def get_movement_history(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> List[Dict[str, Any]]:
        """
        Retorna histórico de movimentações reais do tenant para análise de ML.
        """
        result = await session.execute(
            select(StockMovementORM)
            .where(StockMovementORM.tenant_id == tenant_id)
            .order_by(StockMovementORM.created_at.desc())
            .limit(1000)  # Limita para não sobrecarregar memória em análises
        )
        movements = result.scalars().all()

        return [
            {
                "id": str(m.id),
                "product_id": str(m.product_id),
                "type": m.type.value,
                "quantity": m.quantity,
                "created_at": m.created_at.isoformat(),
                "location_id": str(m.location_id) if m.location_id else None,
                "batch_id": str(m.batch_id) if m.batch_id else None,
                "reference_doc": m.reference_doc,
                "notes": m.notes,
            }
            for m in movements
        ]
