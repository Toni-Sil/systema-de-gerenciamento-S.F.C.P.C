"""Focused tests for the JWT handler implementation."""
import os
import time

import pytest
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from jose import jwt

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-pytest-only")

from src.auth.jwt_handler import ALGORITHM, SECRET_KEY, create_jwt_token, verify_jwt_token


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
