from fastapi import FastAPI, Depends, Header, HTTPException
from middleware.tenant_middleware import TenantMiddleware
from middleware.rate_limiter import RateLimiterMiddleware
from auth.tenant_context import get_tenant_id
from models.entities import ProductSchema, MovementSchema, StockBalanceSchema
from db.base_repository import BaseRepository
from services.stock_service import StockService, product_repo, balance_repo, movement_repo
from uuid import UUID
from typing import List, Optional

from fastapi import FastAPI, Depends, Header, HTTPException
from contextlib import asynccontextmanager
from messaging.producer import producer

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Start the Kafka/RabbitMQ consumer worker
    await producer.start_worker()
    yield
    # Shutdown logic if needed

app = FastAPI(
    title="S.F.C.P.C - Systema de Gerenciamento",
    description="SaaS Multi-tenant Inventory Management System",
    version="0.1.0",
    lifespan=lifespan
)

# Add Rate Limiting (60 requests per minute)
app.add_middleware(RateLimiterMiddleware, requests_per_minute=60)
# Add Multi-tenancy Middleware
app.add_middleware(TenantMiddleware)

@app.get("/")
async def root():
    return {"message": "S.F.C.P.C API is running", "tenant_id": get_tenant_id()}

from pydantic import BaseModel
class LoginRequest(BaseModel):
    tenant_id: str
    user_id: str

@app.post("/auth/token")
async def generate_token(request: LoginRequest):
    """
    Simula um API Gateway de Autenticação (OAuth2/OIDC).
    Retorna o JWT para ser usado no header 'Authorization: Bearer <token>'
    """
    from auth.jwt_handler import create_jwt_token
    token = create_jwt_token(tenant_id=request.tenant_id, user_id=request.user_id)
    return {"access_token": token, "token_type": "bearer"}

# --- Products ---
@app.get("/products", response_model=List[ProductSchema])
async def list_products():
    return await product_repo.get_all()

@app.post("/products", response_model=ProductSchema)
async def create_product(product: ProductSchema):
    return await product_repo.create(product)

# --- Movements ---
@app.post("/movements", response_model=StockBalanceSchema)
async def create_movement(movement: MovementSchema):
    """
    Records a stock movement (ENTRY, EXIT, ADJUSTMENT) and updates balance.
    Throws 400 if EXIT exceeds balance.
    """
    return await StockService.process_movement(movement)

@app.get("/movements", response_model=List[MovementSchema])
async def list_movements():
    return await movement_repo.get_all()

# --- Balances ---
@app.get("/balances", response_model=List[StockBalanceSchema])
async def list_balances():
    return await balance_repo.get_all()

# --- Intelligence (ML) ---
from data.gold_service import GoldLayerService
from ml.abc_analysis import ABCAnalysis
from ml.demand_forecasting import DemandForecasting

@app.get("/intelligence/inventory-summary")
async def get_inventory_summary():
    """Retorna a Gold Layer do estoque."""
    return await GoldLayerService.get_inventory_summary(get_tenant_id())

@app.get("/intelligence/abc-analysis")
async def get_abc_analysis():
    """Retorna a classificação ABC do estoque."""
    summary = await GoldLayerService.get_inventory_summary(get_tenant_id())
    return ABCAnalysis.calculate(summary)

@app.get("/intelligence/demand-forecast")
async def get_demand_forecast(days: int = 30):
    """Retorna previsão de demanda simples."""
    history = await GoldLayerService.get_movement_history(get_tenant_id())
    return DemandForecasting.predict_next_period(history, days=days)

from pydantic import BaseModel
class ChatMessage(BaseModel):
    message: str

# --- LLM Agent (Fase 6) ---
from llm.agent import AgentOrchestrator

@app.post("/chat")
async def chat_with_agent(chat_input: ChatMessage):
    """Rota para enviar comandos em linguagem natural para o Agente."""
    reply = await AgentOrchestrator.process_message(
        tenant_id=get_tenant_id(), 
        message=chat_input.message
    )
    return {"reply": reply}

from fastapi import UploadFile, File, Form
from vision.ocr_service import OCRService
import json

@app.post("/finance/upload")
async def upload_financial_document(
    file: UploadFile = File(...),
    document_type: str = Form("INVOICE")
):
    """
    Rota para ingestão multimodal (OCR) LGPD-compliant.
    A imagem da nota/comprovante nunca é salva em disco; é processada restritamente na RAM,
    traduzida para intenção financeira (JSON) pelo LLM e a memória local é descartada (Garbage Collection).
    """
    tenant_id = get_tenant_id()
    
    # 1. Leitura Mágica para a Memória (bytes efêmeros)
    file_bytes = await file.read()
    
    # 2. Visão Computacional
    extracted_text = OCRService.extract_text(file_bytes)
    
    # 3. AgentOrchestrator avalia o texto sujo e converte em Intent/Action
    prompt = f"[{document_type}] OCR Extraction: {extracted_text}"
    reply_str = await AgentOrchestrator.process_message(tenant_id, prompt)
    
    try:
        reply_json = json.loads(reply_str)
    except:
        reply_json = {"raw_reply": reply_str}
        
    return {
        "status": "success",
        "ocr_preview": extracted_text[:150] + "..." if len(extracted_text) > 150 else extracted_text,
        "agent_decision": reply_json
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
