"""Shared pytest fixtures."""
import os
import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

# Set required env vars BEFORE importing the app
os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-pytest-only")
os.environ.setdefault("DATABASE_URL", "sqlite+aiosqlite:///./test.db")

from src.main import app  # noqa: E402


@pytest_asyncio.fixture
async def client():
    """Async test client that bypasses network layer."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://testserver",
    ) as ac:
        yield ac


@pytest.fixture
def tenant_id() -> str:
    return "00000000-0000-0000-0000-000000000001"


@pytest.fixture
def auth_headers(tenant_id):
    """Returns a valid Authorization header for the test tenant."""
    from src.auth.jwt_handler import create_jwt_token
    token = create_jwt_token(tenant_id=tenant_id, user_id="test-user", role="admin")
    return {"Authorization": f"Bearer {token}"}
