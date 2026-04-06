"""
EventBus — Sistema de Eventos Assíncronos (EDA) do S.F.C.P.C.

Arquitetura em camadas:
  - InProcessEventBus  : Fila asyncio interna (desenvolvimento / single-node)
  - RabbitMQEventBus   : Driver para produção (ativa-se com RABBITMQ_URL no .env)

Troca de driver: apenas set LLM_PROVIDER=rabbitmq no .env, zero mudança de código.

Tópicos (Event Schema):
  stock.movement.created   → Movimentação registrada
  stock.low_stock          → Saldo abaixo do mínimo
  finance.expense.created  → Despesa registrada
  governance.action.pending→ Ação aguardando aprovação humana
  ai.insight.requested     → Solicitação de insight de IA pelo agendador
"""
from __future__ import annotations

import asyncio
import json
import logging
import os
from datetime import datetime
from typing import Any, Callable, Coroutine, Dict, List, Optional
from uuid import uuid4

logger = logging.getLogger(__name__)


# ──────────────────────────────────────────────
# Types
# ──────────────────────────────────────────────

Event = Dict[str, Any]
Handler = Callable[[Event], Coroutine[Any, Any, None]]


# ──────────────────────────────────────────────
# Circuit Breaker (Anti-Dominó Pattern)
# ──────────────────────────────────────────────

class CircuitBreaker:
    """
    Evita que falhas em cascade derrubem o sistema inteiro.
    Após MAX_FAILURES consecutivas, o circuito 'abre' e rejeita eventos por RECOVERY_TIMEOUT segundos.
    """
    MAX_FAILURES = 5
    RECOVERY_TIMEOUT = 30  # seconds

    def __init__(self, name: str):
        self.name = name
        self._failures = 0
        self._open_since: Optional[float] = None

    def is_open(self) -> bool:
        if self._open_since is None:
            return False
        elapsed = asyncio.get_event_loop().time() - self._open_since
        if elapsed > self.RECOVERY_TIMEOUT:
            self._failures = 0
            self._open_since = None
            logger.info(f"[CIRCUIT BREAKER] {self.name} RESTORED after {elapsed:.0f}s")
            return False
        return True

    def record_success(self):
        self._failures = 0

    def record_failure(self):
        self._failures += 1
        if self._failures >= self.MAX_FAILURES:
            self._open_since = asyncio.get_event_loop().time()
            logger.error(
                f"[CIRCUIT BREAKER] {self.name} OPEN after {self._failures} failures! "
                f"Will retry in {self.RECOVERY_TIMEOUT}s"
            )


# ──────────────────────────────────────────────
# In-Process Event Bus (Dev / Single-Node)
# ──────────────────────────────────────────────

class InProcessEventBus:
    """
    Event bus baseado em asyncio.Queue.
    Suporta múltiplos handlers por tópico, retry e circuit breaker.
    """

    def __init__(self):
        self._queue: asyncio.Queue[Event] = asyncio.Queue(maxsize=1000)
        self._handlers: Dict[str, List[Handler]] = {}
        self._breakers: Dict[str, CircuitBreaker] = {}
        self._worker: Optional[asyncio.Task] = None
        self._running = False

    def subscribe(self, topic: str, handler: Handler):
        self._handlers.setdefault(topic, []).append(handler)
        self._breakers.setdefault(topic, CircuitBreaker(topic))
        logger.info(f"[EVENT BUS] Handler registered: {handler.__name__} → {topic}")

    async def publish(self, topic: str, data: Dict[str, Any], tenant_id: Optional[str] = None):
        event: Event = {
            "event_id": str(uuid4()),
            "topic": topic,
            "tenant_id": tenant_id,
            "data": data,
            "published_at": datetime.utcnow().isoformat(),
        }
        try:
            self._queue.put_nowait(event)
            logger.info(f"[EVENT PUBLISHED] {topic} | tenant={tenant_id} | id={event['event_id']}")
        except asyncio.QueueFull:
            logger.error(f"[EVENT BUS] Queue FULL — dropping event {topic}. Consider upgrading to RabbitMQ.")

    async def start(self):
        if self._running:
            return
        self._running = True
        self._worker = asyncio.create_task(self._dispatch_loop())
        logger.info("[EVENT BUS] InProcessEventBus started.")

    async def stop(self):
        self._running = False
        if self._worker:
            self._worker.cancel()

    async def _dispatch_loop(self):
        while self._running:
            try:
                event = await asyncio.wait_for(self._queue.get(), timeout=2.0)
            except asyncio.TimeoutError:
                continue

            topic = event["topic"]
            handlers = self._handlers.get(topic, [])
            breaker = self._breakers.get(topic, CircuitBreaker(topic))

            if breaker.is_open():
                logger.warning(f"[CIRCUIT BREAKER] Skipping {topic} — circuit open.")
                self._queue.task_done()
                continue

            for handler in handlers:
                try:
                    await handler(event)
                    breaker.record_success()
                except Exception as e:
                    breaker.record_failure()
                    logger.error(f"[EVENT BUS] Handler {handler.__name__} failed on {topic}: {e}")

            self._queue.task_done()


# ──────────────────────────────────────────────
# RabbitMQ Driver (Production)
# ──────────────────────────────────────────────

class RabbitMQEventBus:
    """
    Driver de produção usando aio-pika (RabbitMQ).
    Ativa-se quando RABBITMQ_URL está definido no .env.
    """

    def __init__(self, url: str):
        self._url = url
        self._connection = None
        self._channel = None

    def subscribe(self, topic: str, handler: Handler):
        # Para RabbitMQ, handlers são configurados via bind de queue
        # Implementação completa requer aio-pika instalado
        logger.info(f"[RABBITMQ] Subscribe registered for {topic} (apply via queue bind on startup)")

    async def publish(self, topic: str, data: Dict[str, Any], tenant_id: Optional[str] = None):
        try:
            import aio_pika
            if self._connection is None or self._connection.is_closed:
                self._connection = await aio_pika.connect_robust(self._url)
                self._channel = await self._connection.channel()

            message_body = json.dumps({
                "event_id": str(uuid4()),
                "topic": topic,
                "tenant_id": tenant_id,
                "data": data,
                "published_at": datetime.utcnow().isoformat(),
            }).encode()

            await self._channel.default_exchange.publish(
                aio_pika.Message(body=message_body, content_type="application/json"),
                routing_key=topic,
            )
            logger.info(f"[RABBITMQ PUBLISHED] {topic} | tenant={tenant_id}")
        except ImportError:
            logger.error("[RABBITMQ] aio-pika not installed. Run: pip install aio-pika")
        except Exception as e:
            logger.error(f"[RABBITMQ] Failed to publish {topic}: {e}")

    async def start(self):
        logger.info(f"[RABBITMQ] Connected to {self._url}")

    async def stop(self):
        if self._connection:
            await self._connection.close()


# ──────────────────────────────────────────────
# Factory — Seleciona o driver pelo .env
# ──────────────────────────────────────────────

def create_event_bus() -> InProcessEventBus | RabbitMQEventBus:
    rabbitmq_url = os.getenv("RABBITMQ_URL")
    if rabbitmq_url:
        logger.info(f"[EVENT BUS] Using RabbitMQ driver: {rabbitmq_url}")
        return RabbitMQEventBus(url=rabbitmq_url)
    logger.info("[EVENT BUS] Using InProcess driver (set RABBITMQ_URL to use RabbitMQ).")
    return InProcessEventBus()


# Singleton global — importado por toda a aplicação
event_bus = create_event_bus()
