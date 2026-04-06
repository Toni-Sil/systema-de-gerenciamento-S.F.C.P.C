"""
PredictiveService — Camada de Inteligência Preditiva (Gold Layer Tier 2).

Usa cálculos estatísticos leves (sem Scikit-learn) para:
- Calcular taxa de consumo diária por produto
- Prever data de ruptura de estoque
- Detectar tendências de custo por categoria
- Gerar score de saúde do estoque (Inventário ABC)
"""
from typing import List, Dict, Any, Optional
from uuid import UUID
from datetime import datetime, timedelta
from collections import defaultdict

from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from db.orm_models import ProductORM, StockBalanceORM, StockMovementORM, ExpenseORM


class PredictiveService:
    """
    Motor de análise preditiva da Gold Layer.
    Alimenta os Dashboards de Decisão sem dependências de ML pesadas.
    """

    @staticmethod
    async def get_stock_health(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> List[Dict[str, Any]]:
        """
        Retorna análise de saúde por produto com previsão de ruptura.
        """
        # 1. Buscar todos produtos e saldos
        products_res = await session.execute(
            select(ProductORM).where(
                ProductORM.tenant_id == tenant_id,
                ProductORM.is_active == True,
            )
        )
        products = products_res.scalars().all()

        balances_res = await session.execute(
            select(StockBalanceORM).where(StockBalanceORM.tenant_id == tenant_id)
        )
        balances = balances_res.scalars().all()
        balance_map = defaultdict(float)
        for b in balances:
            balance_map[b.product_id] += b.balance

        # 2. Calcular consumo médio diário (últimos 30 dias)
        thirty_days_ago = datetime.utcnow() - timedelta(days=30)
        movements_res = await session.execute(
            select(StockMovementORM).where(
                StockMovementORM.tenant_id == tenant_id,
                StockMovementORM.created_at >= thirty_days_ago,
                StockMovementORM.type == "EXIT",
            )
        )
        movements = movements_res.scalars().all()

        daily_consumption: Dict[UUID, float] = defaultdict(float)
        for m in movements:
            daily_consumption[m.product_id] += m.quantity  # total in 30 days

        results = []
        for product in products:
            current_balance = balance_map.get(product.id, 0.0)
            total_exit_30d = daily_consumption.get(product.id, 0.0)
            avg_daily = total_exit_30d / 30.0 if total_exit_30d > 0 else 0.0

            # Dias até ruptura
            days_until_stockout: Optional[float] = None
            if avg_daily > 0 and current_balance > 0:
                days_until_stockout = current_balance / avg_daily

            # Nível de risco
            if days_until_stockout is None:
                risk = "stable"
            elif days_until_stockout <= 5:
                risk = "critical"
            elif days_until_stockout <= 15:
                risk = "warning"
            else:
                risk = "healthy"

            # ABC Classification (pelo volume consumido nos 30 dias)
            abc_class = "C"
            if total_exit_30d > 100:
                abc_class = "A"
            elif total_exit_30d > 30:
                abc_class = "B"

            results.append({
                "product_id": str(product.id),
                "code": product.code,
                "description": product.description,
                "category": product.category.value if product.category else None,
                "current_balance": current_balance,
                "min_stock": product.min_stock,
                "avg_daily_consumption": round(avg_daily, 2),
                "days_until_stockout": round(days_until_stockout, 1) if days_until_stockout is not None else None,
                "risk_level": risk,
                "abc_class": abc_class,
                "total_exit_30d": round(total_exit_30d, 2),
            })

        # Ordenar por risco (critical primeiro)
        risk_order = {"critical": 0, "warning": 1, "stable": 2, "healthy": 3}
        results.sort(key=lambda x: risk_order.get(x["risk_level"], 99))
        return results

    @staticmethod
    async def get_expense_trend(
        tenant_id: UUID,
        session: AsyncSession,
        months: int = 6,
    ) -> List[Dict[str, Any]]:
        """
        Retorna tendência de despesas dos últimos N meses com variação.
        """
        start_date = datetime.utcnow() - timedelta(days=months * 30)
        result = await session.execute(
            select(ExpenseORM).where(
                ExpenseORM.tenant_id == tenant_id,
                ExpenseORM.expense_date >= start_date.date(),
            ).order_by(ExpenseORM.expense_date)
        )
        expenses = result.scalars().all()

        # Agrupar por mês
        by_month: Dict[str, float] = defaultdict(float)
        for e in expenses:
            key = e.expense_date.strftime("%b/%y")
            by_month[key] += e.value

        trend = [{"month": k, "total": round(v, 2)} for k, v in by_month.items()]

        # Calcular variação mês-a-mês
        for i in range(1, len(trend)):
            prev = trend[i - 1]["total"]
            curr = trend[i]["total"]
            trend[i]["change_pct"] = round(((curr - prev) / prev * 100) if prev > 0 else 0, 1)

        if trend:
            trend[0]["change_pct"] = 0.0

        return trend

    @staticmethod
    async def get_summary_kpis(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> Dict[str, Any]:
        """
        KPIs executivos consolidados para o topo do Dashboard.
        """
        health = await PredictiveService.get_stock_health(tenant_id, session)
        expenses = await PredictiveService.get_expense_trend(tenant_id, session, months=1)

        critical_count = sum(1 for h in health if h["risk_level"] == "critical")
        warning_count = sum(1 for h in health if h["risk_level"] == "warning")
        total_products = len(health)
        monthly_spend = expenses[0]["total"] if expenses else 0.0

        return {
            "total_products": total_products,
            "critical_items": critical_count,
            "warning_items": warning_count,
            "monthly_expense": monthly_spend,
            "health_score": round(
                ((total_products - critical_count - warning_count) / total_products * 100)
                if total_products > 0 else 100, 1
            ),
        }
