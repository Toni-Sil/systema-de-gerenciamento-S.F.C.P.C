import base64
import hashlib
import logging
import os
from datetime import datetime
from uuid import UUID

from cryptography.fernet import Fernet
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.orm_models import AIProviderConfigORM
from models.entities import AIProviderConfigSchema, AIProviderConfigUpsertSchema, AIProviderType


logger = logging.getLogger(__name__)


def _build_fernet() -> Fernet:
    secret_source = (
        os.getenv("AI_PROVIDER_CONFIG_KEY")
        or os.getenv("JWT_SECRET_KEY")
        or "local-dev-ai-provider-config-key"
    )
    digest = hashlib.sha256(secret_source.encode("utf-8")).digest()
    return Fernet(base64.urlsafe_b64encode(digest))


_FERNET = _build_fernet()


class AIProviderService:
    @staticmethod
    def _encrypt_api_key(api_key: str | None) -> str | None:
        if not api_key:
            return None
        return _FERNET.encrypt(api_key.encode("utf-8")).decode("utf-8")

    @staticmethod
    def _decrypt_api_key(api_key_encrypted: str | None) -> str | None:
        if not api_key_encrypted:
            return None
        return _FERNET.decrypt(api_key_encrypted.encode("utf-8")).decode("utf-8")

    @staticmethod
    def _mask_api_key(api_key: str | None) -> str | None:
        if not api_key:
            return None
        if len(api_key) <= 8:
            return "*" * len(api_key)
        return f"{api_key[:4]}{'*' * (len(api_key) - 8)}{api_key[-4:]}"

    @staticmethod
    async def get_config(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> AIProviderConfigSchema | None:
        result = await session.execute(
            select(AIProviderConfigORM).where(AIProviderConfigORM.tenant_id == tenant_id)
        )
        config = result.scalar_one_or_none()
        if config is None:
            return None
        api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
        return AIProviderConfigSchema(
            id=config.id,
            tenant_id=config.tenant_id,
            provider=config.provider,
            model_name=config.model_name,
            api_base_url=config.api_base_url,
            api_key_masked=AIProviderService._mask_api_key(api_key),
            is_active=config.is_active,
            temperature=float(config.temperature),
            max_tokens=int(config.max_tokens),
            system_prompt_override=config.system_prompt_override,
            updated_by_user_id=config.updated_by_user_id,
            last_validated_at=config.last_validated_at,
            last_validation_status=config.last_validation_status,
            last_validation_error=config.last_validation_error,
            created_at=config.created_at,
            updated_at=config.updated_at,
        )

    @staticmethod
    async def upsert_config(
        tenant_id: UUID,
        user_id: UUID | None,
        payload: AIProviderConfigUpsertSchema,
        session: AsyncSession,
    ) -> AIProviderConfigSchema:
        result = await session.execute(
            select(AIProviderConfigORM).where(AIProviderConfigORM.tenant_id == tenant_id)
        )
        config = result.scalar_one_or_none()
        if config is None:
            config = AIProviderConfigORM(tenant_id=tenant_id)
            session.add(config)

        current_api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
        new_api_key = payload.api_key or current_api_key

        config.provider = payload.provider
        config.model_name = payload.model_name
        config.api_base_url = payload.api_base_url
        config.api_key_encrypted = AIProviderService._encrypt_api_key(new_api_key)
        config.is_active = payload.is_active
        config.temperature = payload.temperature
        config.max_tokens = payload.max_tokens
        config.system_prompt_override = payload.system_prompt_override
        config.updated_by_user_id = user_id
        config.updated_at = datetime.utcnow()
        await session.flush()
        return await AIProviderService.get_config(tenant_id, session)

    @staticmethod
    async def validate_config(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> AIProviderConfigSchema | None:
        result = await session.execute(
            select(AIProviderConfigORM).where(AIProviderConfigORM.tenant_id == tenant_id)
        )
        config = result.scalar_one_or_none()
        if config is None:
            return None

        api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
        errors: list[str] = []
        if config.provider != AIProviderType.LOCAL and not api_key:
            errors.append("api_key is required for hosted providers")
        if config.provider == AIProviderType.AZURE_OPENAI and not config.api_base_url:
            errors.append("api_base_url is required for Azure OpenAI")
        if not config.model_name:
            errors.append("model_name is required")

        config.last_validated_at = datetime.utcnow()
        if errors:
            config.last_validation_status = "invalid"
            config.last_validation_error = "; ".join(errors)
        else:
            config.last_validation_status = "validated"
            config.last_validation_error = None

        await session.flush()
        return await AIProviderService.get_config(tenant_id, session)
