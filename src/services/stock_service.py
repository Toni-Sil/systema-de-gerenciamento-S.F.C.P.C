from typing import List, Optional
from uuid import UUID
from fastapi import HTTPException
from models.entities import MovementSchema, MovementType, StockBalanceSchema, ProductSchema
from db.base_repository import BaseRepository
from messaging.producer import producer

# Repositories (Shared/In-memory for MVP)
product_repo = BaseRepository(ProductSchema)
movement_repo = BaseRepository(MovementSchema)
balance_repo = BaseRepository(StockBalanceSchema)

class StockService:
    @staticmethod
    async def process_movement(movement: MovementSchema):
        """
        Business logic for processing a stock movement.
        1. Validates product existence.
        2. Adjusts balance.
        3. Persists movement.
        4. Triggers background events (EDA).
        """
        # 1. Get Product
        product = await product_repo.get_by_id(movement.product_id)
        if not product:
            raise HTTPException(status_code=404, detail="Product not found")

        # 2. Get current balance
        balance_obj = None
        balances = await balance_repo.get_all()
        for b in balances:
            if b.product_id == movement.product_id and b.batch_id == movement.batch_id and b.location_id == movement.location_id:
                balance_obj = b
                break

        if not balance_obj:
            balance_obj = StockBalanceSchema(
                tenant_id=movement.tenant_id,
                product_id=movement.product_id,
                batch_id=movement.batch_id,
                location_id=movement.location_id,
                balance=0.0
            )
            balance_obj = await balance_repo.create(balance_obj)

        # 3. Apply logic based on type
        prev_balance = balance_obj.balance
        if movement.type == MovementType.ENTRY:
            balance_obj.balance += movement.quantity
        elif movement.type == MovementType.EXIT:
            if balance_obj.balance < movement.quantity:
                raise HTTPException(status_code=400, detail="Insufficient stock")
            balance_obj.balance -= movement.quantity
        elif movement.type == MovementType.ADJUSTMENT:
            balance_obj.balance = movement.quantity # Direct set for adjustment
        
        # 4. Save movement
        await movement_repo.create(movement)

        # 5. Emit Event
        await producer.publish("stock.movement", {
            "tenant_id": str(movement.tenant_id),
            "product_id": str(movement.product_id),
            "product_code": product.code,
            "type": movement.type.value,
            "quantity": movement.quantity,
            "prev_balance": prev_balance,
            "new_balance": balance_obj.balance,
            "min_stock": product.min_stock
        })

        return balance_obj
