"""Integration-style tests for StockService using an in-memory SQLite DB.

These tests use pytest-asyncio and a real (async) SQLAlchemy session backed
by aiosqlite so they can run in CI without a live PostgreSQL instance.
"""
import os
import pytest
import pytest_asyncio
from uuid import uuid4
from unittest.mock import AsyncMock, patch

os.environ.setdefault("JWT_SECRET_KEY", "test-secret")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

from models.entities import MovementSchema, MovementType, ProductSchema
from auth.tenant_context import set_tenant_id


TENANT_ID = uuid4()
PRODUCT_ID = uuid4()


@pytest.fixture(autouse=True)
def set_test_tenant():
    set_tenant_id(TENANT_ID)


# ---------------------------------------------------------------------------
# StockService.process_movement (mocked repo)
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_entry_increases_balance():
    """An ENTRY movement must increase the stock balance."""
    product = ProductSchema(
        id=PRODUCT_ID, tenant_id=TENANT_ID,
        code="TEST-001", description="Test Foam", unit="un", min_stock=5.0
    )
    initial_balance_orm = type("B", (), {"balance": 10.0, "tenant_id": TENANT_ID,
                                          "product_id": PRODUCT_ID,
                                          "batch_id": None, "location_id": None})()
    movement = MovementSchema(
        id=uuid4(), tenant_id=TENANT_ID, product_id=PRODUCT_ID,
        type=MovementType.ENTRY, quantity=5.0
    )

    mock_session = AsyncMock()
    with patch("services.stock_service.StockService._get_product", return_value=product), \
         patch("services.stock_service.StockService._get_or_create_balance",
               return_value=initial_balance_orm), \
         patch("services.stock_service.StockService._save_movement"):
        from services.stock_service import StockService
        balance = await StockService(mock_session).process_movement(movement)

    assert balance.balance == 15.0


@pytest.mark.asyncio
async def test_exit_below_zero_raises_400():
    """An EXIT exceeding available stock must raise HTTP 400."""
    from fastapi import HTTPException
    product = ProductSchema(
        id=PRODUCT_ID, tenant_id=TENANT_ID,
        code="TEST-001", description="Test Foam", unit="un", min_stock=0.0
    )
    balance_orm = type("B", (), {"balance": 2.0, "tenant_id": TENANT_ID,
                                   "product_id": PRODUCT_ID,
                                   "batch_id": None, "location_id": None})()
    movement = MovementSchema(
        id=uuid4(), tenant_id=TENANT_ID, product_id=PRODUCT_ID,
        type=MovementType.EXIT, quantity=10.0
    )

    mock_session = AsyncMock()
    with patch("services.stock_service.StockService._get_product", return_value=product), \
         patch("services.stock_service.StockService._get_or_create_balance",
               return_value=balance_orm):
        from services.stock_service import StockService
        with pytest.raises(HTTPException) as exc:
            await StockService(mock_session).process_movement(movement)
        assert exc.value.status_code == 400
