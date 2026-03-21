"""Focused tests for proactive AI admin work management."""
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

from models.entities import AIAdminTaskSchema, AIAdminTaskStatus, AIAdminTaskType
from services.ai_admin_service import AIAdminService


class _FakeResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows


@pytest.mark.asyncio
async def test_sync_admin_tasks_creates_prioritized_replenishment_tasks(monkeypatch):
    tenant_id = uuid4()
    session = AsyncMock()
    session.add = Mock()
    session.execute.return_value = _FakeResult([])

    async def fake_flush():
        added_task = session.add.call_args.args[0]
        added_task.id = uuid4()
        added_task.created_at = datetime.utcnow()
        added_task.updated_at = datetime.utcnow()
        return None

    session.flush.side_effect = fake_flush

    monkeypatch.setattr(
        "services.ai_admin_service.GoldLayerService.get_admin_overview",
        AsyncMock(
            return_value={
                "headline": "2 itens críticos",
                "total_products": 12,
                "low_stock_count": 2,
                "critical_items": [],
                "recommended_actions": [
                    {
                        "type": "replenish",
                        "priority": "high",
                        "priority_score": 92.0,
                        "product_code": "TEC-001",
                        "current_balance": 3.0,
                        "min_stock": 10.0,
                        "deficit": 7.0,
                        "due_date": datetime.utcnow().isoformat(),
                        "reason": "Produto abaixo do estoque mínimo operacional.",
                        "message": "Repor TEC-001 imediatamente.",
                    }
                ],
            }
        ),
    )

    tasks = await AIAdminService.sync_admin_tasks(tenant_id, session)

    assert len(tasks) == 1
    assert tasks[0].task_key == "replenish:TEC-001"
    assert tasks[0].priority_score == 92.0
    assert tasks[0].status == AIAdminTaskStatus.SUGGESTED
    session.add.assert_called_once()


@pytest.mark.asyncio
async def test_generate_daily_briefing_returns_metrics_and_tasks(monkeypatch):
    tenant_id = uuid4()
    session = AsyncMock()

    task = AIAdminTaskSchema(
        id=uuid4(),
        tenant_id=tenant_id,
        task_type=AIAdminTaskType.REPLENISHMENT,
        status=AIAdminTaskStatus.SUGGESTED,
        title="Repor TEC-001",
        description="Repor TEC-001 imediatamente.",
        priority_score=92.0,
        due_date=datetime.utcnow(),
        task_key="replenish:TEC-001",
        context_payload={"product_code": "TEC-001"},
        created_at=datetime.utcnow(),
        updated_at=datetime.utcnow(),
    )

    monkeypatch.setattr(
        "services.ai_admin_service.GoldLayerService.get_admin_overview",
        AsyncMock(
            return_value={
                "headline": "1 item crítico",
                "total_products": 12,
                "low_stock_count": 1,
                "critical_items": [{"code": "TEC-001"}],
                "recommended_actions": [],
            }
        ),
    )
    async def sync_and_return(_tenant_id, _session):
        return [task]

    monkeypatch.setattr(AIAdminService, "sync_admin_tasks", sync_and_return)

    briefing = await AIAdminService.generate_daily_briefing(tenant_id, session)

    assert briefing.metrics["low_stock_count"] == 1
    assert briefing.metrics["urgent_task_count"] == 1
    assert briefing.recommended_tasks[0].task_key == "replenish:TEC-001"
    assert "ruptura" in briefing.summary.lower()
