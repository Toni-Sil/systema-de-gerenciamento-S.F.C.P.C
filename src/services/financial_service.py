"""Financial service: expense CRUD and financial summary (Gold Layer).

Anticipates Phase 8 of the roadmap by delivering core financial reporting
as part of the MVP, aligned with market expectations.
"""
import logging
from datetime import date
from uuid import UUID, uuid4
from datetime import datetime
from typing import List, Optional

from fastapi import HTTPException
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from auth.tenant_context import get_tenant_id
from models.entities import ExpenseSchema, ExpenseCategory, FinancialSummarySchema

logger = logging.getLogger(__name__)


class FinancialService:
    """Manages financial records and reporting per tenant."""

    def __init__(self, session: AsyncSession):
        self.session = session

    def _require_tenant(self) -> UUID:
        tenant_id = get_tenant_id()
        if not tenant_id:
            raise HTTPException(status_code=403, detail="Tenant context missing")
        return tenant_id

    async def create_expense(self, data: ExpenseSchema) -> ExpenseSchema:
        """Persists a new expense record."""
        tenant_id = self._require_tenant()
        if data.tenant_id != tenant_id:
            raise HTTPException(status_code=403, detail="Tenant ID mismatch")

        from db.orm_models import ExpenseORM

        orm = ExpenseORM(
            id=uuid4(),
            tenant_id=tenant_id,
            user_id=data.user_id,
            value=data.value,
            category=data.category,
            supplier=data.supplier,
            description=data.description,
            reference_doc=data.reference_doc,
            expense_date=data.expense_date,
            created_at=datetime.utcnow(),
        )
        self.session.add(orm)
        await self.session.flush()
        logger.info(
            "expense_created",
            extra={
                "tenant_id": str(tenant_id),
                "value": data.value,
                "category": data.category,
            },
        )
        return ExpenseSchema.model_validate(orm)

    async def list_expenses(
        self,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        category: Optional[ExpenseCategory] = None,
        limit: int = 100,
        offset: int = 0,
    ) -> List[ExpenseSchema]:
        """Returns tenant-scoped expenses with optional date/category filters."""
        tenant_id = self._require_tenant()
        from db.orm_models import ExpenseORM

        stmt = select(ExpenseORM).where(ExpenseORM.tenant_id == tenant_id)
        if start_date:
            stmt = stmt.where(ExpenseORM.expense_date >= start_date)
        if end_date:
            stmt = stmt.where(ExpenseORM.expense_date <= end_date)
        if category:
            stmt = stmt.where(ExpenseORM.category == category)
        stmt = stmt.order_by(ExpenseORM.expense_date.desc()).limit(limit).offset(offset)

        result = await self.session.execute(stmt)
        return [ExpenseSchema.model_validate(row) for row in result.scalars().all()]

    async def get_financial_summary(
        self, period_start: date, period_end: date
    ) -> FinancialSummarySchema:
        """Aggregates expenses and computes gross margin for the given period."""
        tenant_id = self._require_tenant()
        from db.orm_models import ExpenseORM, MovementORM

        # --- Total expenses ---
        exp_result = await self.session.execute(
            select(ExpenseORM.category, func.sum(ExpenseORM.value).label("total"))
            .where(
                ExpenseORM.tenant_id == tenant_id,
                ExpenseORM.expense_date >= period_start,
                ExpenseORM.expense_date <= period_end,
            )
            .group_by(ExpenseORM.category)
        )
        expenses_by_category: dict[str, float] = {}
        total_expenses = 0.0
        for row in exp_result:
            expenses_by_category[row.category] = float(row.total)
            total_expenses += float(row.total)

        # --- Movement values (entries vs exits) ---
        # NOTE: Requires unit_value field on MovementORM (added in orm_models).
        mov_result = await self.session.execute(
            select(
                MovementORM.type,
                func.sum(MovementORM.quantity * MovementORM.unit_value).label("total_value"),
            )
            .where(
                MovementORM.tenant_id == tenant_id,
                MovementORM.created_at >= datetime.combine(period_start, datetime.min.time()),
                MovementORM.created_at <= datetime.combine(period_end, datetime.max.time()),
                MovementORM.type.in_(["ENTRY", "EXIT"]),
            )
            .group_by(MovementORM.type)
        )
        total_entries_value = 0.0
        total_exits_value = 0.0
        for row in mov_result:
            if row.type == "ENTRY":
                total_entries_value = float(row.total_value or 0)
            elif row.type == "EXIT":
                total_exits_value = float(row.total_value or 0)

        return FinancialSummarySchema(
            tenant_id=tenant_id,
            period_start=period_start,
            period_end=period_end,
            total_expenses=total_expenses,
            expenses_by_category=expenses_by_category,
            total_entries_value=total_entries_value,
            total_exits_value=total_exits_value,
            gross_margin=total_exits_value - total_expenses,
        )
