import os
from uuid import UUID
from typing import Optional
from sqlalchemy.ext.asyncio import AsyncSession
from .base import LLMProvider
from .gemini_provider import GeminiProvider
from .ollama_provider import OllamaProvider

async def get_llm_provider(tenant_id: str | UUID, session: Optional[AsyncSession] = None) -> LLMProvider:
    """Retorna o provedor de IA baseado nas configurações do tenant (DB) ou ENV."""
    from db.orm_models import TenantSettingsORM
    from sqlalchemy import select

    provider_name = os.getenv("LLM_PROVIDER", "gemini").lower()
    gemini_key = os.getenv("GEMINI_API_KEY")
    ollama_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434")
    ollama_model = os.getenv("OLLAMA_MODEL", "llama3")

    # Tenta carregar do banco de dados se houver sessão
    if session:
        result = await session.execute(
            select(TenantSettingsORM).where(TenantSettingsORM.tenant_id == tenant_id)
        )
        settings = result.scalar_one_or_none()
        if settings:
            provider_name = settings.llm_provider
            if settings.gemini_api_key: gemini_key = settings.gemini_api_key
            if settings.ollama_url: ollama_url = settings.ollama_url
            if settings.ollama_model: ollama_model = settings.ollama_model

    if provider_name == "ollama":
        provider = OllamaProvider()
        provider.base_url = ollama_url
        provider.model = ollama_model
        return provider
    
    # Default to Gemini
    provider = GeminiProvider()
    if gemini_key:
        import google.generativeai as genai
        genai.configure(api_key=gemini_key)
    return provider
