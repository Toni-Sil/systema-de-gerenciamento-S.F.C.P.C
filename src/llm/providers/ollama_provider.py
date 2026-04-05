import os
import json
import httpx
from .base import LLMProvider

class OllamaProvider(LLMProvider):
    """Provedor para Ollama (IA Local)."""

    def __init__(self):
        self.base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
        self.model = os.getenv("OLLAMA_MODEL", "llama3")

    async def process_prompt(self, system_instruction: str, message: str) -> str:
        prompt = f"System: {system_instruction}\nUser: {message}\nAssistant:"
        
        async with httpx.AsyncClient(timeout=120) as client:
            resp = await client.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "stream": False,
                    "format": "json"
                }
            )
            data = resp.json()
            return data["response"].strip()

    async def generate_insight(self, prompt: str) -> str:
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "stream": False
                }
            )
            data = resp.json()
            return data["response"].strip()

    async def process_multimodal(self, system_instruction: str, message: str, media_bytes: bytes, mime_type: str) -> str:
        # TODO: Implementar suporte a LLAVA ou outros modelos visuais locais via Ollama
        return await self.process_prompt(system_instruction, f"{message} [Atenção: Esta IA local ainda não suporta visão multimodal diretamente pelo SFC-PC]")
