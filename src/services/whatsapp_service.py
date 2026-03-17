"""
WhatsApp service via Evolution API.

Responsavel por enviar mensagens de texto para qualquer numero
usando a instancia configurada na Evolution API do VPS.

Variaveis de ambiente necessarias (.env):
  EVOLUTION_API_URL     — ex: https://evolution.seudominio.com
  EVOLUTION_API_KEY     — API key da instancia
  EVOLUTION_INSTANCE    — nome da instancia (ex: sfcpc)
  WHATSAPP_MANAGER_JID  — numero do gestor (ex: 5511999990000@s.whatsapp.net)
"""
import logging
import os

import httpx

logger = logging.getLogger(__name__)

_EVOLUTION_URL = os.getenv("EVOLUTION_API_URL", "").rstrip("/")
_EVOLUTION_KEY = os.getenv("EVOLUTION_API_KEY", "")
_INSTANCE = os.getenv("EVOLUTION_INSTANCE", "sfcpc")
_MANAGER_JID = os.getenv("WHATSAPP_MANAGER_JID", "")


class WhatsAppService:
    """Thin async client para Evolution API."""

    @staticmethod
    async def send_text(jid: str, text: str) -> dict:
        """
        Envia mensagem de texto para `jid`.
        jid formato: 5511999990000@s.whatsapp.net
        Levanta RuntimeError se EVOLUTION_API_URL nao estiver configurado.
        """
        if not _EVOLUTION_URL:
            raise RuntimeError(
                "EVOLUTION_API_URL nao configurado. "
                "Defina no .env do servidor."
            )

        url = f"{_EVOLUTION_URL}/message/sendText/{_INSTANCE}"
        headers = {
            "apikey": _EVOLUTION_KEY,
            "Content-Type": "application/json",
        }
        payload = {
            "number": jid,
            "textMessage": {"text": text},
            "options": {
                "delay": 500,
                "presence": "composing",
            },
        }

        async with httpx.AsyncClient(timeout=15.0) as client:
            resp = await client.post(url, json=payload, headers=headers)

        if resp.status_code not in (200, 201):
            logger.error(
                "[WhatsAppService] Evolution API error %s: %s",
                resp.status_code,
                resp.text,
            )
            resp.raise_for_status()

        logger.info(
            "[WhatsAppService] Mensagem enviada para %s (%d chars)",
            jid,
            len(text),
        )
        return resp.json()

    @staticmethod
    async def send_to_manager(text: str) -> dict:
        """Atalho: envia para o numero do gestor configurado em WHATSAPP_MANAGER_JID."""
        if not _MANAGER_JID:
            raise RuntimeError(
                "WHATSAPP_MANAGER_JID nao configurado. "
                "Defina no .env do servidor."
            )
        return await WhatsAppService.send_text(_MANAGER_JID, text)

    @staticmethod
    async def check_instance_status() -> dict:
        """Verifica se a instancia Evolution API esta conectada."""
        if not _EVOLUTION_URL:
            return {"status": "unconfigured"}
        url = f"{_EVOLUTION_URL}/instance/connectionState/{_INSTANCE}"
        headers = {"apikey": _EVOLUTION_KEY}
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                resp = await client.get(url, headers=headers)
            return resp.json()
        except Exception as exc:
            logger.warning("[WhatsAppService] check_instance_status error: %s", exc)
            return {"status": "error", "detail": str(exc)}
