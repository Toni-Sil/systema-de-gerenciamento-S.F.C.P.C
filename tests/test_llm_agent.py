"""Focused regression tests for the integrated AI orchestrator."""
import json
import os
import sys
from pathlib import Path
from uuid import uuid4
from unittest.mock import AsyncMock

import pytest


ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src"
if str(SRC) not in sys.path:
    sys.path.insert(0, str(SRC))

os.environ.setdefault("JWT_SECRET_KEY", "test-secret-key-for-pytest-only")
os.environ.setdefault("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/testdb")

from llm.agent import AgentOrchestrator


@pytest.mark.asyncio
async def test_agent_processes_entry_message(monkeypatch):
    tenant_id = uuid4()
    mocked_record = AsyncMock(
        return_value=json.dumps(
            {
                "status": "success",
                "message": "Movimentação registrada com sucesso.",
                "new_balance": 65.0,
            }
        )
    )

    monkeypatch.setattr(
        "llm.agent.LLMTools.record_movement",
        mocked_record,
    )

    response = await AgentOrchestrator.process_message(
        tenant_id,
        "Acabei de dar entrada em 15 caixas do produto",
    )
    payload = json.loads(response)

    assert payload["action"] == "Entry"
    assert payload["status"] == "success"
    assert payload["params"]["quantity"] == 15.0
    assert payload["new_balance"] == 65.0
    mocked_record.assert_awaited_once_with(
        tenant_id=tenant_id,
        product_code="TEST-001",
        type="ENTRY",
        quantity=15.0,
    )


@pytest.mark.asyncio
async def test_agent_flags_large_exit_for_human_approval(monkeypatch):
    tenant_id = uuid4()

    monkeypatch.setattr(
        "llm.agent.LLMTools.record_movement",
        AsyncMock(
            return_value=json.dumps(
                {
                    "status": "success",
                    "message": "Movimentação registrada com sucesso.",
                    "new_balance": 10.0,
                }
            )
        ),
    )

    response = await AgentOrchestrator.process_message(
        tenant_id,
        "Vendi 1500 peças, dê saída",
    )
    payload = json.loads(response)

    assert payload["action"] == "Exit"
    assert payload["status"] == "needs_approval"
    assert "movimentação atípica" in payload["motivo"].lower()


@pytest.mark.asyncio
async def test_agent_returns_inventory_status(monkeypatch):
    tenant_id = uuid4()
    mocked_inventory = AsyncMock(
        return_value=json.dumps(
            {
                "status": "success",
                "data": [{"code": "TEST-001", "balance": 12.5}],
            }
        )
    )

    monkeypatch.setattr("llm.agent.LLMTools.get_inventory_status", mocked_inventory)

    response = await AgentOrchestrator.process_message(
        tenant_id,
        "Me mostre o status do estoque",
    )
    payload = json.loads(response)

    assert payload["action"] == "InventoryStatus"
    assert payload["status"] == "success"
    assert payload["data"] == [{"code": "TEST-001", "balance": 12.5}]
    mocked_inventory.assert_awaited_once_with(tenant_id=tenant_id)


@pytest.mark.asyncio
async def test_agent_generates_admin_plan(monkeypatch):
    tenant_id = uuid4()
    mocked_admin = AsyncMock(
        return_value=json.dumps(
            {
                "status": "success",
                "data": {
                    "headline": "2 itens críticos",
                    "summary": "A IA consolidou o quadro administrativo do dia.",
                    "metrics": {
                        "total_products": 12,
                        "low_stock_count": 2,
                        "urgent_task_count": 1,
                    },
                    "recommended_actions": [
                        {
                            "type": "replenish",
                            "priority": "high",
                            "product_code": "TEC-001",
                            "deficit": 7.0,
                            "message": "Repor TEC-001 para cobrir déficit de 7.0 e retornar ao estoque mínimo.",
                        }
                    ],
                },
            }
        )
    )

    monkeypatch.setattr("llm.agent.LLMTools.get_daily_admin_briefing", mocked_admin)

    response = await AgentOrchestrator.process_message(
        tenant_id,
        "Atue como administrador ativo e me entregue um plano de ação",
    )
    payload = json.loads(response)

    assert payload["action"] == "AdminPlan"
    assert payload["status"] == "success"
    assert payload["data"]["metrics"]["low_stock_count"] == 2
    assert payload["data"]["recommended_actions"][0]["product_code"] == "TEC-001"
    assert "estoque abaixo do mínimo" in payload["motivo"]
    mocked_admin.assert_awaited_once_with(tenant_id=tenant_id)


@pytest.mark.asyncio
async def test_agent_rejects_unknown_intent():
    payload = json.loads(
        await AgentOrchestrator.process_message(uuid4(), "Me conte uma piada")
    )

    assert payload["action"] == "Unknown"
    assert payload["status"] == "failed"
    assert "logística" in payload["motivo"]


@pytest.mark.asyncio
async def test_agent_extracts_product_code_from_message_and_context(monkeypatch):
    tenant_id = uuid4()
    mocked_record = AsyncMock(
        return_value=json.dumps(
            {
                "status": "success",
                "message": "Movimentação registrada com sucesso.",
                "new_balance": 22.0,
            }
        )
    )

    monkeypatch.setattr("llm.agent.LLMTools.record_movement", mocked_record)

    payload = json.loads(
        await AgentOrchestrator.process_message(
            tenant_id,
            "Dar entrada em 2 unidades do produto tec-009",
        )
    )

    assert payload["params"]["product"] == "TEC-009"
    mocked_record.assert_awaited_once_with(
        tenant_id=tenant_id,
        product_code="TEC-009",
        type="ENTRY",
        quantity=2.0,
    )


@pytest.mark.asyncio
async def test_agent_uses_context_to_extract_product_code(monkeypatch):
    tenant_id = uuid4()
    mocked_record = AsyncMock(
        return_value=json.dumps(
            {
                "status": "success",
                "message": "Movimentação registrada com sucesso.",
                "new_balance": 7.0,
            }
        )
    )

    monkeypatch.setattr("llm.agent.LLMTools.record_movement", mocked_record)

    payload = json.loads(
        await AgentOrchestrator.process_message(
            tenant_id,
            "Registrar saída de 3 unidades",
            context="Item crítico atual: TEC-777",
        )
    )

    assert payload["params"]["product"] == "TEC-777"
    mocked_record.assert_awaited_once_with(
        tenant_id=tenant_id,
        product_code="TEC-777",
        type="EXIT",
        quantity=3.0,
    )
