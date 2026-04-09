import jwt
import time
import os
from uuid import UUID
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import logging

logger = logging.getLogger(__name__)

# SECURITY: Never hardcode secrets. Load from environment variables.
# Set SECRET_KEY in your .env file. A safe default is only used for local dev.
SECRET_KEY = os.getenv("JWT_SECRET_KEY")
if not SECRET_KEY:
    logger.critical(
        "CRITICAL: JWT_SECRET_KEY environment variable is not set. "
        "This is a severe security risk. Set it before deploying."
    )
    raise RuntimeError("JWT_SECRET_KEY must be set as an environment variable.")

ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_SECONDS = int(os.getenv("ACCESS_TOKEN_EXPIRE_SECONDS", 3600))

security = HTTPBearer(auto_error=True)


def create_jwt_token(tenant_id: str, user_id: str, role: str = "operator") -> str:
    """Creates a signed JWT with tenant, user, and role claims."""
    now = time.time()
    payload = {
        "tenant_id": tenant_id,
        "user_id": user_id,
        "role": role,
        "iat": now,
        "exp": now + ACCESS_TOKEN_EXPIRE_SECONDS,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def verify_jwt_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    """Decodes and validates a JWT. Raises 401 on any failure."""
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        logger.warning("JWT token expired")
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as exc:
        logger.warning(f"Invalid JWT token: {exc}")
        raise HTTPException(status_code=401, detail="Invalid token")


def get_current_tenant_from_token(
    payload: dict = Security(verify_jwt_token),
) -> UUID:
    """Extracts and returns the tenant UUID from a verified JWT payload."""
    tenant_id_str = payload.get("tenant_id")
    if not tenant_id_str:
        raise HTTPException(status_code=403, detail="tenant_id missing from token")
    try:
        return UUID(tenant_id_str)
    except ValueError:
        raise HTTPException(status_code=403, detail="Malformed tenant_id in token")


def verify_admin(payload: dict = Security(verify_jwt_token)) -> dict:
    """Dependency to restrict access to ADMIN users only."""
    if payload.get("role") != "admin":
        logger.warning(f"Unauthorized access attempt by user {payload.get('user_id')} with role {payload.get('role')}")
        raise HTTPException(status_code=403, detail="Apenas administradores podem realizar esta ação.")
    return payload
