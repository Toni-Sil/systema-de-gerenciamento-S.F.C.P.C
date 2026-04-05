from abc import ABC, abstractmethod
from typing import Dict, Any, Optional

class LLMProvider(ABC):
    """
    Interface base para provedores de LLM (Gemini, OpenAI, Ollama, etc).
    Permite que o SFC-PC seja agnóstico à IA utilizada.
    """

    @abstractmethod
    async def process_prompt(self, system_instruction: str, message: str) -> str:
        """Processa uma mensagem de usuário com instruções de sistema."""
        pass

    @abstractmethod
    async def generate_insight(self, prompt: str) -> str:
        """Gera um insight curto e direto para dashboards."""
        pass

    @abstractmethod
    async def process_multimodal(self, system_instruction: str, message: str, media_bytes: bytes, mime_type: str) -> str:
        """Processa uma mensagem de usuário com anexo de mídia (imagem/PDF/etc)."""
        pass
