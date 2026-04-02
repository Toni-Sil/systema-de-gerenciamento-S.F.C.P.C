from typing import Optional, Dict, Any, List
from uuid import UUID
import json
import uuid
from datetime import date

from models.entities import MovementType, MovementSchema, ProductSchema, ExpenseSchema, ExpenseCategory
from db.session import get_session
from db.orm_models import ProductORM, StockBalanceORM
from sqlalchemy import select, func


class LLMTools:
    """Ferramentas (Functions) que o LLM poderá acionar para interagir com o SFC-PC."""

    # ------------------------------------------------------------------
    # TOOL: record_movement
    # ------------------------------------------------------------------
    @staticmethod
    async def record_movement(
        tenant_id: UUID,
        product_code: str,
        type: str,
        quantity: float,
        session=None,
        notes: Optional[str] = None,
        reference_doc: Optional[str] = None,
    ) -> str:
        """
        Registra uma movimentação de estoque (ENTRY, EXIT, ADJUSTMENT, TRANSFER).
        Aceita product_code ou busca por correspondência parcial de descrição.
        """
        from services.stock_service import StockService

        try:
            async with get_session() as db:
                result = await db.execute(
                    select(ProductORM).where(
                        ProductORM.tenant_id == tenant_id,
                        ProductORM.is_active == True,
                        ProductORM.code == product_code,
                    )
                )
                product = result.scalar_one_or_none()

                if not product:
                    return json.dumps({
                        "status": "error",
                        "message": f"Produto '{product_code}' não encontrado. Use search_product para localizar o código correto."
                    })

                mov_type = MovementType[type.upper()]
                movement = MovementSchema(
                    id=uuid.uuid4(),
                    tenant_id=tenant_id,
                    product_id=product.id,
                    type=mov_type,
                    quantity=quantity,
                    notes=notes,
                    reference_doc=reference_doc,
                    location_id=None,
                    batch_id=None,
                )
                balance_obj = await StockService.process_movement(movement, db)
                await db.commit()
                return json.dumps({
                    "status": "success",
                    "message": "Movimentação registrada com sucesso.",
                    "product_code": product_code,
                    "new_balance": balance_obj.balance,
                })
        except KeyError:
            return json.dumps({"status": "error", "message": f"Tipo de movimentação inválido: '{type}'. Use ENTRY, EXIT, ADJUSTMENT ou TRANSFER."})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: search_product  (NOVA)
    # ------------------------------------------------------------------
    @staticmethod
    async def search_product(tenant_id: UUID, query: str) -> str:
        """
        Busca produtos por código exato OU por correspondência parcial de descrição.
        Retorna lista com code, description, unit, min_stock, category.
        """
        try:
            async with get_session() as db:
                result = await db.execute(
                    select(ProductORM).where(
                        ProductORM.tenant_id == tenant_id,
                        ProductORM.is_active == True,
                    )
                )
                all_products = result.scalars().all()

            query_lower = query.lower()
            matches = [
                {
                    "code": p.code,
                    "description": p.description,
                    "unit": p.unit,
                    "min_stock": p.min_stock,
                    "category": p.category.value if p.category else None,
                }
                for p in all_products
                if query_lower in p.code.lower() or query_lower in p.description.lower()
            ]

            if not matches:
                return json.dumps({"status": "not_found", "message": f"Nenhum produto encontrado para '{query}'.", "data": []})

            return json.dumps({"status": "success", "data": matches, "count": len(matches)})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: create_product  (NOVA)
    # ------------------------------------------------------------------
    @staticmethod
    async def create_product(
        tenant_id: UUID,
        code: str,
        description: str,
        unit: str,
        category: Optional[str] = None,
        min_stock: float = 0.0,
    ) -> str:
        """
        Cadastra um novo produto no catálogo do tenant.
        """
        try:
            async with get_session() as db:
                # Verifica duplicata
                existing = await db.execute(
                    select(ProductORM).where(
                        ProductORM.tenant_id == tenant_id,
                        ProductORM.code == code,
                    )
                )
                if existing.scalar_one_or_none():
                    return json.dumps({"status": "error", "message": f"Produto com código '{code}' já existe."})

                from models.entities import ProductCategory
                cat = None
                if category:
                    try:
                        cat = ProductCategory(category.upper())
                    except ValueError:
                        pass

                new_product = ProductORM(
                    id=uuid.uuid4(),
                    tenant_id=tenant_id,
                    code=code,
                    description=description,
                    unit=unit,
                    min_stock=min_stock,
                    category=cat,
                    is_active=True,
                )
                db.add(new_product)
                await db.commit()

            return json.dumps({
                "status": "success",
                "message": f"Produto '{code}' cadastrado com sucesso.",
                "code": code,
                "description": description,
            })
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: get_inventory_status
    # ------------------------------------------------------------------
    @staticmethod
    async def get_inventory_status(tenant_id: UUID) -> str:
        """
        Retorna o resumo da inteligência do estoque atual (Gold Layer).
        """
        try:
            from data.gold_service import GoldLayerService
            async with get_session() as db:
                summary = await GoldLayerService.get_inventory_summary(tenant_id, db)
            return json.dumps({"status": "success", "data": summary})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: get_low_stock_alerts  (NOVA)
    # ------------------------------------------------------------------
    @staticmethod
    async def get_low_stock_alerts(tenant_id: UUID) -> str:
        """
        Retorna produtos com saldo atual abaixo do min_stock definido.
        """
        try:
            async with get_session() as db:
                result = await db.execute(
                    select(
                        ProductORM.code,
                        ProductORM.description,
                        ProductORM.min_stock,
                        StockBalanceORM.balance,
                    )
                    .join(StockBalanceORM, StockBalanceORM.product_id == ProductORM.id)
                    .where(
                        ProductORM.tenant_id == tenant_id,
                        ProductORM.is_active == True,
                        StockBalanceORM.balance < ProductORM.min_stock,
                    )
                )
                rows = result.fetchall()

            alerts = [
                {
                    "code": r.code,
                    "description": r.description,
                    "min_stock": r.min_stock,
                    "current_balance": r.balance,
                    "deficit": round(r.min_stock - r.balance, 2),
                }
                for r in rows
            ]

            if not alerts:
                return json.dumps({"status": "success", "message": "Nenhum produto em situação crítica de estoque.", "data": []})

            return json.dumps({"status": "success", "data": alerts, "count": len(alerts)})
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: register_expense  (NOVA)
    # ------------------------------------------------------------------
    @staticmethod
    async def register_expense(
        tenant_id: UUID,
        value: float,
        category: str,
        supplier: Optional[str] = None,
        expense_date: Optional[str] = None,
        reference_doc: Optional[str] = None,
    ) -> str:
        """
        Registra uma despesa financeira (ex: nota fiscal, frete, mão de obra).
        """
        from services.financial_service import FinancialService
        from datetime import date as date_type
        try:
            async with get_session() as db:
                parsed_date = date_type.fromisoformat(expense_date) if expense_date else date_type.today()
                try:
                    cat = ExpenseCategory(category)
                except ValueError:
                    cat = ExpenseCategory.OTHER

                expense = ExpenseSchema(
                    tenant_id=tenant_id,
                    value=value,
                    category=cat,
                    supplier=supplier,
                    expense_date=parsed_date,
                    reference_doc=reference_doc,
                )
                result = await FinancialService.create_expense(expense, db)
                await db.commit()

            return json.dumps({
                "status": "success",
                "message": "Despesa registrada com sucesso.",
                "value": value,
                "category": cat.value,
                "supplier": supplier,
            })
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})

    # ------------------------------------------------------------------
    # TOOL: get_financial_summary  (NOVA)
    # ------------------------------------------------------------------
    @staticmethod
    async def get_financial_summary(
        tenant_id: UUID,
        period_start: str,
        period_end: str,
    ) -> str:
        """
        Retorna resumo financeiro do período (despesas, entradas, saídas, margem bruta).
        """
        from services.financial_service import FinancialService
        from datetime import date as date_type
        try:
            async with get_session() as db:
                start = date_type.fromisoformat(period_start)
                end = date_type.fromisoformat(period_end)
                summary = await FinancialService.get_period_summary(tenant_id, start, end, db)

            return json.dumps({
                "status": "success",
                "data": summary.model_dump(mode="json"),
            })
        except Exception as e:
            return json.dumps({"status": "error", "message": str(e)})
