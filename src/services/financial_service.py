"""Financial service — expense management and period summary.

This service was anticipated from Roadmap Phase 8 to Phase 1 because
financial visibility (gross margin, expense tracking) is a baseline
expectation in any market-competitive inventory management SaaS.
"""
import logging
from datetime import date
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from db.orm_models import ExpenseORM, StockMovementORM, ProductORM
from models.entities import ExpenseCategory, ExpenseSchema, FinancialSummarySchema, MovementType

logger = logging.getLogger(__name__)


class FinancialService:

    @staticmethod
    async def create_expense(
        data: ExpenseSchema,
        session: AsyncSession,
    ) -> ExpenseSchema:
        """Persists a new expense record."""
        orm = ExpenseORM(
            tenant_id=data.tenant_id,
            user_id=data.user_id,
            value=data.value,
            category=data.category,
            supplier=data.supplier,
            description=data.description,
            reference_doc=data.reference_doc,
            expense_date=data.expense_date,
        )
        session.add(orm)
        await session.flush()
        logger.info(f"expense_created tenant={data.tenant_id} value={data.value} category={data.category}")
        return data.model_copy(update={"id": orm.id, "created_at": orm.created_at})

    @staticmethod
    async def get_period_summary(
        tenant_id: UUID,
        period_start: date,
        period_end: date,
        session: AsyncSession,
    ) -> FinancialSummarySchema:
        """Generates an aggregated financial summary for the given period.

        Returns:
            - total_expenses broken down by category
            - total stock entry/exit value (quantity-based proxy until unit price is added)
            - gross_margin = total_exits_value - total_expenses
        """
        if period_start > period_end:
            raise HTTPException(status_code=422, detail="period_start must be before period_end")

        # --- Expenses aggregated by category ---
        expense_rows = await session.execute(
            select(ExpenseORM.category, func.sum(ExpenseORM.value).label("total"))
            .where(
                ExpenseORM.tenant_id == tenant_id,
                ExpenseORM.expense_date >= period_start,
                ExpenseORM.expense_date <= period_end,
            )
            .group_by(ExpenseORM.category)
        )
        expenses_by_category: dict[str, float] = {
            row.category.value: round(row.total, 2)
            for row in expense_rows.fetchall()
        }
        total_expenses = round(sum(expenses_by_category.values()), 2)

        # --- Movement values based on Product prices ---
        movement_rows = await session.execute(
            select(
                StockMovementORM.type, 
                func.sum(StockMovementORM.quantity * ProductORM.purchase_price).label("total_cost"),
                func.sum(StockMovementORM.quantity * ProductORM.sale_price).label("total_revenue")
            )
            .join(ProductORM, StockMovementORM.product_id == ProductORM.id)
            .where(
                StockMovementORM.tenant_id == tenant_id,
                func.date(StockMovementORM.created_at) >= period_start,
                func.date(StockMovementORM.created_at) <= period_end,
            )
            .group_by(StockMovementORM.type)
        )
        movements = movement_rows.all()
        
        total_entries_value = 0.0
        total_exits_value = 0.0
        
        for m in movements:
            if m.type == MovementType.ENTRY:
                total_entries_value += float(m.total_cost or 0.0)
            elif m.type == MovementType.EXIT:
                total_exits_value += float(m.total_revenue or 0.0)

        total_entries_value = round(total_entries_value, 2)
        total_exits_value = round(total_exits_value, 2)
        gross_margin = round(total_exits_value - total_expenses, 2)

        logger.info(
            f"financial_summary tenant={tenant_id} "
            f"period={period_start}/{period_end} "
            f"expenses={total_expenses} margin={gross_margin}"
        )

        return FinancialSummarySchema(
            tenant_id=tenant_id,
            period_start=period_start,
            period_end=period_end,
            total_expenses=total_expenses,
            expenses_by_category=expenses_by_category,
            total_entries_value=total_entries_value,
            total_exits_value=total_exits_value,
            gross_margin=gross_margin,
        )
