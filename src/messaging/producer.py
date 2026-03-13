import json
from uuid import UUID
from typing import Any, Dict
import asyncio
import logging

logger = logging.getLogger(__name__)

class EventBus:
    """
    Mocked event bus to simulate Kafka/RabbitMQ publishing and consuming asynchronously.
    """
    def __init__(self):
        self.published_events = []
        self._queue = asyncio.Queue()
        self._worker_task: asyncio.Task | None = None

    async def start_worker(self):
        if self._worker_task is None:
            self._worker_task = asyncio.create_task(self._consume_loop())

    async def publish(self, topic: str, message: Dict[str, Any]):
        event = {
            "topic": topic,
            "data": message
        }
        self.published_events.append(event)
        logger.info(f" [EVENT PUBLISHED] Topic: {topic} | Data: {json.dumps(message, indent=2, default=str)}")
        await self._queue.put(event)
        
    async def _consume_loop(self):
        from messaging.consumers.inventory_alerts import process_movement_event
        while True:
            event = await self._queue.get()
            topic = event["topic"]
            message = event["data"]
            try:
                if topic == "stock.movement":
                    await process_movement_event(message)
                elif topic == "finance.invoice_created":
                    # Placeholder for Phase 6 Financial Events
                    pass
            except Exception as e:
                logger.error(f"Error processing event {topic}: {e}")
            finally:
                self._queue.task_done()

# Global producer instance
producer = EventBus()
