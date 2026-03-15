"""Async SQLAlchemy session factory.

Usage::

    async with get_session() as session:
        result = await session.execute(select(MyModel))

Environment variables:
    DATABASE_URL  - e.g. postgresql+asyncpg://user:pass@host:5432/dbname
"""
import os
from contextlib import asynccontextmanager
from typing import AsyncGenerator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

DATABASE_URL = os.getenv("DATABASE_URL")
if not DATABASE_URL:
    raise RuntimeError("DATABASE_URL environment variable must be set.")

engine = create_async_engine(
    DATABASE_URL,
    echo=False,           # Set to True only for local debugging
    pool_size=10,
    max_overflow=20,
    pool_pre_ping=True,   # Drops stale connections before using them
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autoflush=False,
    autocommit=False,
)


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""
    pass


@asynccontextmanager
async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Yields a transactional AsyncSession and rolls back on error."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
