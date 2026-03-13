import jwt
import time
from uuid import UUID
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from config import get_settings

settings = get_settings()
security = HTTPBearer(auto_error=True)  # auto_error=True: retorna 403 automaticamente se sem token


def create_jwt_token(tenant_id: str, user_id: str) -> str:
    payload = {
        "tenant_id": tenant_id,
        "user_id": user_id,
        "exp": time.time() + settings.jwt_expiry_seconds,
        "iat": time.time(),
    }
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def verify_jwt_token(
    credentials: HTTPAuthorizationCredentials = Security(security),
) -> dict:
    """
    Valida o Bearer token JWT.
    Lança HTTP 401 se ausente, expirado ou inválido.
    """
    try:
        token = credentials.credentials
        payload = jwt.decode(
            token,
            settings.jwt_secret_key,
            algorithms=[settings.jwt_algorithm],
        )
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expirado.")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Token inválido.")


def get_current_tenant_from_token(
    payload: dict = Security(verify_jwt_token),
) -> UUID:
    tenant_id_str = payload.get("tenant_id")
    if not tenant_id_str:
        raise HTTPException(status_code=403, detail="tenant_id ausente no token.")
    return UUID(tenant_id_str)
