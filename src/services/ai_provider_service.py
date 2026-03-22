import base64
import hashlib
import logging
import os
from datetime import datetime
from uuid import UUID

from cryptography.fernet import Fernet, InvalidToken
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from db.orm_models import AIProviderConfigORM
from models.entities import AIProviderConfigSchema, AIProviderConfigUpsertSchema, AIProviderType


logger = logging.getLogger(__name__)


def _get_encryption_secret() -> str:
    explicit_secret = os.getenv("AI_PROVIDER_CONFIG_KEY")
    if explicit_secret:
        return explicit_secret

    if os.getenv("PYTEST_CURRENT_TEST"):
        fallback = os.getenv("JWT_SECRET_KEY") or "test-ai-provider-config-key"
        logger.warning(
            "AI_PROVIDER_CONFIG_KEY is not configured; using test-only fallback during pytest execution."
        )
        return fallback

    if os.getenv("ALLOW_INSECURE_AI_PROVIDER_KEY", "false").lower() == "true":
        fallback = os.getenv("JWT_SECRET_KEY")
        if fallback:
            logger.warning(
                "AI_PROVIDER_CONFIG_KEY is not configured; using JWT_SECRET_KEY because ALLOW_INSECURE_AI_PROVIDER_KEY=true."
            )
            return fallback

    raise RuntimeError(
        "AI_PROVIDER_CONFIG_KEY must be set to encrypt tenant AI provider credentials. "
        "Set ALLOW_INSECURE_AI_PROVIDER_KEY=true only for local development fallback."
    )


_FERNET: Fernet | None = None


def _get_fernet() -> Fernet:
    global _FERNET
    if _FERNET is None:
        digest = hashlib.sha256(_get_encryption_secret().encode("utf-8")).digest()
        _FERNET = Fernet(base64.urlsafe_b64encode(digest))
    return _FERNET


class AIProviderService:
    @staticmethod
    def _encrypt_api_key(api_key: str | None) -> str | None:
        if not api_key:
            return None
        return _get_fernet().encrypt(api_key.strip().encode("utf-8")).decode("utf-8")

    @staticmethod
    def _decrypt_api_key(api_key_encrypted: str | None) -> str | None:
        if not api_key_encrypted:
            return None
        return _get_fernet().decrypt(api_key_encrypted.encode("utf-8")).decode("utf-8")

    @staticmethod
    def _mask_api_key(api_key: str | None) -> str | None:
        if not api_key:
            return None
        if len(api_key) <= 8:
            return "*" * len(api_key)
        return f"{api_key[:4]}{'*' * (len(api_key) - 8)}{api_key[-4:]}"

    @staticmethod
    def _serialize_config(
        config: AIProviderConfigORM,
        api_key: str | None,
        *,
        validation_error: str | None = None,
    ) -> AIProviderConfigSchema:
        last_status = config.last_validation_status
        last_error = config.last_validation_error
        if validation_error:
            last_status = "invalid"
            last_error = validation_error

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
            last_validation_status=last_status,
            last_validation_error=last_error,
            created_at=config.created_at,
            updated_at=config.updated_at,
        )

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

        try:
            api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
            return AIProviderService._serialize_config(config, api_key)
        except InvalidToken:
            logger.exception("Failed to decrypt AI provider API key", extra={"tenant_id": str(tenant_id)})
            return AIProviderService._serialize_config(
                config,
                None,
                validation_error="stored_api_key_cannot_be_decrypted",
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

        current_api_key = None
        if config.api_key_encrypted:
            try:
                current_api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
            except InvalidToken:
                logger.exception(
                    "Stored AI provider API key could not be decrypted during update",
                    extra={"tenant_id": str(tenant_id)},
                )

        new_api_key = (payload.api_key or current_api_key or None)

        config.provider = payload.provider
        config.model_name = payload.model_name.strip()
        config.api_base_url = payload.api_base_url.strip() if payload.api_base_url else None
        config.api_key_encrypted = AIProviderService._encrypt_api_key(new_api_key)
        config.is_active = payload.is_active
        config.temperature = payload.temperature
        config.max_tokens = payload.max_tokens
        config.system_prompt_override = (
            payload.system_prompt_override.strip() if payload.system_prompt_override else None
        )
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

        errors: list[str] = []
        api_key = None
        if config.api_key_encrypted:
            try:
                api_key = AIProviderService._decrypt_api_key(config.api_key_encrypted)
            except InvalidToken:
                errors.append("stored_api_key_cannot_be_decrypted")

        if config.provider != AIProviderType.LOCAL and not api_key:
            errors.append("api_key is required for hosted providers")
        if config.provider == AIProviderType.AZURE_OPENAI and not config.api_base_url:
            errors.append("api_base_url is required for Azure OpenAI")
        if not config.model_name or not config.model_name.strip():
            errors.append("model_name is required")

        config.last_validated_at = datetime.utcnow()
        if errors:
            config.last_validation_status = "invalid"
            config.last_validation_error = "; ".join(dict.fromkeys(errors))
        else:
            config.last_validation_status = "validated"
            config.last_validation_error = None

        await session.flush()
        return await AIProviderService.get_config(tenant_id, session)
