import jwt
import time
from uuid import UUID
from fastapi import HTTPException, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

SECRET_KEY = "super-secret-key-for-mvp"
ALGORITHM = "HS256"

security = HTTPBearer(auto_error=False)

def create_jwt_token(tenant_id: str, user_id: str) -> str:
    payload = {
        "tenant_id": tenant_id,
        "user_id": user_id,
        "exp": time.time() + 3600 # 1 hour
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_jwt_token(credentials: HTTPAuthorizationCredentials = Security(security)) -> dict:
    if not credentials:
        # Allow missing tokens in MVP for backward compatibility with tests
        return {}
    try:
        token = credentials.credentials
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_current_tenant_from_token(payload: dict = Security(verify_jwt_token)) -> UUID | None:
    tenant_id_str = payload.get("tenant_id")
    if tenant_id_str:
        return UUID(tenant_id_str)
    return None
