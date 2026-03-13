from typing import Any, Dict
import logging

logger = logging.getLogger(__name__)

async def process_movement_event(event_data: Dict[str, Any]):
    """
    Consumer logic for stock movements.
    Currently checks for low stock alerts.
    """
    product_code = event_data.get("product_code")
    new_balance = event_data.get("new_balance")
    min_stock = event_data.get("min_stock", 0)
    tenant_id = event_data.get("tenant_id")

    if new_balance < min_stock:
        logger.warning(f" !!! KAFKA CONSUMER ALERT [TENANT: {tenant_id}] !!! Product {product_code} is below minimum stock! (Balance: {new_balance}, Min: {min_stock})")
        # In a real system, this would send an email, push notification, or update an 'alerts' table.
