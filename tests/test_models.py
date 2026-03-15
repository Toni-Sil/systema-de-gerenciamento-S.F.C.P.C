"""Tests for Pydantic model validation."""
import pytest
from uuid import uuid4
from pydantic import ValidationError
from src.models.entities import (
    MovementSchema,
    MovementType,
    ProductSchema,
    ProductCategory,
    UserCreateSchema,
    UserRole,
    ExpenseSchema,
    ExpenseCategory,
)
from datetime import date


def _tenant() -> str:
    return str(uuid4())


def test_product_code_cannot_be_empty():
    with pytest.raises(ValidationError):
        ProductSchema(
            tenant_id=uuid4(),
            code="",
            description="Valid",
            unit="m",
        )


def test_movement_quantity_must_be_positive():
    with pytest.raises(ValidationError):
        MovementSchema(
            tenant_id=uuid4(),
            product_id=uuid4(),
            type=MovementType.ENTRY,
            quantity=0,   # Must be > 0
        )


def test_movement_quantity_negative_raises():
    with pytest.raises(ValidationError):
        MovementSchema(
            tenant_id=uuid4(),
            product_id=uuid4(),
            type=MovementType.EXIT,
            quantity=-5,
        )


def test_user_create_invalid_email_raises():
    with pytest.raises(ValidationError):
        UserCreateSchema(
            tenant_id=uuid4(),
            username="toni",
            email="not-an-email",
            plain_password="strongpassword",
        )


def test_user_create_short_password_raises():
    with pytest.raises(ValidationError):
        UserCreateSchema(
            tenant_id=uuid4(),
            username="toni",
            email="toni@example.com",
            plain_password="short",
        )


def test_expense_value_must_be_positive():
    with pytest.raises(ValidationError):
        ExpenseSchema(
            tenant_id=uuid4(),
            value=0.0,   # Must be > 0
            category=ExpenseCategory.LOGISTICS,
            expense_date=date.today(),
        )


def test_valid_product_schema():
    p = ProductSchema(
        tenant_id=uuid4(),
        code="SF-001",
        description="Espuma D28 60x80",
        unit="un",
        min_stock=5.0,
        category=ProductCategory.FOAM,
    )
    assert p.code == "SF-001"
    assert p.min_stock == 5.0
