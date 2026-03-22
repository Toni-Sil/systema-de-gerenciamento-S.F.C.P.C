"""
Scheduler de tarefas periodicas usando APScheduler.

Tarefas registradas:
  - weekly_whatsapp_report : toda segunda-feira as 08:00 (America/Sao_Paulo)
  - daily_due_alert        : todo dia as 07:00 — alerta de vencimentos do dia

Ativar no lifespan do FastAPI chamando SchedulerService.start().
"""
import logging
import os
from datetime import datetime, timedelta

from apscheduler.schedulers.asyncio import AsyncIOScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)

_COMPANY_NAME = os.getenv("COMPANY_NAME", "S.F.C.P.C")
_TZ = "America/Sao_Paulo"
_AI_ADMIN_TENANT_IDS = [
    tenant_id.strip()
    for tenant_id in os.getenv("AI_ADMIN_TENANT_IDS", "").split(",")
    if tenant_id.strip()
]


class SchedulerService:
    _scheduler: AsyncIOScheduler | None = None

    # ------------------------------------------------------------------ #
    # Lifecycle
    # ------------------------------------------------------------------ #

    @classmethod
    def start(cls) -> None:
        if cls._scheduler and cls._scheduler.running:
            return
        cls._scheduler = AsyncIOScheduler(timezone=_TZ)

        # Relatorio semanal — segunda-feira 08:00
        cls._scheduler.add_job(
            cls._send_weekly_report,
            CronTrigger(day_of_week="mon", hour=8, minute=0, timezone=_TZ),
            id="weekly_whatsapp_report",
            replace_existing=True,
        )

        # Alerta diario de vencimentos — todo dia 07:00
        cls._scheduler.add_job(
            cls._send_daily_due_alert,
            CronTrigger(hour=7, minute=0, timezone=_TZ),
            id="daily_due_alert",
            replace_existing=True,
        )

        cls._scheduler.add_job(
            cls._generate_daily_admin_briefing,
            CronTrigger(hour=6, minute=45, timezone=_TZ),
            id="daily_admin_briefing",
            replace_existing=True,
        )

        cls._scheduler.start()
        logger.info("[SchedulerService] Iniciado. Jobs: weekly_report + daily_due_alert + daily_admin_briefing")

    @classmethod
    def stop(cls) -> None:
        if cls._scheduler and cls._scheduler.running:
            cls._scheduler.shutdown(wait=False)
            logger.info("[SchedulerService] Parado.")

    # ------------------------------------------------------------------ #
    # Jobs
    # ------------------------------------------------------------------ #

    @staticmethod
    async def _send_weekly_report() -> None:
        """Gera e envia o relatorio semanal para o gestor via WhatsApp."""
        from services.whatsapp_service import WhatsAppService
        from db.session import get_session
        from services.financial_service import FinancialService
        from services.stock_service import StockService

        logger.info("[SchedulerService] Gerando relatorio semanal...")
        try:
            now = datetime.now()
            week_end = now + timedelta(days=7)

            # Resumo financeiro do periodo
            async with get_session() as session:
                fin = await FinancialService.get_period_summary(
                    tenant_id=None,  # todos os tenants no modo single-tenant
                    period_start=now.date(),
                    period_end=week_end.date(),
                    session=session,
                )
                low_stock = await StockService.get_low_stock_items(session)

            lines = [
                f"\U0001f4ca *Relatorio Semanal \u2014 {_COMPANY_NAME}*",
                f"{now.strftime('%d/%m')} \u2013 {week_end.strftime('%d/%m/%Y')}",
                "",
            ]

            # Financeiro
            if fin:
                lines.append("\U0001f4b0 *Financeiro*")
                lines.append(f"- Receita prevista: R$ {getattr(fin, 'total_revenue', 0):.2f}")
                lines.append(f"- Despesas: R$ {getattr(fin, 'total_expenses', 0):.2f}")
                lines.append("")

            # Estoque critico
            if low_stock:
                lines.append(f"\U0001f4e6 *{len(low_stock)} item(s) critico(s) no estoque*")
                for item in low_stock[:5]:  # maximo 5 itens para nao poluir
                    lines.append(f"- {item.description}: {item.qty}/{item.minimum_stock} {item.unit}")
                if len(low_stock) > 5:
                    lines.append(f"  ... e mais {len(low_stock) - 5} item(s).")
                lines.append("")

            lines.append("_Gerado automaticamente pelo Agente S.F.C.P.C_")
            report = "\n".join(lines)

            await WhatsAppService.send_to_manager(report)
            logger.info("[SchedulerService] Relatorio semanal enviado.")

        except Exception as exc:
            logger.error("[SchedulerService] Falha no relatorio semanal: %s", exc)

    @staticmethod
    async def _send_daily_due_alert() -> None:
        """Envia alerta de vencimentos financeiros do dia e proximos 3 dias."""
        from services.whatsapp_service import WhatsAppService
        from db.session import get_session
        from services.financial_service import FinancialService

        logger.info("[SchedulerService] Verificando vencimentos do dia...")
        try:
            now = datetime.now()
            look_ahead = now + timedelta(days=3)

            async with get_session() as session:
                due = await FinancialService.get_due_events(
                    period_start=now.date(),
                    period_end=look_ahead.date(),
                    session=session,
                )

            if not due:
                logger.info("[SchedulerService] Nenhum vencimento nos proximos 3 dias.")
                return

            total = sum(getattr(e, 'amount', 0) or 0 for e in due)
            lines = [
                f"\u26a0\ufe0f *{len(due)} vencimento(s) nos proximos 3 dias \u2014 {_COMPANY_NAME}*",
                "",
            ]
            for event in due:
                dt = getattr(event, 'due_date', None) or getattr(event, 'date', '')
                title = getattr(event, 'title', str(event))
                amount = getattr(event, 'amount', None)
                valor = f" \u2014 R$ {amount:.2f}" if amount else ""
                lines.append(f"- {dt}: {title}{valor}")

            if total > 0:
                lines.append(f"\nTotal: R$ {total:.2f}")
            lines.append("\n_Agente S.F.C.P.C_")

            await WhatsAppService.send_to_manager("\n".join(lines))
            logger.info("[SchedulerService] Alerta de vencimentos enviado.")

        except Exception as exc:
            logger.error("[SchedulerService] Falha no alerta de vencimentos: %s", exc)

    @staticmethod
    async def _generate_daily_admin_briefing() -> None:
        """Gera a fila de trabalho administrativa diária da IA."""
        from uuid import UUID

        from db.session import get_session
        from services.ai_admin_service import AIAdminService

        if not _AI_ADMIN_TENANT_IDS:
            logger.info("[SchedulerService] Nenhum tenant configurado para daily_admin_briefing.")
            return

        for tenant_id_str in _AI_ADMIN_TENANT_IDS:
            try:
                tenant_id = UUID(tenant_id_str)
                async with get_session() as session:
                    briefing = await AIAdminService.generate_daily_briefing(tenant_id, session)
                logger.info(
                    "[SchedulerService] Briefing administrativo gerado.",
                    extra={
                        "tenant_id": tenant_id_str,
                        "headline": briefing.headline,
                        "task_count": len(briefing.recommended_tasks),
                    },
                )
            except Exception as exc:
                logger.error(
                    "[SchedulerService] Falha ao gerar briefing administrativo do tenant %s: %s",
                    tenant_id_str,
                    exc,
                )
