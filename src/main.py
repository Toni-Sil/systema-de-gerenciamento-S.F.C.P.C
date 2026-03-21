"""S.F.C.P.C — API entrypoint.

All routes are protected by JWT authentication via Depends(verify_jwt_token).
Public routes are limited to: GET /, POST /auth/login, POST /auth/register.

Each route group is organized as an APIRouter and mounted with a prefix.
"""
import logging
import os
from contextlib import asynccontextmanager
from datetime import date, timedelta
from typing import List, Optional
from uuid import UUID

from fastapi import Depends, FastAPI, File, Form, HTTPException, Query, UploadFile, APIRouter
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from auth.jwt_handler import verify_jwt_token
from auth.tenant_context import get_tenant_id
from models.entities import ProductSchema, MovementSchema, FinancialSummarySchema, ChatInputSchema
from db.session import get_session
from messaging.producer import producer
from middleware.rate_limiter import RateLimiterMiddleware
from middleware.tenant_middleware import TenantMiddleware
from models.entities import (
    AIAdminBriefingSchema,
    AIAdminTaskSchema,
    ExpenseSchema,
    FinancialSummarySchema,
    MovementSchema,
    ProductSchema,
    StockBalanceSchema,
    UserCreateSchema,
    UserSchema,
)
from services.financial_service import FinancialService
from services.ai_admin_service import AIAdminService
from services.stock_service import StockService
from services.user_service import UserService
from routes.whatsapp_router import router as whatsapp_router
from services.scheduler_service import SchedulerService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("startup: initialising message broker worker")
    await producer.start_worker()
    # Inicia scheduler de tarefas periodicas (relatorio semanal + alertas diarios)
    SchedulerService.start()
    yield
    logger.info("shutdown: cleaning up resources")
    SchedulerService.stop()


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

app = FastAPI(
    title="S.F.C.P.C — Systema de Gerenciamento",
    description="SaaS Multi-tenant Inventory Management System",
    version="0.3.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

# CORS
_allowed_origins = os.getenv("ALLOWED_ORIGINS", "*").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RateLimiterMiddleware, requests_per_minute=60)
app.add_middleware(TenantMiddleware)

# Routers
app.include_router(whatsapp_router)

_auth = Depends(verify_jwt_token)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "S.F.C.P.C API", "version": "0.3.0"}


# ---------------------------------------------------------------------------
# API v1 Router (Unified)
# ---------------------------------------------------------------------------

v1_router = APIRouter(prefix="/api/v1", dependencies=[_auth])

# Products / Inventory
@v1_router.get("/inventory", response_model=List[ProductSchema], tags=["Inventory"])
async def list_products(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    async with get_session() as session:
        from db.orm_models import ProductORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(ProductORM, session)
        return await repo.get_all(limit=limit, offset=offset)

@v1_router.post("/inventory", response_model=ProductSchema, tags=["Inventory"], status_code=201)
async def create_product(product: ProductSchema):
    async with get_session() as session:
        from db.orm_models import ProductORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(ProductORM, session)
        return await repo.create(product)

@v1_router.get("/inventory/{code}", response_model=ProductSchema, tags=["Inventory"])
async def get_product(code: str):
    async with get_session() as session:
        from db.orm_models import ProductORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(ProductORM, session)
        # Assuming code is a unique string field, but current repo uses ID.
        # For MVP, we'll try to find by code if possible or use ID if code is UUID.
        product = None
        try:
            product_id = UUID(code)
            product = await repo.get_by_id(product_id)
        except ValueError:
            # Fallback or specific lookup by code (needs repo support)
            # This assumes BaseRepository.get_one can take keyword arguments for filtering
            product = await repo.get_one(code=code)

        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        return product

@v1_router.delete("/inventory/{code}", tags=["Inventory"], status_code=204)
async def delete_product(code: str):
    async with get_session() as session:
        from db.orm_models import ProductORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(ProductORM, session)
        # Manual delete if repo doesn't have it or use filter
        # This assumes BaseRepository.delete_where can take keyword arguments for filtering
        success = await repo.delete_where(code=code)
        if not success:
            raise HTTPException(status_code=404, detail="Product not found")
        return None

# Stock / Movements
@v1_router.post("/inventory/{code}/balance", response_model=StockBalanceSchema, tags=["Inventory"], status_code=201)
async def update_balance(code: str, data: dict):
    delta = data.get("delta", 0)
    reason = data.get("reason", "Ajuste")
    async with get_session() as session:
        from models.entities import MovementSchema
        movement = MovementSchema(product_code=code, quantity=delta, type="ENTRY" if delta > 0 else "EXIT", reason=reason)
        return await StockService.process_movement(movement, session)

# Finance
@v1_router.get("/financial/summary", response_model=FinancialSummarySchema, tags=["Finance"])
async def financial_summary(
    period: str = Query("30d"),
):
    # Mocking implementation to match frontend simplified period
    tenant_id = get_tenant_id()
    if not tenant_id:
        raise HTTPException(status_code=403, detail="Tenant context missing")
    async with get_session() as session:
        # date logic based on period '30d' etc
        end_date = date.today()
        days = 30 # Default
        if period.endswith('d'):
            try:
                days = int(period[:-1])
            except ValueError:
                pass # Use default
        start_date = end_date - timedelta(days=days)
        return await FinancialService.get_period_summary(tenant_id, start_date, end_date, session)

@v1_router.get("/financial/transactions", tags=["Finance"])
async def financial_transactions(period: str = Query("30d")):
    async with get_session() as session:
        from db.orm_models import StockMovementORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockMovementORM, session)
        return await repo.get_all(limit=20)

