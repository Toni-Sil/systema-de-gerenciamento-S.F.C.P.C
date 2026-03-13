from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from uuid import UUID
from auth.tenant_context import set_tenant_id
import logging

logger = logging.getLogger(__name__)

class TenantMiddleware(BaseHTTPMiddleware):
    """
    Middleware that extracts the tenant_id from the 'X-Tenant-ID' header
    and sets it in the request context.
    """
    async def dispatch(self, request: Request, call_next):
        auth_header = request.headers.get("Authorization")
        tenant_id_str = None
        
        # 1. Tenta extrair do JWT Token (API Gateway Level Security)
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            try:
                from auth.jwt_handler import SECRET_KEY, ALGORITHM
                import jwt
                payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
                tenant_id_str = payload.get("tenant_id")
            except Exception as e:
                logger.error(f"JWT Validation failed: {e}")
                raise HTTPException(status_code=401, detail="Invalid or expired token")

        # 2. Fallback para X-Tenant-ID (Somente em ambiente de testes/MVP)
        if not tenant_id_str:
            tenant_id_str = request.headers.get("X-Tenant-ID")

        if tenant_id_str:
            try:
                tenant_id = UUID(tenant_id_str)
                set_tenant_id(tenant_id)
                logger.debug(f"Request tenant_id set to: {tenant_id}")
            except ValueError:
                raise HTTPException(status_code=400, detail="Invalid tenant format")
        else:
            # Em produção, rotas sem tenant_id dariam 401, mas para MVP permitimos passar para rotas públicas.
            pass

        response = await call_next(request)
        return response
