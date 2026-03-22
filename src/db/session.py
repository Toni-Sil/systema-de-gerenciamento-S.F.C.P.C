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

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

_engine: AsyncEngine | None = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_database_url() -> str:
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL environment variable must be set.")
    return database_url


def get_engine() -> AsyncEngine:
    global _engine
    if _engine is None:
        database_url = get_database_url()
        try:
            _engine = create_async_engine(
                database_url,
                echo=False,           # Set to True only for local debugging
                pool_pre_ping=True,   # Drops stale connections before using them
                **(
                    {"pool_size": 10, "max_overflow": 20}
                    if not database_url.startswith("sqlite")
                    else {}
                ),
            )
        except ModuleNotFoundError as exc:
            raise RuntimeError(
                "Database driver dependency is missing for DATABASE_URL. "
                "Install the configured async driver before opening DB sessions."
            ) from exc
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(
            bind=get_engine(),
            class_=AsyncSession,
            expire_on_commit=False,
            autoflush=False,
            autocommit=False,
        )
    return _session_factory


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""
    pass


@asynccontextmanager
async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """Yields a transactional AsyncSession and rolls back on error."""
    async with get_session_factory()() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
