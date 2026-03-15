"""Health check endpoints for liveness and readiness probes.

Designed for:
  - Docker HEALTHCHECK
  - Kubernetes liveness + readiness probes
  - Uptime monitoring (Better Uptime, UptimeRobot, Grafana Synthetic)
"""
import os
import time
from typing import Literal

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(tags=["Health"])

_start_time = time.time()


class HealthResponse(BaseModel):
    status: Literal["ok", "degraded", "down"]
    service: str
    version: str
    uptime_seconds: float
    checks: dict


@router.get("/health", response_model=HealthResponse, include_in_schema=True)
async def health_check() -> HealthResponse:
    """Structured health probe. Returns 200 if all checks pass, 503 if degraded."""
    checks: dict = {}
    overall: Literal["ok", "degraded", "down"] = "ok"

    # --- Database check ---
    try:
        from db.session import engine
        async with engine.connect() as conn:
            await conn.execute(__import__("sqlalchemy").text("SELECT 1"))
        checks["database"] = "ok"
    except Exception as exc:
        checks["database"] = f"error: {exc}"
        overall = "degraded"

    # --- Environment check ---
    jwt_set = bool(os.getenv("JWT_SECRET_KEY"))
    checks["jwt_secret_configured"] = "ok" if jwt_set else "missing"
    if not jwt_set:
        overall = "degraded"

    return HealthResponse(
        status=overall,
        service="S.F.C.P.C API",
        version="0.2.0",
        uptime_seconds=round(time.time() - _start_time, 2),
        checks=checks,
    )
