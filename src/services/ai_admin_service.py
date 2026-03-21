import logging
from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from data.gold_service import GoldLayerService
from db.orm_models import AIAdminTaskORM
from models.entities import (
    AIAdminBriefingSchema,
    AIAdminTaskSchema,
    AIAdminTaskStatus,
    AIAdminTaskType,
)


logger = logging.getLogger(__name__)


class AIAdminService:
    """Camada de trabalho administrativo proativo da IA."""

    @staticmethod
    async def sync_admin_tasks(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> list[AIAdminTaskSchema]:
        overview = await GoldLayerService.get_admin_overview(tenant_id)
        recommended_actions = overview.get("recommended_actions", [])

        existing_rows = await session.execute(
            select(AIAdminTaskORM).where(AIAdminTaskORM.tenant_id == tenant_id)
        )
        existing_by_key = {
            row.task_key: row for row in existing_rows.scalars().all()
        }

        synced_tasks: list[AIAdminTaskSchema] = []
        now = datetime.utcnow()

        for action in recommended_actions:
            task_key = f"{action['type']}:{action['product_code']}"
            priority_score = float(min(100.0, max(0.0, action.get("priority_score", 50.0))))
            due_date = now + timedelta(
                hours=4 if action.get("priority") == "high" else 24
            )

            task = existing_by_key.get(task_key)
            if task is None:
                task = AIAdminTaskORM(
                    tenant_id=tenant_id,
                    task_type=AIAdminTaskType.REPLENISHMENT,
                    status=AIAdminTaskStatus.SUGGESTED,
                    title=f"Repor {action['product_code']}",
                    description=action["message"],
                    priority_score=priority_score,
                    due_date=due_date,
                    task_key=task_key,
                    context_payload=action,
                )
                session.add(task)
                await session.flush()
            else:
                task.title = f"Repor {action['product_code']}"
                task.description = action["message"]
                task.priority_score = priority_score
                task.due_date = due_date
                task.context_payload = action
                task.updated_at = now
                await session.flush()

            synced_tasks.append(AIAdminTaskSchema.model_validate(task))

        logger.info(
            "ai_admin_tasks_synced",
            extra={"tenant_id": str(tenant_id), "task_count": len(synced_tasks)},
        )
        return synced_tasks

    @staticmethod
    async def list_open_tasks(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> list[AIAdminTaskSchema]:
        result = await session.execute(
            select(AIAdminTaskORM)
            .where(
                AIAdminTaskORM.tenant_id == tenant_id,
                AIAdminTaskORM.status.in_(
                    [
                        AIAdminTaskStatus.SUGGESTED,
                        AIAdminTaskStatus.PENDING_APPROVAL,
                        AIAdminTaskStatus.APPROVED,
                    ]
                ),
            )
            .order_by(
                AIAdminTaskORM.priority_score.desc(),
                AIAdminTaskORM.due_date.asc(),
            )
        )
        return [
            AIAdminTaskSchema.model_validate(row)
            for row in result.scalars().all()
        ]

    @staticmethod
    async def generate_daily_briefing(
        tenant_id: UUID,
        session: AsyncSession,
    ) -> AIAdminBriefingSchema:
        overview = await GoldLayerService.get_admin_overview(tenant_id)
        tasks = await AIAdminService.sync_admin_tasks(tenant_id, session)

        urgent_count = sum(1 for task in tasks if task.priority_score >= 80)
        headline = (
            f"{overview['low_stock_count']} item(ns) abaixo do mínimo e "
            f"{urgent_count} ação(ões) urgentes."
        )
        summary = (
            "A IA consolidou o quadro administrativo do dia, priorizando ruptura de "
            "estoque e ações de reposição com maior impacto operacional."
        )

        return AIAdminBriefingSchema(
            tenant_id=tenant_id,
            headline=headline,
            summary=summary,
            metrics={
                "total_products": overview["total_products"],
                "low_stock_count": overview["low_stock_count"],
                "urgent_task_count": urgent_count,
            },
            recommended_tasks=tasks,
        )
