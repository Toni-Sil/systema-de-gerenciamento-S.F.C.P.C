from fastapi import Request
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
import time
from collections import defaultdict
import logging

logger = logging.getLogger(__name__)


class RateLimiterMiddleware(BaseHTTPMiddleware):
    """
    Rate Limiting por tenant_id (extraído do JWT via header X-Tenant-ID já resolvido).

    ATENÇÃO: Esta implementação em memória é adequada apenas para instância única.
    Em produção com múltiplos workers/pods, substitua por Redis:
        await redis.incr(f"rl:{tenant_id}:{window}")
        await redis.expire(f"rl:{tenant_id}:{window}", 60)
    """

    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.tenant_requests: defaultdict[str, list] = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        # Lemos o tenant_id diretamente do header já que o TenantMiddleware
        # seta o contexto ANTES deste middleware ser chamado (ordem importa no add_middleware).
        # Como starlette processa middlewares de baixo para cima na ordem de adição,
        # o RateLimiter extrai o header diretamente para evitar dependência de contexto.
        tenant_id_str = request.headers.get("X-Tenant-ID")
        if not tenant_id_str:
            # Tenta extrair do JWT se presente
            auth = request.headers.get("Authorization", "")
            if auth.startswith("Bearer "):
                try:
                    import jwt
                    from config import get_settings
                    s = get_settings()
                    payload = jwt.decode(auth.split(" ")[1], s.jwt_secret_key, algorithms=[s.jwt_algorithm])
                    tenant_id_str = payload.get("tenant_id")
                except Exception:
                    pass

        if tenant_id_str:
            now = time.time()
            window = self.tenant_requests[tenant_id_str]
            # Remove requisições fora da janela de 60 segundos
            self.tenant_requests[tenant_id_str] = [t for t in window if now - t < 60]

            if len(self.tenant_requests[tenant_id_str]) >= self.requests_per_minute:
                logger.warning(f"[RATE LIMIT] tenant={tenant_id_str} excedeu {self.requests_per_minute} req/min")
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Too Many Requests. Aguarde 1 minuto."},
                    headers={"Retry-After": "60"},
                )

            self.tenant_requests[tenant_id_str].append(now)

        return await call_next(request)
