"""Focused tests for tenant AI provider configuration."""
import os
import sys
from datetime import datetime
from pathlib import Path
from uuid import uuid4
from unittest.mock import AsyncMock, Mock

import pytest


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-pytest-only")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/testdb")

from models.entities import AIProviderConfigUpsertSchema, AIProviderType
from services.ai_provider_service import AIProviderService


class _FakeResult:
    def __init__(self, row):
        self._row = row

    def scalar_one_or_none(self):
        return self._row


@pytest.mark.asyncio
async def test_upsert_config_encrypts_key_and_returns_masked_value():
    tenant_id = uuid4()
    user_id = uuid4()
    session = AsyncMock()
    session.add = Mock()
    session.execute.side_effect = [_FakeResult(None), _FakeResult(type(
        "Config",
        (),
        {
            "id": uuid4(),
            "tenant_id": tenant_id,
            "provider": AIProviderType.OPENAI,
            "model_name": "gpt-4.1-mini",
            "api_base_url": None,
            "api_key_encrypted": AIProviderService._encrypt_api_key("sk-test-12345678"),
            "is_active": True,
            "temperature": 0.3,
            "max_tokens": 1600,
            "system_prompt_override": None,
            "updated_by_user_id": user_id,
            "last_validated_at": None,
            "last_validation_status": None,
            "last_validation_error": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        },
    )())]

    payload = AIProviderConfigUpsertSchema(
        provider=AIProviderType.OPENAI,
        model_name="gpt-4.1-mini",
        api_key="sk-test-12345678",
        temperature=0.3,
        max_tokens=1600,
    )

    config = await AIProviderService.upsert_config(tenant_id, user_id, payload, session)

    assert config.provider == AIProviderType.OPENAI
    assert config.api_key_masked.startswith("sk-t")
    assert config.api_key_masked.endswith("5678")


@pytest.mark.asyncio
async def test_validate_config_marks_missing_hosted_api_key_as_invalid():
    tenant_id = uuid4()
    session = AsyncMock()
    config_row = type(
        "Config",
        (),
        {
            "id": uuid4(),
            "tenant_id": tenant_id,
            "provider": AIProviderType.ANTHROPIC,
            "model_name": "claude-3-5-sonnet",
            "api_base_url": None,
            "api_key_encrypted": None,
            "is_active": True,
            "temperature": 0.2,
            "max_tokens": 1200,
            "system_prompt_override": None,
            "updated_by_user_id": None,
            "last_validated_at": None,
            "last_validation_status": None,
            "last_validation_error": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        },
    )()
    session.execute.side_effect = [_FakeResult(config_row), _FakeResult(config_row)]

    config = await AIProviderService.validate_config(tenant_id, session)

    assert config is not None
    assert config.last_validation_status == "invalid"
    assert "api_key" in (config.last_validation_error or "")
