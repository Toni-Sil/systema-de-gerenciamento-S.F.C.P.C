"""S.F.C.P.C - Systema de Gerenciamento API

Architecture decisions in this file:
  - All routes requiring DB access receive an AsyncSession via FastAPI Depends.
  - All routes except /auth/* are protected by JWT (verify_jwt_token dependency).
  - Routes are grouped into APIRouters for modularity and versioning readiness.
  - Lifespan handles startup/shutdown (Kafka worker, DB engine warm-up).
"""
from contextlib import asynccontextmanager
from datetime import date
from typing import List, Optional
from uuid import UUID

from fastapi import FastAPI, Depends, UploadFile, File, Form, HTTPException
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession
import json

from auth.jwt_handler import verify_jwt_token
from auth.tenant_context import get_tenant_id
from db.session import get_session
from messaging.producer import producer
from middleware.tenant_middleware import TenantMiddleware
from middleware.rate_limiter import RateLimiterMiddleware
from models.entities import (
    ProductSchema,
    MovementSchema,
    StockBalanceSchema,
    UserCreateSchema,
    ExpenseSchema,
    ExpenseCategory,
)


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    await producer.start_worker()
    yield
    # Future: await engine.dispose() for graceful DB pool shutdown


# ---------------------------------------------------------------------------
# App factory
# ---------------------------------------------------------------------------

app = FastAPI(
    title="S.F.C.P.C - Systema de Gerenciamento",
    description="SaaS Multi-tenant Inventory & Financial Management System",
    version="0.2.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(RateLimiterMiddleware, requests_per_minute=60)
app.add_middleware(TenantMiddleware)


# ---------------------------------------------------------------------------
# Dependency shortcuts
# ---------------------------------------------------------------------------

AsyncDB = Depends(get_session)
AuthUser = Depends(verify_jwt_token)  # injects verified JWT payload


# ---------------------------------------------------------------------------
# Health-check (public)
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "S.F.C.P.C API", "version": "0.2.0"}


# ---------------------------------------------------------------------------
# Auth (public)
# ---------------------------------------------------------------------------

from pydantic import BaseModel

class LoginRequest(BaseModel):
    username: str
    password: str


@app.post("/auth/register", tags=["Auth"], status_code=201)
async def register_user(data: UserCreateSchema, session: AsyncSession = AsyncDB):
    """Creates a new user for the current tenant (requires valid JWT for tenant context)."""
    # Note: TenantMiddleware provides tenant context via JWT even for this route
    # because registration requires knowing which tenant the user belongs to.
    from services.user_service import UserService
    return await UserService(session).register(data)


@app.post("/auth/login", tags=["Auth"])
async def login(request: LoginRequest, session: AsyncSession = AsyncDB):
    """Authenticates a user and returns a JWT. Requires X-Tenant-ID... wait,
    tenant context is resolved from the JWT itself; for login, pass tenant_id
    as a query param or route prefix. Current implementation uses middleware
    context — caller must send a short-lived 'bootstrap' token or tenant slug.

    TODO: implement tenant-slug-to-id resolution for unauthenticated login.
    """
    from services.user_service import UserService
    return await UserService(session).authenticate(request.username, request.password)


# ---------------------------------------------------------------------------
# Products  (protected)
# ---------------------------------------------------------------------------

@app.get("/products", response_model=List[ProductSchema], tags=["Products"],
         dependencies=[AuthUser])
async def list_products(limit: int = 50, offset: int = 0,
                        session: AsyncSession = AsyncDB):
    from db.base_repository import BaseRepository
    from db.orm_models import ProductORM
    repo = BaseRepository(ProductORM, session)
    return await repo.get_all(limit=limit, offset=offset)


@app.post("/products", response_model=ProductSchema, status_code=201,
          tags=["Products"], dependencies=[AuthUser])
async def create_product(product: ProductSchema, session: AsyncSession = AsyncDB):
    from db.base_repository import BaseRepository
    from db.orm_models import ProductORM
    repo = BaseRepository(ProductORM, session)
    # Map Pydantic schema → ORM instance
    orm = ProductORM(**product.model_dump(exclude_none=True))
    return await repo.create(orm)


@app.get("/products/{product_id}", response_model=ProductSchema, tags=["Products"],
         dependencies=[AuthUser])
async def get_product(product_id: UUID, session: AsyncSession = AsyncDB):
    from db.base_repository import BaseRepository
    from db.orm_models import ProductORM
    repo = BaseRepository(ProductORM, session)
    product = await repo.get_by_id(product_id)
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    return product


# ---------------------------------------------------------------------------
# Movements  (protected)
# ---------------------------------------------------------------------------

@app.post("/movements", response_model=StockBalanceSchema, status_code=201,
          tags=["Movements"], dependencies=[AuthUser])
async def create_movement(movement: MovementSchema, session: AsyncSession = AsyncDB):
    """Records a stock movement and updates the balance atomically."""
    from services.stock_service import StockService
    return await StockService(session).process_movement(movement)


@app.get("/movements", response_model=List[MovementSchema], tags=["Movements"],
         dependencies=[AuthUser])
async def list_movements(limit: int = 50, offset: int = 0,
                         session: AsyncSession = AsyncDB):
    from db.base_repository import BaseRepository
    from db.orm_models import MovementORM
    repo = BaseRepository(MovementORM, session)
    return await repo.get_all(limit=limit, offset=offset)


