import os
import google.generativeai as genai
from .base import LLMProvider

class GeminiProvider(LLMProvider):
    """Provedor do Google Gemini (Cloud)."""

    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY")
        if self.api_key:
            genai.configure(api_key=self.api_key)
        self.model_name = "gemini-2.0-flash"

    async def process_prompt(self, system_instruction: str, message: str) -> str:
        model = genai.GenerativeModel(
            model_name=self.model_name,
            system_instruction=system_instruction
        )
        response = await model.generate_content_async(message)
        return response.text.replace('```json', '').replace('```', '').strip()

    async def generate_insight(self, prompt: str) -> str:
        model = genai.GenerativeModel(self.model_name)
        response = await model.generate_content_async(prompt)
        return response.text.strip()

    async def process_multimodal(self, system_instruction: str, message: str, media_bytes: bytes, mime_type: str) -> str:
        model = genai.GenerativeModel(
            model_name=self.model_name,
            system_instruction=system_instruction
        )
        # Gemini multimodal call (SDK uses direct byte containers)
        response = await model.generate_content_async([
            message,
            {"mime_type": mime_type, "data": media_bytes}
        ])
        return response.text.replace('```json', '').replace('```', '').strip()
