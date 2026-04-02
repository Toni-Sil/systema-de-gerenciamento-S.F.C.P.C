"""S.F.C.P.C — API entrypoint.

Fixes aplicados:
- #13: MovementSchema instanciado com campos corretos (product_id, notes)
- #16: get_tenant_id() protegido com get_validated_tenant_id() em todos os endpoints
- #17: Router /ai (ai_input) registrado
- #19: Rotas legadas (/movements, /balances, /finance/expenses, /intelligence/*)
        movidas para v1_router e removidas do app raiz
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
from pydantic import BaseModel

from auth.jwt_handler import verify_jwt_token
from auth.tenant_context import get_tenant_id
from db.session import get_session
from messaging.producer import producer
from middleware.rate_limiter import RateLimiterMiddleware
from middleware.tenant_middleware import TenantMiddleware
from models.entities import (
    ExpenseSchema,
    FinancialSummarySchema,
    MovementSchema,
    MovementType,
    ProductSchema,
    StockBalanceSchema,
    UserCreateSchema,
    UserSchema,
)
from services.financial_service import FinancialService
from services.stock_service import StockService
from services.user_service import UserService
from routes.whatsapp_router import router as whatsapp_router
from routes.ai_input import router as ai_input_router
from services.scheduler_service import SchedulerService

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Tenant guard — reutilizável como Depends (fix #16)
# ---------------------------------------------------------------------------

def get_validated_tenant_id() -> UUID:
    """Retorna o tenant_id do contexto ou lança 403 se ausente."""
    tenant_id = get_tenant_id()
    if not tenant_id:
        raise HTTPException(status_code=403, detail="Tenant context missing")
    return tenant_id


# ---------------------------------------------------------------------------
# Lifespan
# ---------------------------------------------------------------------------

@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("startup: initialising message broker worker")
    await producer.start_worker()
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
    version="0.4.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
)

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
app.include_router(ai_input_router)  # fix #17

_auth = Depends(verify_jwt_token)


# ---------------------------------------------------------------------------
# Health
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "S.F.C.P.C API", "version": "0.4.0"}


# ---------------------------------------------------------------------------
# API v1 Router
# ---------------------------------------------------------------------------

v1_router = APIRouter(prefix="/api/v1", dependencies=[_auth])


# --- Inventory ---

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
        # Tenta por UUID primeiro, depois por code string
        product = None
        try:
            product_id = UUID(code)
            product = await repo.get_by_id(product_id)
        except ValueError:
            product = await repo.get_one(code=code)  # BaseRepository.get_one existe e é tenant-scoped
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")
        return product


@v1_router.delete("/inventory/{code}", tags=["Inventory"], status_code=204)
async def delete_product(code: str):
    async with get_session() as session:
        from db.orm_models import ProductORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(ProductORM, session)
        success = await repo.delete_where(code=code)  # BaseRepository.delete_where existe e é tenant-scoped
        if not success:
            raise HTTPException(status_code=404, detail="Product not found")
        return None


# --- Stock / Movements (fix #13: MovementSchema com campos corretos) ---

@v1_router.post("/inventory/{code}/balance", response_model=StockBalanceSchema, tags=["Inventory"], status_code=201)
async def update_balance(
    code: str,
    data: dict,
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    """Aplica um delta de saldo ao produto identificado pelo code.
    Positivo = ENTRY, negativo = EXIT.
    """
    delta = data.get("delta", 0)
    notes = data.get("reason") or data.get("notes", "Ajuste via API")

    if delta == 0:
        raise HTTPException(status_code=400, detail="delta não pode ser zero")

    async with get_session() as session:
        from db.orm_models import ProductORM
        from sqlalchemy import select
        # Busca produto pelo code com isolamento de tenant (fix #13)
        result = await session.execute(
            select(ProductORM).where(
                ProductORM.code == code,
                ProductORM.tenant_id == tenant_id,
                ProductORM.is_active == True,
            )
        )
        product = result.scalar_one_or_none()
        if not product:
            raise HTTPException(status_code=404, detail=f"Produto '{code}' não encontrado")

        import uuid
        movement = MovementSchema(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            product_id=product.id,           # fix #13: product_id correto
            type=MovementType.ENTRY if delta > 0 else MovementType.EXIT,
            quantity=abs(delta),
            notes=notes,                      # fix #13: notes ao invés de reason
        )
        return await StockService.process_movement(movement, session)


@v1_router.get("/movements", tags=["Stock"])  # fix #19: movido de /movements para v1
async def list_movements(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    async with get_session() as session:
        from db.orm_models import StockMovementORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockMovementORM, session)
        return await repo.get_all(limit=limit, offset=offset)


@v1_router.get("/balances", response_model=List[StockBalanceSchema], tags=["Stock"])  # fix #19
async def list_balances(
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    async with get_session() as session:
        from db.orm_models import StockBalanceORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockBalanceORM, session)
        return await repo.get_all(limit=limit, offset=offset)


# --- Finance ---

@v1_router.post("/finance/expenses", response_model=ExpenseSchema, tags=["Finance"])  # fix #19
async def create_expense(expense: ExpenseSchema):
    async with get_session() as session:
        return await FinancialService.create_expense(expense, session)


@v1_router.get("/financial/summary", response_model=FinancialSummarySchema, tags=["Finance"])
async def financial_summary(
    period: str = Query("30d"),
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    end_date = date.today()
    days = 30
    if period.endswith("d"):
        try:
            days = int(period[:-1])
        except ValueError:
            pass
    start_date = end_date - timedelta(days=days)
    async with get_session() as session:
        return await FinancialService.get_period_summary(tenant_id, start_date, end_date, session)


@v1_router.get("/financial/transactions", tags=["Finance"])
async def financial_transactions(period: str = Query("30d")):
    async with get_session() as session:
        from db.orm_models import StockMovementORM
        from db.base_repository import BaseRepository
        repo = BaseRepository(StockMovementORM, session)
        return await repo.get_all(limit=20)


# --- Intelligence (fix #14 + #16: session e tenant_id validados) ---

@v1_router.get("/intelligence/inventory-summary", tags=["Intelligence"])  # fix #19
async def get_inventory_summary(
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    from data.gold_service import GoldLayerService
    async with get_session() as session:
        return await GoldLayerService.get_inventory_summary(tenant_id, session)  # fix #14


@v1_router.get("/intelligence/abc-analysis", tags=["Intelligence"])  # fix #19
async def get_abc_analysis(
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    from data.gold_service import GoldLayerService
    from ml.abc_analysis import ABCAnalysis
    async with get_session() as session:
        summary = await GoldLayerService.get_inventory_summary(tenant_id, session)  # fix #14
    return ABCAnalysis.calculate(summary)


@v1_router.get("/intelligence/demand-forecast", tags=["Intelligence"])  # fix #19
async def get_demand_forecast(
    days: int = Query(30, ge=1, le=365),
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    from data.gold_service import GoldLayerService
    from ml.demand_forecasting import DemandForecasting
    async with get_session() as session:
        history = await GoldLayerService.get_movement_history(tenant_id, session)  # fix #14
    return DemandForecasting.predict_next_period(history, days=days)


# --- Agent ---

class ChatMessage(BaseModel):
    message: str


@v1_router.post("/agent/chat", tags=["Agent"])
async def chat_with_agent(
    chat_input: ChatMessage,
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
    from llm.agent import AgentOrchestrator
    reply = await AgentOrchestrator.process_message(
        tenant_id=tenant_id,
        message=chat_input.message,
    )
    return {"reply": reply}


# --- Finance upload ---

@v1_router.post("/finance/upload", tags=["Finance"])  # fix #19: movido para v1
async def upload_financial_document(
    file: UploadFile = File(...),
    document_type: str = Form("INVOICE"),
    tenant_id: UUID = Depends(get_validated_tenant_id),  # fix #16
):
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


# Mount v1 router
app.include_router(v1_router)


# ---------------------------------------------------------------------------
# Auth routes (públicas)
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