# ---------------------------------------------------------------------------
# Stock Balances  (protected)
# ---------------------------------------------------------------------------

@app.get("/balances", response_model=List[StockBalanceSchema], tags=["Balances"],
         dependencies=[AuthUser])
async def list_balances(limit: int = 50, offset: int = 0,
                        session: AsyncSession = AsyncDB):
    from db.base_repository import BaseRepository
    from db.orm_models import StockBalanceORM
    repo = BaseRepository(StockBalanceORM, session)
    return await repo.get_all(limit=limit, offset=offset)


# ---------------------------------------------------------------------------
# Financial Module  (protected)
# ---------------------------------------------------------------------------

@app.post("/finance/expenses", response_model=ExpenseSchema, status_code=201,
          tags=["Finance"], dependencies=[AuthUser])
async def create_expense(expense: ExpenseSchema, session: AsyncSession = AsyncDB):
    from services.financial_service import FinancialService
    return await FinancialService(session).create_expense(expense)


@app.get("/finance/expenses", response_model=List[ExpenseSchema],
         tags=["Finance"], dependencies=[AuthUser])
async def list_expenses(
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    category: Optional[ExpenseCategory] = None,
    limit: int = 50,
    offset: int = 0,
    session: AsyncSession = AsyncDB,
):
    from services.financial_service import FinancialService
    return await FinancialService(session).list_expenses(
        start_date=start_date, end_date=end_date,
        category=category, limit=limit, offset=offset,
    )


@app.get("/finance/summary", tags=["Finance"], dependencies=[AuthUser])
async def financial_summary(
    period_start: date,
    period_end: date,
    session: AsyncSession = AsyncDB,
):
    """Returns gross margin, total expenses and breakdown by category for the period."""
    from services.financial_service import FinancialService
    return await FinancialService(session).get_financial_summary(period_start, period_end)


# ---------------------------------------------------------------------------
# Intelligence / ML  (protected)
# ---------------------------------------------------------------------------

@app.get("/intelligence/inventory-summary", tags=["Intelligence"],
         dependencies=[AuthUser])
async def get_inventory_summary():
    from data.gold_service import GoldLayerService
    return await GoldLayerService.get_inventory_summary(get_tenant_id())


@app.get("/intelligence/abc-analysis", tags=["Intelligence"],
         dependencies=[AuthUser])
async def get_abc_analysis():
    from data.gold_service import GoldLayerService
    from ml.abc_analysis import ABCAnalysis
    summary = await GoldLayerService.get_inventory_summary(get_tenant_id())
    return ABCAnalysis.calculate(summary)


@app.get("/intelligence/demand-forecast", tags=["Intelligence"],
         dependencies=[AuthUser])
async def get_demand_forecast(days: int = 30):
    from data.gold_service import GoldLayerService
    from ml.demand_forecasting import DemandForecasting
    history = await GoldLayerService.get_movement_history(get_tenant_id())
    return DemandForecasting.predict_next_period(history, days=days)


# ---------------------------------------------------------------------------
# LLM Agent  (protected)
# ---------------------------------------------------------------------------

class ChatMessage(BaseModel):
    message: str


@app.post("/chat", tags=["Agent"], dependencies=[AuthUser])
async def chat_with_agent(chat_input: ChatMessage):
    """Natural language interface for inventory operations."""
    from llm.agent import AgentOrchestrator
    reply = await AgentOrchestrator.process_message(
        tenant_id=get_tenant_id(),
        message=chat_input.message,
    )
    return {"reply": reply}


# ---------------------------------------------------------------------------
# OCR / Finance Upload  (protected, LGPD-compliant)
# ---------------------------------------------------------------------------

@app.post("/finance/upload", tags=["Finance"], dependencies=[AuthUser])
async def upload_financial_document(
    file: UploadFile = File(...),
    document_type: str = Form("INVOICE"),
):
    """LGPD-compliant multimodal ingestion.

    The uploaded file is read into ephemeral bytes in RAM, processed by OCR
    and the LLM agent, then discarded (never written to disk or persisted).
    Only the structured JSON intent is stored, not the raw document.
    """
    MAX_SIZE_BYTES = 10 * 1024 * 1024  # 10 MB hard limit
    file_bytes = await file.read()

    if len(file_bytes) > MAX_SIZE_BYTES:
        raise HTTPException(status_code=413, detail="File exceeds maximum allowed size of 10 MB")

    allowed_types = {"image/jpeg", "image/png", "application/pdf"}
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported media type '{file.content_type}'. Allowed: JPEG, PNG, PDF",
        )

    from vision.ocr_service import OCRService
    from llm.agent import AgentOrchestrator

    extracted_text = OCRService.extract_text(file_bytes)
    prompt = f"[{document_type}] OCR Extraction: {extracted_text}"
    reply_str = await AgentOrchestrator.process_message(get_tenant_id(), prompt)

    try:
        reply_json = json.loads(reply_str)
    except json.JSONDecodeError:
        reply_json = {"raw_reply": reply_str}

    return {
        "status": "success",
        "ocr_preview": extracted_text[:200] + "..." if len(extracted_text) > 200 else extracted_text,
        "agent_decision": reply_json,
    }


# ---------------------------------------------------------------------------
# Entry point (dev)
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
