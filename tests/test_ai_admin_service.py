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

from models.entities import AIAdminFeedbackStatus, AIAdminProfileSchema, AIAdminTaskSchema, AIAdminTaskStatus, AIAdminTaskType
from services.ai_admin_service import AIAdminService


class _FakeResult:
    def __init__(self, rows):
        self._rows = rows

    def scalars(self):
        return self

    def all(self):
        return self._rows

    def scalar_one_or_none(self):
        return self._rows[0] if self._rows else None


@pytest.mark.asyncio
async def test_sync_admin_tasks_creates_prioritized_replenishment_tasks(monkeypatch):
    tenant_id = uuid4()
    session = AsyncMock()
    session.add = Mock()
    session.execute.side_effect = [_FakeResult([]), _FakeResult([])]

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
    assert session.add.call_count == 2  # profile + task


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
        AIAdminService,
        "get_or_create_profile",
        AsyncMock(
            return_value=AIAdminProfileSchema(
                tenant_id=tenant_id,
                communication_style="detailed",
                priority_focus="balanced",
                briefing_hour=7,
                max_daily_tasks=5,
                prefers_whatsapp=True,
            )
        ),
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
    async def sync_and_return(_tenant_id, _session, _user_id=None):
        return [task]

    monkeypatch.setattr(AIAdminService, "sync_admin_tasks", sync_and_return)
    session.add = Mock()
    async def fake_flush():
        added = session.add.call_args.args[0]
        added.id = uuid4()
    session.flush.side_effect = fake_flush

    briefing = await AIAdminService.generate_daily_briefing(tenant_id, session)

    assert briefing.metrics["low_stock_count"] == 1
    assert briefing.metrics["urgent_task_count"] == 1
    assert briefing.recommended_tasks[0].task_key == "replenish:TEC-001"
    assert briefing.metrics["communication_style"] == "detailed"
    assert "memória" in briefing.summary.lower()


@pytest.mark.asyncio
async def test_record_task_feedback_marks_task_as_executed():
    tenant_id = uuid4()
    task = type(
        "Task",
        (),
        {
            "id": uuid4(),
            "tenant_id": tenant_id,
            "task_type": AIAdminTaskType.REPLENISHMENT,
            "status": AIAdminTaskStatus.SUGGESTED,
            "title": "Repor TEC-001",
            "description": "Repor TEC-001 imediatamente.",
            "priority_score": 92.0,
            "due_date": datetime.utcnow(),
            "task_key": "replenish:TEC-001",
            "context_payload": {},
            "feedback_status": None,
            "feedback_note": None,
            "resolved_by_user_id": None,
            "resolved_at": None,
            "resolution_time_minutes": None,
            "created_at": datetime.utcnow(),
            "updated_at": datetime.utcnow(),
        },
    )()

    session = AsyncMock()
    session.execute.return_value = _FakeResult([task])

    updated = await AIAdminService.record_task_feedback(
        tenant_id=tenant_id,
        task_id=task.id,
        feedback_status=AIAdminFeedbackStatus.USEFUL,
        feedback_note="Executado após briefing.",
        resolved_by_user_id=uuid4(),
        session=session,
    )

    assert updated is not None
    assert updated.status == AIAdminTaskStatus.EXECUTED
    assert updated.feedback_note == "Executado após briefing."


@pytest.mark.asyncio
async def test_sync_admin_tasks_maps_non_replenishment_types(monkeypatch):
    tenant_id = uuid4()
    session = AsyncMock()
    session.add = Mock()
    session.execute.side_effect = [_FakeResult([]), _FakeResult([])]

    async def fake_flush():
        added = session.add.call_args.args[0]
        added.id = uuid4()
        added.created_at = datetime.utcnow()
        added.updated_at = datetime.utcnow()
        return None

    session.flush.side_effect = fake_flush

    monkeypatch.setattr(
        "services.ai_admin_service.GoldLayerService.get_admin_overview",
        AsyncMock(
            return_value={
                "headline": "1 item em auditoria",
                "total_products": 12,
                "low_stock_count": 0,
                "critical_items": [],
                "recommended_actions": [
                    {
                        "type": "audit",
                        "priority": "medium",
                        "priority_score": 71.0,
                        "product_code": "TEC-002",
                        "message": "Revisar saída fora do padrão.",
                    }
                ],
            }
        ),
    )

    tasks = await AIAdminService.sync_admin_tasks(tenant_id, session)

    assert len(tasks) == 1
    assert tasks[0].task_type == AIAdminTaskType.AUDIT
    assert tasks[0].title == "Auditar movimentação de TEC-002"
