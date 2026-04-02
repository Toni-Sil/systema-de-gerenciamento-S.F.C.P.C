"""Routes para input via IA: transcrição de áudio, extração de imagem e PDF.

Fixes:
- #17: Corrigido import `from src.auth.dependencies` (não existia) para `auth.jwt_handler`
- #17: Router agora é registrado em main.py
- #20: Catálogo de produtos removido do System Prompt estático;
        injetado dinamicamente por tenant a cada requisição
"""
import json
import os
from typing import Literal, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from auth.jwt_handler import verify_jwt_token
from auth.tenant_context import get_tenant_id

router = APIRouter(prefix="/ai", tags=["AI Input"])

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

# System Prompt base — sem lista de produtos hardcoded
# O catálogo real do tenant é injetado dinamicamente em cada requisição
BASE_SYSTEM_PROMPT = """Voce e um assistente de gerenciamento de estoque da fabrica de estofados S.F.C.P.C.
Sua tarefa e extrair informacoes de movimentacoes de estoque a partir de texto (voz transcrita), imagens ou PDFs.

Extraia os seguintes campos quando disponiveis:
- productName: nome ou descricao do produto
- productCode: codigo do produto (ex: TEC-001)
- type: tipo de movimentacao (Entrada, Saida, Transferencia, Ajuste)
- quantity: quantidade movimentada (numero positivo)
- batch: numero do lote
- locationOrigin: local de origem
- locationDestiny: local de destino
- notes: observacoes adicionais
- operator: nome do operador

Responda APENAS com o JSON, sem markdown ou explicacoes."""


# ---------------------------------------------------------------------------
# Schemas
# ---------------------------------------------------------------------------

class TranscribeRequest(BaseModel):
    audio: str  # base64 encoded audio/webm
    mimeType: str = "audio/webm"


class TranscribeResponse(BaseModel):
    transcript: str


class ProcessMovementRequest(BaseModel):
    type: Literal["voice", "image", "pdf"]
    content: str  # text for voice; base64 for image/pdf
    mimeType: Optional[str] = None


class MovementData(BaseModel):
    productName: Optional[str] = None
    productCode: Optional[str] = None
    type: Optional[str] = None
    quantity: Optional[float] = None
    batch: Optional[str] = None
    locationOrigin: Optional[str] = None
    locationDestiny: Optional[str] = None
    notes: Optional[str] = None
    operator: Optional[str] = None


class ProcessMovementResponse(BaseModel):
    movement: MovementData


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _gemini_headers() -> dict:
    return {"Content-Type": "application/json"}


def _gemini_url() -> str:
    return f"{GEMINI_URL}?key={GEMINI_API_KEY}"


async def _get_tenant_catalog() -> str:
    """Busca o catálogo de produtos real do tenant atual para injetar no prompt."""
    tenant_id = get_tenant_id()
    if not tenant_id:
        return ""
    try:
        from llm.tools import LLMTools
        resp = json.loads(await LLMTools.search_product(tenant_id=tenant_id, query=""))
        if resp.get("status") == "success" and resp.get("data"):
            lines = [f"- {p['code']}: {p['description']}" for p in resp["data"][:50]]  # max 50 no prompt
            return "\n\nCatálogo de produtos do tenant:\n" + "\n".join(lines)
    except Exception:
        pass
    return ""


async def _call_gemini(payload: dict) -> dict:
    """Chama a API REST do Gemini e retorna o JSON de resposta."""
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY not configured. Set it in .env",
        )
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(_gemini_url(), headers=_gemini_headers(), json=payload)
        if resp.status_code == 429:
            raise HTTPException(status_code=429, detail="Limite de requisicoes Gemini excedido.")
        if not resp.is_success:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail=f"Gemini error {resp.status_code}: {resp.text[:300]}",
            )
        return resp.json()


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.post("/transcribe-audio", response_model=TranscribeResponse)
async def transcribe_audio(
    body: TranscribeRequest,
    _: dict = Depends(verify_jwt_token),
):
    """Transcreve um blob de áudio base64 usando Gemini multimodal."""
    payload = {
        "contents": [
            {
                "role": "user",
                "parts": [
                    {"text": "Transcreva este audio em portugues brasileiro. Retorne apenas o texto transcrito, sem formatacao adicional."},
                    {
                        "inlineData": {
                            "mimeType": body.mimeType,
                            "data": body.audio,
                        }
                    },
                ],
            }
        ],
        "generationConfig": {"temperature": 0.1},
    }
    data = await _call_gemini(payload)
    transcript = data["candidates"][0]["content"]["parts"][0]["text"].strip()
    return TranscribeResponse(transcript=transcript)


@router.post("/process-movement", response_model=ProcessMovementResponse)
async def process_movement(
    body: ProcessMovementRequest,
    _: dict = Depends(verify_jwt_token),
):
    """Extrai dados de movimentação de voz, imagem ou PDF via Gemini.
    O catálogo de produtos é carregado dinamicamente do banco por tenant.
    """
    # Catálogo dinâmico do tenant (substitui lista hardcoded)
    catalog_context = await _get_tenant_catalog()
    system_prompt = BASE_SYSTEM_PROMPT + catalog_context

    if body.type == "voice":
        parts = [
            {"text": system_prompt},
            {"text": f'Extraia os dados de movimentacao desta transcricao de voz:\n\n"{body.content}"'},
        ]
    elif body.type in ("image", "pdf"):
        label = "documento PDF" if body.type == "pdf" else "imagem"
        mime = body.mimeType or ("application/pdf" if body.type == "pdf" else "image/jpeg")
        parts = [
            {"text": system_prompt},
            {"text": f"Extraia os dados de movimentacao de estoque deste {label}."},
            {
                "inlineData": {
                    "mimeType": mime,
                    "data": body.content,
                }
            },
        ]
    else:
        raise HTTPException(status_code=400, detail="type deve ser voice, image ou pdf")

    payload = {
        "contents": [{"role": "user", "parts": parts}],
        "generationConfig": {"temperature": 0.1, "responseMimeType": "application/json"},
    }
    data = await _call_gemini(payload)
    raw = data["candidates"][0]["content"]["parts"][0]["text"]

    try:
        movement_dict = json.loads(raw)
    except json.JSONDecodeError:
        raise HTTPException(status_code=422, detail="Nao foi possivel extrair dados estruturados da resposta da IA")

    return ProcessMovementResponse(movement=MovementData(**{k: v for k, v in movement_dict.items() if k in MovementData.model_fields}))
