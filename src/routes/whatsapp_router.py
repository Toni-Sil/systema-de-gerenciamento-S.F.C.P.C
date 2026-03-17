"""
Rotas de WhatsApp — Evolution API.

Endpoints:
  POST /whatsapp/send          — envia mensagem para qualquer JID (interno)
  POST /whatsapp/send-report   — envia relatorio imediato para o gestor
  GET  /whatsapp/status        — verifica conexao da instancia
"""
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from auth.jwt_handler import verify_jwt_token
from services.whatsapp_service import WhatsAppService

router = APIRouter(prefix="/whatsapp", tags=["WhatsApp"])
_auth = Depends(verify_jwt_token)


class SendMessageRequest(BaseModel):
    jid: str  # ex: 5511999990000@s.whatsapp.net
    text: str


class SendReportRequest(BaseModel):
    report_text: str
    jid: Optional[str] = None  # se None, usa WHATSAPP_MANAGER_JID do .env


@router.post("/send", dependencies=[_auth])
async def send_whatsapp_message(body: SendMessageRequest):
    """Envia mensagem de texto para um JID especifico."""
    try:
        result = await WhatsAppService.send_text(body.jid, body.text)
        return {"status": "sent", "evolution_response": result}
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Evolution API error: {exc}")


@router.post("/send-report", dependencies=[_auth])
async def send_report(
    body: SendReportRequest,
):
    """
    Envia relatorio financeiro/semanal para o gestor (ou JID informado).
    Usado pelo app Flutter ao tocar em 'Relatorio Semanal'.
    """
    try:
        if body.jid:
            result = await WhatsAppService.send_text(body.jid, body.report_text)
        else:
            result = await WhatsAppService.send_to_manager(body.report_text)
        return {"status": "sent", "evolution_response": result}
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Evolution API error: {exc}")


@router.get("/status")
async def whatsapp_status():
    """Verifica se a instancia Evolution API esta conectada (open/closed/connecting)."""
    return await WhatsAppService.check_instance_status()
