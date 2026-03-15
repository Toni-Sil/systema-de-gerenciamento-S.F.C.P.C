"""Prometheus metrics instrumentation for FastAPI.

Exposes:
  GET /metrics  — Prometheus scrape endpoint
  GET /health   — Structured liveness + readiness probe (for Kubernetes/Docker)

Metrics collected automatically by prometheus-fastapi-instrumentator:
  - http_requests_total (method, handler, status)
  - http_request_duration_seconds (latency histogram)
  - http_requests_in_progress (gauge)

Custom metrics added here:
  - sfcpc_stock_movements_total (counter, by tenant + type)
  - sfcpc_active_tenants (gauge)
"""
from prometheus_client import Counter, Gauge
from prometheus_fastapi_instrumentator import Instrumentator
from fastapi import FastAPI
import logging

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Custom business metrics
# ---------------------------------------------------------------------------

STOCK_MOVEMENTS_TOTAL = Counter(
    name="sfcpc_stock_movements_total",
    documentation="Total stock movements processed, partitioned by tenant and type.",
    labelnames=["tenant_id", "movement_type"],
)

ACTIVE_TENANTS = Gauge(
    name="sfcpc_active_tenants",
    documentation="Number of tenants that have made at least one request in the last 5 minutes.",
)

FINANCIAL_EXPENSES_TOTAL = Counter(
    name="sfcpc_financial_expenses_total",
    documentation="Total expense value registered, partitioned by tenant and category.",
    labelnames=["tenant_id", "category"],
)


def record_movement(tenant_id: str, movement_type: str) -> None:
    """Increment the stock movement counter. Call from StockService."""
    STOCK_MOVEMENTS_TOTAL.labels(
        tenant_id=tenant_id,
        movement_type=movement_type,
    ).inc()


def record_expense(tenant_id: str, category: str, value: float) -> None:
    """Increment the expense value counter. Call from FinancialService."""
    FINANCIAL_EXPENSES_TOTAL.labels(
        tenant_id=tenant_id,
        category=category,
    ).inc(value)


# ---------------------------------------------------------------------------
# Instrumentator setup
# ---------------------------------------------------------------------------

def setup_metrics(app: FastAPI) -> None:
    """Attach Prometheus instrumentation to the FastAPI app.

    Call this once during app startup, after all routes are registered.

    Usage in main.py::

        from observability import setup_metrics
        setup_metrics(app)
    """
    Instrumentator(
        should_group_status_codes=False,
        should_ignore_untemplated=True,
        excluded_handlers=["/metrics", "/health", "/docs", "/redoc", "/openapi.json"],
    ).instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)

    logger.info("Prometheus metrics exposed at /metrics")
