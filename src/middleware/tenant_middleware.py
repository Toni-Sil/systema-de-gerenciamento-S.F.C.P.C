import logging
import jwt
from uuid import UUID
from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from auth.tenant_context import set_tenant_id
from config import get_settings

logger = logging.getLogger(__name__)
settings = get_settings()

PUBLIC_PATHS = {"/", "/docs", "/openapi.json", "/redoc", "/auth/token", "/health"}


class TenantMiddleware(BaseHTTPMiddleware):
    """
    Middleware que extrai o tenant_id do Bearer JWT e o define no contexto da requisição.
    Rotas públicas definidas em PUBLIC_PATHS são isentas de autenticação.
    """

    async def dispatch(self, request: Request, call_next):
        if request.url.path in PUBLIC_PATHS:
            return await call_next(request)

        auth_header = request.headers.get("Authorization", "")
        tenant_id_str: str | None = None

        if auth_header.startswith("Bearer "):
            token = auth_header.split(" ")[1]
            try:
                payload = jwt.decode(
                    token,
                    settings.jwt_secret_key,
                    algorithms=[settings.jwt_algorithm],
                )
                tenant_id_str = payload.get("tenant_id")
            except jwt.ExpiredSignatureError:
                return JSONResponse(status_code=401, content={"detail": "Token expirado."})
            except jwt.InvalidTokenError:
                return JSONResponse(status_code=401, content={"detail": "Token inválido."})

        # Fallback: X-Tenant-ID somente em ambiente de desenvolvimento
        if not tenant_id_str and settings.environment == "development":
            tenant_id_str = request.headers.get("X-Tenant-ID")

        if not tenant_id_str:
            return JSONResponse(status_code=401, content={"detail": "Autenticação requerida."})

        try:
            set_tenant_id(UUID(tenant_id_str))
            logger.debug(f"[TENANT] tenant_id={tenant_id_str} path={request.url.path}")
        except ValueError:
            return JSONResponse(status_code=400, content={"detail": "Formato de tenant_id inválido (deve ser UUID)."})

        return await call_next(request)
