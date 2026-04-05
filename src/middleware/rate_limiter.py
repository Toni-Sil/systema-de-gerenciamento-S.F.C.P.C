import asyncio
import logging
import time
from collections import defaultdict

from fastapi import Request
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.responses import JSONResponse

from auth.tenant_context import get_tenant_id

logger = logging.getLogger(__name__)


class RateLimiterMiddleware(BaseHTTPMiddleware):
    """
    Per-tenant sliding-window rate limiter.

    Production note: replace the in-memory defaultdict with a Redis backend
    (redis-py asyncio) so limits are shared across multiple worker processes/pods.

    Example Redis replacement::

        async def _is_rate_limited(self, key: str) -> bool:
            pipe = self.redis.pipeline()
            now = time.time()
            pipe.zremrangebyscore(key, 0, now - 60)
            pipe.zadd(key, {str(now): now})
            pipe.zcard(key)
            pipe.expire(key, 60)
            _, _, count, _ = await pipe.execute()
            return count > self.requests_per_minute
    """

    def __init__(self, app, requests_per_minute: int = 60):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self._storage: defaultdict[str, list[float]] = defaultdict(list)
        # asyncio.Lock per tenant to prevent race conditions in async context
        self._locks: defaultdict[str, asyncio.Lock] = defaultdict(asyncio.Lock)

    async def dispatch(self, request: Request, call_next):
        tenant_id = get_tenant_id()

        if tenant_id is None or request.method == "OPTIONS":
            return await call_next(request)

        key = str(tenant_id)
        async with self._locks[key]:
            now = time.time()
            window_start = now - 60.0
            # Prune timestamps outside the sliding window
            self._storage[key] = [
                ts for ts in self._storage[key] if ts > window_start
            ]

            if len(self._storage[key]) >= self.requests_per_minute:
                logger.warning(
                    "rate_limit_exceeded",
                    extra={"tenant_id": key, "path": request.url.path},
                )
                return JSONResponse(
                    status_code=429,
                    content={
                        "detail": "Too many requests. Please retry after 60 seconds.",
                        "tenant_id": key,
                    },
                    headers={"Retry-After": "60"},
                )

            self._storage[key].append(now)

        return await call_next(request)
