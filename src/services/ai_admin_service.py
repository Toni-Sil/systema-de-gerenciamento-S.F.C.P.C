import logging
from datetime import datetime, timedelta
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from data.gold_service import GoldLayerService
from db.orm_models import AIAdminBriefingORM, AIAdminProfileORM, AIAdminTaskORM
from models.entities import (
    AIAdminBriefingSchema,
    AIAdminFeedbackStatus,
    AIAdminProfileSchema,
    AIAdminTaskSchema,
    AIAdminTaskStatus,
    AIAdminTaskType,
    AICommunicationStyle,
    AIPriorityFocus,
)


logger = logging.getLogger(__name__)


class AIAdminService:
    """Camada de trabalho administrativo proativo da IA."""

    _TASK_TYPE_MAP = {
        "replenish": AIAdminTaskType.REPLENISHMENT,
        "audit": AIAdminTaskType.AUDIT,
        "follow_up": AIAdminTaskType.FOLLOW_UP,
        "briefing": AIAdminTaskType.BRIEFING,
    }

    @staticmethod
    def _build_task_key(action: dict) -> str:
        product_code = action.get("product_code") or action.get("entity_key") or "general"
        return f"{action.get('type', 'follow_up')}:{product_code}"

    @staticmethod
    def _map_task_type(action: dict) -> AIAdminTaskType:
        return AIAdminService._TASK_TYPE_MAP.get(
            action.get("type", "").lower(),
            AIAdminTaskType.FOLLOW_UP,
        )

    @staticmethod
    def _build_task_title(action: dict, task_type: AIAdminTaskType) -> str:
        product_code = action.get("product_code")
        if task_type == AIAdminTaskType.REPLENISHMENT and product_code:
            return f"Repor {product_code}"
        if task_type == AIAdminTaskType.AUDIT and product_code:
            return f"Auditar movimentação de {product_code}"
        if task_type == AIAdminTaskType.BRIEFING:
            return action.get("title") or "Revisar briefing administrativo"
        if task_type == AIAdminTaskType.FOLLOW_UP and product_code:
            return f"Acompanhar ação em {product_code}"
        return action.get("title") or "Acompanhar recomendação administrativa"

    @staticmethod
    def _build_task_description(action: dict, task_type: AIAdminTaskType) -> str:
        if action.get("message"):
            return action["message"]
        if task_type == AIAdminTaskType.AUDIT:
            return "Revisar ocorrência operacional sinalizada pela IA."
        if task_type == AIAdminTaskType.BRIEFING:
            return "Validar o resumo diário gerado pela IA."
        return "Executar acompanhamento administrativo recomendado pela IA."

    @staticmethod
    async def get_or_create_profile(
        tenant_id: UUID,
        session: AsyncSession,
        user_id: UUID | None = None,
    ) -> AIAdminProfileSchema:
        result = await session.execute(
            select(AIAdminProfileORM).where(
                AIAdminProfileORM.tenant_id == tenant_id,
                AIAdminProfileORM.user_id == user_id,
            )
        )
        profile = result.scalar_one_or_none()
        if profile is None:
            profile = AIAdminProfileORM(
                tenant_id=tenant_id,
                user_id=user_id,
                communication_style=AICommunicationStyle.EXECUTIVE,
                priority_focus=AIPriorityFocus.BALANCED,
                briefing_hour=7,
                max_daily_tasks=5,
                prefers_whatsapp=True,
            )
            session.add(profile)
            await session.flush()

        return AIAdminProfileSchema.model_validate(profile)

    @staticmethod
    async def update_profile(
        tenant_id: UUID,
        session: AsyncSession,
        profile_data: AIAdminProfileSchema,
    ) -> AIAdminProfileSchema:
        result = await session.execute(
            select(AIAdminProfileORM).where(
                AIAdminProfileORM.tenant_id == tenant_id,
                AIAdminProfileORM.user_id == profile_data.user_id,
            )
        )
        profile = result.scalar_one_or_none()

        if profile is None:
            profile = AIAdminProfileORM(
                tenant_id=tenant_id,
                user_id=profile_data.user_id,
            )
            session.add(profile)

        profile.communication_style = profile_data.communication_style
        profile.priority_focus = profile_data.priority_focus
        profile.briefing_hour = profile_data.briefing_hour
        profile.max_daily_tasks = profile_data.max_daily_tasks
        profile.prefers_whatsapp = profile_data.prefers_whatsapp
        profile.updated_at = datetime.utcnow()
        await session.flush()
        return AIAdminProfileSchema.model_validate(profile)

    @staticmethod
    async def sync_admin_tasks(
        tenant_id: UUID,
        session: AsyncSession,
        user_id: UUID | None = None,
    ) -> list[AIAdminTaskSchema]:
        profile = await AIAdminService.get_or_create_profile(tenant_id, session, user_id)
        overview = await GoldLayerService.get_admin_overview(tenant_id)
        recommended_actions = overview.get("recommended_actions", [])[: profile.max_daily_tasks]

        existing_rows = await session.execute(
            select(AIAdminTaskORM).where(AIAdminTaskORM.tenant_id == tenant_id)
        )
        existing_by_key = {
            row.task_key: row for row in existing_rows.scalars().all()
        }

        synced_tasks: list[AIAdminTaskSchema] = []
        now = datetime.utcnow()

        focus_bonus = {
            AIPriorityFocus.RUPTURE: 8.0,
            AIPriorityFocus.COST: -5.0,
            AIPriorityFocus.BALANCED: 0.0,
        }[profile.priority_focus]

        for action in recommended_actions:
            task_type = AIAdminService._map_task_type(action)
            task_key = AIAdminService._build_task_key(action)
            priority_score = float(
                min(100.0, max(0.0, action.get("priority_score", 50.0) + focus_bonus))
            )
            due_date = now + timedelta(
                hours=4 if action.get("priority") == "high" else 24
            )
            title = AIAdminService._build_task_title(action, task_type)
            description = AIAdminService._build_task_description(action, task_type)

            task = existing_by_key.get(task_key)
            if task is None:
                task = AIAdminTaskORM(
                    tenant_id=tenant_id,
                    task_type=task_type,
                    status=AIAdminTaskStatus.SUGGESTED,
                    title=title,
                    description=description,
                    priority_score=priority_score,
                    due_date=due_date,
                    task_key=task_key,
                    context_payload=action,
                )
                session.add(task)
                await session.flush()
            else:
                task.task_type = task_type
                task.title = title
                task.description = description
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
    async def record_task_feedback(
        tenant_id: UUID,
        task_id: UUID,
        feedback_status: AIAdminFeedbackStatus,
        session: AsyncSession,
        feedback_note: str | None = None,
        resolved_by_user_id: UUID | None = None,
    ) -> AIAdminTaskSchema | None:
        result = await session.execute(
            select(AIAdminTaskORM).where(
                AIAdminTaskORM.tenant_id == tenant_id,
                AIAdminTaskORM.id == task_id,
            )
        )
        task = result.scalar_one_or_none()
        if task is None:
            return None

        task.feedback_status = feedback_status
        task.feedback_note = feedback_note
        task.resolved_by_user_id = resolved_by_user_id
        task.resolved_at = datetime.utcnow()
        task.resolution_time_minutes = int(
            max(0, (task.resolved_at - task.created_at).total_seconds() // 60)
        )
        if feedback_status in (AIAdminFeedbackStatus.USEFUL, AIAdminFeedbackStatus.AUTOMATED):
            task.status = AIAdminTaskStatus.EXECUTED
        elif feedback_status == AIAdminFeedbackStatus.IRRELEVANT:
            task.status = AIAdminTaskStatus.DISMISSED

        await session.flush()
        return AIAdminTaskSchema.model_validate(task)

    @staticmethod
    async def generate_daily_briefing(
        tenant_id: UUID,
        session: AsyncSession,
        user_id: UUID | None = None,
    ) -> AIAdminBriefingSchema:
        profile = await AIAdminService.get_or_create_profile(tenant_id, session, user_id)
        overview = await GoldLayerService.get_admin_overview(tenant_id)
        tasks = await AIAdminService.sync_admin_tasks(tenant_id, session, user_id)

        urgent_count = sum(1 for task in tasks if task.priority_score >= 80)
        headline = (
            f"{overview['low_stock_count']} item(ns) abaixo do mínimo e "
            f"{urgent_count} ação(ões) urgentes."
        )

        if profile.communication_style == AICommunicationStyle.DETAILED:
            summary = (
                "A IA consolidou o quadro administrativo do dia com foco em ruptura, "
                "priorização, memória de execução e acompanhamento das tarefas mais urgentes."
            )
        else:
            summary = (
                "Resumo executivo do dia: foco em ruptura de estoque e execução das ações críticas."
            )

        briefing = AIAdminBriefingSchema(
            tenant_id=tenant_id,
            headline=headline,
            summary=summary,
            metrics={
                "total_products": overview["total_products"],
                "low_stock_count": overview["low_stock_count"],
                "urgent_task_count": urgent_count,
                "communication_style": profile.communication_style.value,
                "priority_focus": profile.priority_focus.value,
            },
            recommended_tasks=tasks,
        )

        briefing_row = AIAdminBriefingORM(
            tenant_id=tenant_id,
            headline=briefing.headline,
            summary=briefing.summary,
            metrics=briefing.metrics,
            recommended_task_keys=[task.task_key for task in tasks],
            generated_at=briefing.generated_at,
        )
        session.add(briefing_row)
        await session.flush()
        briefing.id = briefing_row.id
        return briefing