# Agent
from pydantic import BaseModel
class ChatMessage(BaseModel):
    message: str

@v1_router.post("/agent/chat", tags=["Agent"])
async def chat_with_agent(chat_input: ChatMessage):
    from llm.agent import AgentOrchestrator
    reply = await AgentOrchestrator.process_message(
        tenant_id=get_tenant_id(),
        message=chat_input.message,
    )
    return {"reply": reply}


@v1_router.get("/agent/admin/tasks", response_model=List[AIAdminTaskSchema], tags=["Agent"])
async def list_ai_admin_tasks():
    tenant_id = get_tenant_id()
    if not tenant_id:
        raise HTTPException(status_code=403, detail="Tenant context missing")

    async with get_session() as session:
        await AIAdminService.sync_admin_tasks(tenant_id, session)
        return await AIAdminService.list_open_tasks(tenant_id, session)


@v1_router.get("/agent/admin/briefing", response_model=AIAdminBriefingSchema, tags=["Agent"])
async def get_ai_admin_briefing():
    tenant_id = get_tenant_id()
    if not tenant_id:
        raise HTTPException(status_code=403, detail="Tenant context missing")

    async with get_session() as session:
        return await AIAdminService.generate_daily_briefing(tenant_id, session)

# Mount v1 router
app.include_router(v1_router)


# ---------------------------------------------------------------------------
# Auth routes
# ---------------------------------------------------------------------------

class LoginRequest(BaseModel):
    tenant_id: UUID
    username: str
    password: str


@app.post("/auth/register", response_model=UserSchema, tags=["Auth"], status_code=201)
async def register_user(data: UserCreateSchema):
    async with get_session() as session:
        return await UserService.register(data, session)


@app.post("/api/v1/auth/login", tags=["Auth"])
async def login_v1(request: LoginRequest):
    async with get_session() as session:
        return await UserService.authenticate(
            tenant_id=request.tenant_id,
            username=request.username,
            plain_password=request.password,
            session=session,
        )


# ---------------------------------------------------------------------------
# Products (OLD - these routes are now handled by v1_router)
# ---------------------------------------------------------------------------
# @app.get("/products", response_model=List[ProductSchema], tags=["Products"], dependencies=[_auth])
# async def list_products(
#     limit: int = Query(50, ge=1, le=200),
#     offset: int = Query(0, ge=0),
# ):
#     async with get_session() as session:
#         from db.orm_models import ProductORM
#         from db.base_repository import BaseRepository
#         repo = BaseRepository(ProductORM, session)
#         return await repo.get_all(limit=limit, offset=offset)


# @app.post("/products", response_model=ProductSchema, tags=["Products"], status_code=201, dependencies=[_auth])
# async def create_product(product: ProductSchema):
#     async with get_session() as session:
#         from db.orm_models import ProductORM
#         from db.base_repository import BaseRepository
#         repo = BaseRepository(ProductORM, session)
#         return await repo.create(product)


# @app.get("/products/{product_id}", response_model=ProductSchema, tags=["Products"], dependencies=[_auth])
# async def get_product(product_id: UUID):
#     async with get_session() as session:
#         from db.orm_models import ProductORM
#         from db.base_repository import BaseRepository
#         repo = BaseRepository(ProductORM, session)
#         product = await repo.get_by_id(product_id)
#         if not product:
#             raise HTTPException(status_code=404, detail="Product not found")
#         return product


# ---------------------------------------------------------------------------
# Stock Movements (OLD - these routes are now handled by v1_router)
# ---------------------------------------------------------------------------

