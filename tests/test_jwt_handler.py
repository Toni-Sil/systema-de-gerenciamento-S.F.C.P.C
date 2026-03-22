"""Focused tests for the JWT handler implementation."""
import os
import time

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from jose import jwt
from unittest.mock import AsyncMock

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-pytest-only")

from src.auth.jwt_handler import ALGORITHM, SECRET_KEY, create_jwt_token, verify_jwt_token
from src.services.user_service import UserService


def _credentials(token: str) -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def test_create_and_verify_jwt_token_round_trip():
    token = create_jwt_token(
        tenant_id="00000000-0000-0000-0000-000000000001",
        user_id="user-123",
        role="admin",
    )

    payload = verify_jwt_token(_credentials(token))

    assert payload["tenant_id"] == "00000000-0000-0000-0000-000000000001"
    assert payload["user_id"] == "user-123"
    assert payload["role"] == "admin"


def test_verify_jwt_token_rejects_expired_token():
    now = time.time()
    token = jwt.encode(
        {
            "tenant_id": "00000000-0000-0000-0000-000000000001",
            "user_id": "user-123",
            "role": "operator",
            "iat": now - 10,
            "exp": now - 1,
        },
        SECRET_KEY,
        algorithm=ALGORITHM,
    )

    with pytest.raises(HTTPException) as exc:
        verify_jwt_token(_credentials(token))

    assert exc.value.status_code == 401
    assert exc.value.detail == "Token has expired"


@pytest.mark.asyncio
async def test_user_service_authenticate_accepts_email_without_tenant_when_unique(monkeypatch):
    class _ScalarResult:
        def __init__(self, rows):
            self._rows = rows

        def scalars(self):
            return self

        def all(self):
            return self._rows

        def scalar_one_or_none(self):
            return self._rows[0] if self._rows else None

    user = type(
        "User",
        (),
        {
            "id": "user-1",
            "tenant_id": "tenant-1",
            "username": "alice",
            "email": "alice@example.com",
            "hashed_password": "hashed",
            "role": type("Role", (), {"value": "admin"})(),
        },
    )()

    session = AsyncMock()
    session.execute.return_value = _ScalarResult([user])
    monkeypatch.setattr("src.services.user_service.verify_password", lambda plain, hashed: True)
    monkeypatch.setattr(
        "src.services.user_service.create_jwt_token",
        lambda tenant_id, user_id, role: f"token:{tenant_id}:{user_id}:{role}",
    )

    response = await UserService.authenticate(
        tenant_id=None,
        username=None,
        email="alice@example.com",
        plain_password="secret123",
        session=session,
    )

    assert response["access_token"] == "token:tenant-1:user-1:admin"


@pytest.mark.asyncio
async def test_user_service_authenticate_requires_tenant_for_duplicated_email(monkeypatch):
    class _ScalarResult:
        def __init__(self, rows):
            self._rows = rows

        def scalars(self):
            return self

        def all(self):
            return self._rows

    session = AsyncMock()
    session.execute.return_value = _ScalarResult([object(), object()])

    with pytest.raises(HTTPException) as exc:
        await UserService.authenticate(
            tenant_id=None,
            username=None,
            email="shared@example.com",
            plain_password="secret123",
            session=session,
        )

    assert exc.value.status_code == 400
    assert "Multiple tenants" in exc.value.detail
