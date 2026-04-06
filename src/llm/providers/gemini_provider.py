import os
import json
import httpx
import logging
from .base import LLMProvider

logger = logging.getLogger(__name__)

class GeminiProvider(LLMProvider):
    """Provedor do Google Gemini via REST API (Thread-safe & Multi-tenant safe)."""

    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        self.model_name = "gemini-2.0-flash"
        self.base_url = "https://generativelanguage.googleapis.com/v1beta/models"

    async def _call_api(self, payload: dict, api_key: str) -> str:
        url = f"{self.base_url}/{self.model_name}:generateContent?key={api_key}"
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(url, json=payload)
            if response.status_code != 200:
                logger.error(f"Gemini API Error {response.status_code}: {response.text}")
                return "Erro: Falha na comunicação com a IA."
            
            data = response.json()
            try:
                return data['candidates'][0]['content']['parts'][0]['text'].strip()
            except (KeyError, IndexError):
                logger.error(f"Unexpected Gemini response format: {data}")
                return "Erro: Resposta da IA em formato inválido."

    async def process_prompt(self, system_instruction: str, message: str) -> str:
        payload = {
            "system_instruction": {"parts": [{"text": system_instruction}]},
            "contents": [{"parts": [{"text": message}]}],
            "generationConfig": {"temperature": 0.1, "maxOutputTokens": 2048}
        }
        text = await self._call_api(payload, self.api_key)
        return text.replace('```json', '').replace('```', '').strip()

    async def generate_insight(self, prompt: str) -> str:
        payload = {
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.7}
        }
        return await self._call_api(payload, self.api_key)

    async def process_multimodal(self, system_instruction: str, message: str, media_bytes: bytes, mime_type: str) -> str:
        import base64
        encoded = base64.b64encode(media_bytes).decode('utf-8')
        
        payload = {
            "system_instruction": {"parts": [{"text": system_instruction}]},
            "contents": [{
                "parts": [
                    {"text": message},
                    {"inline_data": {"mime_type": mime_type, "data": encoded}}
                ]
            }],
            "generationConfig": {"temperature": 0.1}
        }
        text = await self._call_api(payload, self.api_key)
        return text.replace('```json', '').replace('```', '').strip()
