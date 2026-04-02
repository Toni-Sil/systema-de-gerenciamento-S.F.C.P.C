"""Routes for AI-powered movement input: voice transcription, image and PDF extraction.
Adapted from sfcpc-inventory-hub Supabase Edge Functions to FastAPI + Gemini.
"""
import base64
import json
import os
from typing import Literal, Optional

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from src.auth.dependencies import get_current_user

router = APIRouter(prefix="/ai", tags=["AI Input"])

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent"

SYSTEM_PROMPT = """Voce e um assistente de gerenciamento de estoque da fabrica de estofados S.F.C.P.C.
Sua tarefa e extrair informacoes de movimentacoes de estoque a partir de texto (voz transcrita), imagens ou PDFs.

Extraia os seguintes campos quando disponiveis:
- productName: nome ou descricao do produto
- type: tipo de movimentacao (Entrada, Saida, Transferencia, Ajuste)
- quantity: quantidade movimentada (numero positivo)
- batch: numero do lote
- locationOrigin: local de origem
- locationDestiny: local de destino
- notes: observacoes adicionais
- operator: nome do operador

Produtos conhecidos:
- TEC-001: Tecido Suede Cinza
- TEC-002: Tecido Linho Bege
- TEC-003: Tecido Chenille Marrom
- ESP-001: Espuma D33 10cm
- ESP-002: Espuma D45 15cm
- ESP-003: Espuma D28 8cm
- MAD-001: Pinus Tratado 2m
- MAD-002: MDF 15mm 2,75x1,84
- MAD-003: Compensado 10mm
- FER-001: Dobradica Sofa-Cama
- FER-002: Mola Espiral 12cm
- FER-003: Parafuso Sextavado M8

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


async def _call_gemini(payload: dict) -> dict:
    """Call Gemini REST API and return parsed JSON response."""
    if not GEMINI_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="GEMINI_API_KEY not configured",
        )
    async with httpx.AsyncClient(timeout=60) as client:
        resp = await client.post(_gemini_url(), headers=_gemini_headers(), json=payload)
        if resp.status_code == 429:
            raise HTTPException(status_code=429, detail="Limite de requisicoes excedido.")
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
    current_user=Depends(get_current_user),
):
    """Transcribe a base64-encoded audio blob using Gemini multimodal."""
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
    current_user=Depends(get_current_user),
):
    """Extract inventory movement data from voice text, image or PDF using Gemini."""
    if body.type == "voice":
        parts = [
            {"text": SYSTEM_PROMPT},
            {"text": f'Extraia os dados de movimentacao desta transcricao de voz:\n\n"{body.content}"'},
        ]
    elif body.type in ("image", "pdf"):
        label = "documento PDF" if body.type == "pdf" else "imagem"
        mime = body.mimeType or ("application/pdf" if body.type == "pdf" else "image/jpeg")
        parts = [
            {"text": SYSTEM_PROMPT},
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
        raise HTTPException(status_code=422, detail="Nao foi possivel extrair dados da resposta da IA")

    return ProcessMovementResponse(movement=MovementData(**movement_dict))
