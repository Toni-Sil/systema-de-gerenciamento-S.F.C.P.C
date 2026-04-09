"""Refactored StockService Tests — V2.
Uses the current SQLAlchemy mapping and StockService logic.
"""
import pytest
import pytest_asyncio
from uuid import uuid4
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from db.orm_models import Base, ProductORM, StockBalanceORM
from services.stock_service import StockService
from models.entities import MovementSchema, MovementType, ProductCategory

# Use in-memory SQLite for tests
DB_URL = "sqlite+aiosqlite:///:memory:"

@pytest_asyncio.fixture
async def engine():
    engine = create_async_engine(DB_URL)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()

@pytest_asyncio.fixture
async def session(engine):
    AsyncSessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
    async with AsyncSessionLocal() as session:
        yield session

@pytest.mark.asyncio
async def test_process_movement_entry(session):
    tenant_id = uuid4()
    product_id = uuid4()
    
    # Setup: Create product
    new_product = ProductORM(
        id=product_id,
        tenant_id=tenant_id,
        code="TEST-FOAM",
        description="Espuma D33 para Caminhão Scania",
        unit="un",
        category=ProductCategory.FOAM,
        is_active=True
    )
    session.add(new_product)
    await session.commit()

    # Movement: Entry of 10 units
    movement = MovementSchema(
        id=uuid4(),
        tenant_id=tenant_id,
        product_id=product_id,
        type=MovementType.ENTRY,
        quantity=10.0
    )

    # Execute
    balance = await StockService.process_movement(movement, session)
    await session.commit()

    # Verify
    assert balance.balance == 10.0
    
    # Check if a second entry accumulates
    move2 = MovementSchema(
        id=uuid4(),
        tenant_id=tenant_id,
        product_id=product_id,
        type=MovementType.ENTRY,
        quantity=5.5
    )
    balance2 = await StockService.process_movement(move2, session)
    assert balance2.balance == 15.5

@pytest.mark.asyncio
async def test_process_movement_exit_insufficient(session):
    tenant_id = uuid4()
    product_id = uuid4()
    
    # Create product
    new_product = ProductORM(
        id=product_id, tenant_id=tenant_id, code="TEST", description="..", unit="..", is_active=True
    )
    session.add(new_product)
    await session.commit()

    # Try exit of 10 units when balance is 0
    movement = MovementSchema(
        id=uuid4(),
        tenant_id=tenant_id,
        product_id=product_id,
        type=MovementType.EXIT,
        quantity=10.0
    )

    from fastapi import HTTPException
    with pytest.raises(HTTPException) as exc:
        await StockService.process_movement(movement, session)
    assert exc.value.status_code == 400
    assert "Insufficient stock" in exc.value.detail
