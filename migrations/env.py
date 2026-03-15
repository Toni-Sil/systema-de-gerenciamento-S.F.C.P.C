"""Alembic environment — async-compatible with SQLAlchemy 2.x."""
import asyncio
import os
from logging.config import fileConfig

from alembic import context
from sqlalchemy.ext.asyncio import create_async_engine

# Load all ORM models so Alembic can detect them
import sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

from db.orm_models import (  # noqa: F401 — side-effect import registers metadata
    Base,
    TenantORM,
    UserORM,
    ProductORM,
    LocationORM,
    BatchORM,
    StockBalanceORM,
    StockMovementORM,
    ExpenseORM,
)

config = context.config
if config.config_file_name:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata

DATABASE_URL = os.environ["DATABASE_URL"]


def run_migrations_offline() -> None:
    """Run migrations without a live DB connection (generates SQL script)."""
    context.configure(
        url=DATABASE_URL,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    """Run migrations against a live DB using async engine."""
    connectable = create_async_engine(DATABASE_URL, echo=False)
    async with connectable.connect() as connection:
        await connection.run_sync(
            lambda conn: context.configure(
                connection=conn,
                target_metadata=target_metadata,
                compare_type=True,
            )
        )
        await connection.run_sync(lambda conn: context.run_migrations())
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
