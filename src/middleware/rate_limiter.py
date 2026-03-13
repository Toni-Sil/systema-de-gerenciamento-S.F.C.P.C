from fastapi import Request, HTTPException
from starlette.middleware.base import BaseHTTPMiddleware
from auth.tenant_context import get_tenant_id
import time
from collections import defaultdict
import logging

logger = logging.getLogger(__name__)

class RateLimiterMiddleware(BaseHTTPMiddleware):
    """
    Middleware de Rate Limiting simples por tenant.
    Em produção, deve ser usado Redis (ex: redis-py com conexão na porta 6379). 
    Para o MVP, usamos memória (defaultdict).
    
    # Exemplo Redis:
    # return await redis.get(f"rate_limit:{tenant_id}")
    """
    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.tenant_requests = defaultdict(list)

    async def dispatch(self, request: Request, call_next):
        tenant_id = get_tenant_id()
        
        if tenant_id:
            now = time.time()
            # Limpa requisições antigas (fora da janela de 1 minuto)
            self.tenant_requests[tenant_id] = [
                req_time for req_time in self.tenant_requests[tenant_id]
                if now - req_time < 60
            ]
            
            if len(self.tenant_requests[tenant_id]) >= self.requests_per_minute:
                logger.warning(f"Rate limit exceeded for tenant: {tenant_id}")
                from fastapi.responses import JSONResponse
                return JSONResponse(
                    status_code=429, 
                    content={"detail": "Too many requests for this tenant. Please wait a minute."}
                )
            
            self.tenant_requests[tenant_id].append(now)

        response = await call_next(request)
        return response
