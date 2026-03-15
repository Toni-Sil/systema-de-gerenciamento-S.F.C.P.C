"""Tests for authentication endpoints."""
import pytest


@pytest.mark.asyncio
async def test_root_returns_ok(client):
    response = await client.get("/")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


@pytest.mark.asyncio
async def test_protected_route_without_token_returns_401(client):
    """All protected routes must reject requests without a Bearer token."""
    response = await client.get("/products")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_route_with_invalid_token_returns_401(client):
    response = await client.get(
        "/products",
        headers={"Authorization": "Bearer invalid.token.here"},
    )
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_route_with_valid_token_passes(client, auth_headers):
    """A valid JWT should allow access to protected routes."""
    response = await client.get("/products", headers=auth_headers)
    # 200 or 500 (DB not configured in unit test) — but NOT 401/403
    assert response.status_code not in (401, 403)
