"""Unit tests for JWT handler and password utilities."""
import os
import time
import pytest

os.environ["JWT_SECRET_KEY"] = "test-secret-key-for-pytest-only"
os.environ["DATABASE_URL"] = "postgresql+asyncpg://test:test@localhost/test"

from auth.jwt_handler import create_jwt_token, verify_jwt_token
from auth.password_handler import hash_password, verify_password
from fastapi import HTTPException
from fastapi.security import HTTPAuthorizationCredentials


# ---------------------------------------------------------------------------
# Password
# ---------------------------------------------------------------------------

def test_hash_and_verify_password():
    plain = "S3cur3P@ssword!"
    hashed = hash_password(plain)
    assert hashed != plain
    assert verify_password(plain, hashed)


def test_wrong_password_fails():
    hashed = hash_password("correct")
    assert not verify_password("wrong", hashed)


def test_hash_is_unique_per_call():
    """bcrypt salts must produce different hashes even for the same input."""
    p = "samepassword"
    assert hash_password(p) != hash_password(p)


# ---------------------------------------------------------------------------
# JWT
# ---------------------------------------------------------------------------

def _make_credentials(token: str) -> HTTPAuthorizationCredentials:
    return HTTPAuthorizationCredentials(scheme="Bearer", credentials=token)


def test_create_and_verify_token():
    token = create_jwt_token(tenant_id="tenant-abc", user_id="user-123", role="operator")
    creds = _make_credentials(token)
    payload = verify_jwt_token(creds)
    assert payload["tenant_id"] == "tenant-abc"
    assert payload["user_id"] == "user-123"
    assert payload["role"] == "operator"


def test_expired_token_raises_401(monkeypatch):
    import auth.jwt_handler as jwt_mod
    # Create token that expires in -1 seconds (already expired)
    import jwt, time
    payload = {"tenant_id": "t", "user_id": "u", "exp": time.time() - 1}
    expired_token = jwt.encode(payload, os.environ["JWT_SECRET_KEY"], algorithm="HS256")
    creds = _make_credentials(expired_token)
    with pytest.raises(HTTPException) as exc:
        verify_jwt_token(creds)
    assert exc.value.status_code == 401


def test_invalid_token_raises_401():
    creds = _make_credentials("not.a.valid.token")
    with pytest.raises(HTTPException) as exc:
        verify_jwt_token(creds)
    assert exc.value.status_code == 401
