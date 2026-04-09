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
from models.entities import MovementType


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
                "is_low_stock": total_balance < product.min_stock or product.is_manual_low_stock,
                "is_manual_low_stock": product.is_manual_low_stock,
                "asset_value": total_balance * (product.purchase_price or 0.0),
                "potential_revenue": total_balance * (product.sale_price or 0.0),
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

    @staticmethod
    async def get_financial_dashboard(tenant_id: UUID, session: AsyncSession) -> Dict[str, Any]:
        """Gera KPIs financeiros consolidados (Ouro), cruzando estoque e despesas."""
        from db.orm_models import ExpenseORM
        
        # 1. Total Patrimonial em Estoque
        inventory = await GoldLayerService.get_inventory_summary(tenant_id, session)
        total_assets = sum(item["asset_value"] for item in inventory)
        potential_revenue = sum(item["potential_revenue"] for item in inventory)
        
        # 2. Total de Despesas (Geral)
        expenses_result = await session.execute(
            select(ExpenseORM).where(ExpenseORM.tenant_id == tenant_id)
        )
        expenses_list = expenses_result.scalars().all()
        total_expenses = sum(e.value for e in expenses_list)
        
        # 3. Categorização de Gastos
        cat_map = {}
        for e in expenses_list:
            cat = e.category.value if hasattr(e.category, 'value') else str(e.category)
            cat_map[cat] = cat_map.get(cat, 0.0) + e.value

        return {
            "total_assets": total_assets,
            "potential_revenue": potential_revenue,
            "total_expenses": total_expenses,
            "gross_margin_estimate": potential_revenue - total_assets,
            "expenses_by_category": cat_map,
            "monthly_breakdown": await GoldLayerService._get_monthly_history(tenant_id, session)
        }

    @staticmethod
    async def _get_monthly_history(tenant_id: UUID, session: AsyncSession) -> List[Dict[str, Any]]:
        """Calcula histórico real de movimentações por mês."""
        from sqlalchemy import func, extract
        # Entrada vs Saída por mês com preços reais
        result = await session.execute(
            select(
                extract('month', StockMovementORM.created_at).label('month'),
                func.sum(StockMovementORM.quantity * ProductORM.purchase_price).label('total_cost'),
                func.sum(StockMovementORM.quantity * ProductORM.sale_price).label('total_revenue')
            ).join(ProductORM, StockMovementORM.product_id == ProductORM.id)
            .where(StockMovementORM.tenant_id == tenant_id)
            .group_by('month')
        )
        data = result.all()
        
        months = ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]
        history = {m: {"revenue": 0.0, "cost": 0.0} for m in months}
        
        for row in data:
            m_idx = int(row.month) - 1
            if 0 <= m_idx < 12:
                m_name = months[m_idx]
                history[m_name]["revenue"] = round(float(row.total_revenue or 0.0), 2)
                history[m_name]["cost"] = round(float(row.total_cost or 0.0), 2)
        
        return [{"month": k, **v} for k, v in history.items() if v["revenue"] > 0 or v["cost"] > 0]
