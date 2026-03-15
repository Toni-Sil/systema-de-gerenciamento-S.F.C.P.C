"""Unit tests for FinancialService."""
import os
import pytest
from uuid import uuid4
from datetime import date
from unittest.mock import AsyncMock, MagicMock, patch

os.environ.setdefault("JWT_SECRET_KEY", "test-secret")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from models.entities import ExpenseSchema, ExpenseCategory
from auth.tenant_context import set_tenant_id

TENANT_ID = uuid4()


@pytest.fixture(autouse=True)
def set_test_tenant():
    set_tenant_id(TENANT_ID)


@pytest.mark.asyncio
async def test_create_expense_persists():
    """create_expense should call session.add and session.flush."""
    expense = ExpenseSchema(
        tenant_id=TENANT_ID,
        value=1500.0,
        category=ExpenseCategory.RAW_MATERIAL,
        supplier="TECIDOS FINOS LTDA",
        expense_date=date(2026, 3, 15),
    )

    mock_session = AsyncMock()
    mock_orm = MagicMock()

    with patch("services.financial_service.ExpenseORM", return_value=mock_orm), \
         patch("models.entities.ExpenseSchema.model_validate", return_value=expense):
        from services.financial_service import FinancialService
        result = await FinancialService(mock_session).create_expense(expense)

    mock_session.add.assert_called_once_with(mock_orm)
    mock_session.flush.assert_called_once()
    assert result.value == 1500.0


@pytest.mark.asyncio
async def test_tenant_mismatch_raises_403():
    """Expense with a different tenant_id must raise HTTP 403."""
    from fastapi import HTTPException
    other_tenant = uuid4()
    expense = ExpenseSchema(
        tenant_id=other_tenant,  # different from current tenant context
        value=200.0,
        category=ExpenseCategory.LOGISTICS,
        expense_date=date(2026, 3, 15),
    )

    from services.financial_service import FinancialService
    with pytest.raises(HTTPException) as exc:
        await FinancialService(AsyncMock()).create_expense(expense)
    assert exc.value.status_code == 403
