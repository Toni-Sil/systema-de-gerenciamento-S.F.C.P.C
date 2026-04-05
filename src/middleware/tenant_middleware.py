import logging
import uuid
from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse
from auth.tenant_context import set_tenant_id

logger = logging.getLogger(__name__)

# Routes that are explicitly public (no tenant context required)
_PUBLIC_PATHS = {"/", "/auth/token", "/docs", "/openapi.json", "/redoc"}


class TenantMiddleware(BaseHTTPMiddleware):
    """
    Extracts tenant_id from a verified JWT Bearer token and sets it in the
    async-safe request context (ContextVar).

    Security improvements over previous version:
    - Removed the insecure X-Tenant-ID header fallback (header spoofing vector).
    - Requests without a valid token to protected routes now return 401 immediately.
    - Injects a unique X-Request-ID into each request for distributed tracing.
    """

    async def dispatch(self, request: Request, call_next):
        # Inject a unique request ID for distributed tracing (logs, ELK, Grafana)
        request_id = str(uuid.uuid4())
        request.state.request_id = request_id

        if request.url.path in _PUBLIC_PATHS or request.method == "OPTIONS":
            response = await call_next(request)
            response.headers["X-Request-ID"] = request_id
            return response


        auth_header = request.headers.get("Authorization")

        if not auth_header or not auth_header.startswith("Bearer "):
            return JSONResponse(
                status_code=401,
                content={"detail": "Authorization header missing or malformed"},
                headers={"X-Request-ID": request_id},
            )

        token = auth_header.split(" ", 1)[1]
        try:
            from auth.jwt_handler import SECRET_KEY, ALGORITHM
            import jwt

            payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
            from uuid import UUID

            tenant_id_str = payload.get("tenant_id")
            if not tenant_id_str:
                raise ValueError("tenant_id missing from token payload")

            tenant_id = UUID(tenant_id_str)
            set_tenant_id(tenant_id)

            logger.info(
                "request_start",
                extra={
                    "request_id": request_id,
                    "tenant_id": str(tenant_id),
                    "path": request.url.path,
                    "method": request.method,
                },
            )
        except Exception as exc:
            logger.warning(f"Tenant auth failed [{request_id}]: {exc}")
            return JSONResponse(
                status_code=401,
                content={"detail": "Invalid or expired token"},
                headers={"X-Request-ID": request_id},
            )

        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