# @app.post("/movements", response_model=StockBalanceSchema, tags=["Stock"], status_code=201, dependencies=[_auth])
# async def create_movement(movement: MovementSchema):
#     async with get_session() as session:
#         return await StockService.process_movement(movement, session)


@app.get("/movements", response_model=List[MovementSchema], tags=["Stock"], dependencies=[_auth])
async def list_movements(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    async with get_session() as session:
        from db.orm_models import StockMovementORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockMovementORM, session)
        return await repo.get_all(limit=limit, offset=offset)


@app.get("/balances", response_model=List[StockBalanceSchema], tags=["Stock"], dependencies=[_auth])
async def list_balances(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    async with get_session() as session:
        from db.orm_models import StockBalanceORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockBalanceORM, session)
        return await repo.get_all(limit=limit, offset=offset)


# ---------------------------------------------------------------------------
# Financial (OLD - some routes are now handled by v1_router)
# ---------------------------------------------------------------------------

@app.post("/finance/expenses", response_model=ExpenseSchema, tags=["Finance"], dependencies=[_auth])
async def create_expense(expense: ExpenseSchema):
    async with get_session() as session:
        return await FinancialService.create_expense(expense, session)


# @app.get("/finance/summary", response_model=FinancialSummarySchema, tags=["Finance"], dependencies=[_auth])
# async def financial_summary(
#     period_start: date = Query(..., description="Format: YYYY-MM-DD"),
#     period_end: date = Query(..., description="Format: YYYY-MM-DD"),
# ):
#     tenant_id = get_tenant_id()
#     if not tenant_id:
#         raise HTTPException(status_code=403, detail="Tenant context missing")
#     async with get_session() as session:
#         return await FinancialService.get_period_summary(tenant_id, period_start, period_end, session)


@app.post("/finance/upload", tags=["Finance"], dependencies=[_auth])
async def upload_financial_document(
    file: UploadFile = File(...),
    document_type: str = Form("INVOICE"),
):
    tenant_id = get_tenant_id()
    file_bytes = await file.read()
    from vision.ocr_service import OCRService
    from llm.agent import AgentOrchestrator
    import json
    extracted_text = OCRService.extract_text(file_bytes)
    prompt = f"[{document_type}] OCR Extraction: {extracted_text}"
    reply_str = await AgentOrchestrator.process_message(tenant_id, prompt)
    try:
        reply_json = json.loads(reply_str)
    except Exception:
        reply_json = {"raw_reply": reply_str}
    return {
        "status": "success",
        "ocr_preview": extracted_text[:150] + "..." if len(extracted_text) > 150 else extracted_text,
        "agent_decision": reply_json,
    }


# ---------------------------------------------------------------------------
# Intelligence (ML)
# ---------------------------------------------------------------------------

@app.get("/intelligence/inventory-summary", tags=["Intelligence"], dependencies=[_auth])
async def get_inventory_summary():
    from data.gold_service import GoldLayerService
    return await GoldLayerService.get_inventory_summary(get_tenant_id())


@app.get("/intelligence/abc-analysis", tags=["Intelligence"], dependencies=[_auth])
async def get_abc_analysis():
    from data.gold_service import GoldLayerService
    from ml.abc_analysis import ABCAnalysis
    summary = await GoldLayerService.get_inventory_summary(get_tenant_id())
    return ABCAnalysis.calculate(summary)


@app.get("/intelligence/demand-forecast", tags=["Intelligence"], dependencies=[_auth])
async def get_demand_forecast(days: int = Query(30, ge=1, le=365)):
    from data.gold_service import GoldLayerService
    from ml.demand_forecasting import DemandForecasting
    history = await GoldLayerService.get_movement_history(get_tenant_id())
    return DemandForecasting.predict_next_period(history, days=days)


# ---------------------------------------------------------------------------
# LLM Agent (OLD - this route is now handled by v1_router)
# ---------------------------------------------------------------------------

# class ChatMessage(BaseModel):
#     message: str


# @app.post("/chat", tags=["Agent"], dependencies=[_auth])
# async def chat_with_agent(chat_input: ChatMessage):
#     from llm.agent import AgentOrchestrator
#     reply = await AgentOrchestrator.process_message(
#         tenant_id=get_tenant_id(),
#         message=chat_input.message,
#     )
#     return {"reply": reply}


# ---------------------------------------------------------------------------
# Exception handlers
# ---------------------------------------------------------------------------

@app.exception_handler(Exception)
async def unhandled_exception_handler(request, exc):
    logger.exception(f"Unhandled exception on {request.url.path}: {exc}")
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error", "path": request.url.path},
    )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
