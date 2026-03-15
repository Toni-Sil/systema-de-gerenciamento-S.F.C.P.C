"""User service: registration, authentication, and tenant-scoped lookup.

Security contract:
  - Passwords are NEVER stored or logged in plain text.
  - Every created user is scoped to the current tenant (enforced by BaseRepository).
  - Login is rate-limited upstream by RateLimiterMiddleware.
"""
import logging
from uuid import UUID, uuid4
from datetime import datetime

from fastapi import HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from auth.password_handler import hash_password, verify_password
from auth.jwt_handler import create_jwt_token
from auth.tenant_context import get_tenant_id
from models.entities import UserCreateSchema, UserSchema

logger = logging.getLogger(__name__)


class UserService:
    """Handles user lifecycle within a tenant."""

    def __init__(self, session: AsyncSession):
        self.session = session

    async def register(self, data: UserCreateSchema) -> UserSchema:
        """Creates a new user. Raises 409 if username or email already exists."""
        tenant_id = get_tenant_id()
        if not tenant_id:
            raise HTTPException(status_code=403, detail="Tenant context missing")

        # Import ORM model here to avoid circular imports at module level
        from db.orm_models import UserORM

        # Uniqueness check (username + email) scoped to tenant
        duplicate = await self.session.execute(
            select(UserORM).where(
                UserORM.tenant_id == tenant_id,
                (UserORM.username == data.username) | (UserORM.email == data.email),
            )
        )
        if duplicate.scalar_one_or_none():
            raise HTTPException(
                status_code=409,
                detail="Username or e-mail already registered for this tenant",
            )

        user_orm = UserORM(
            id=uuid4(),
            tenant_id=tenant_id,
            username=data.username,
            email=data.email,
            role=data.role,
            hashed_password=hash_password(data.plain_password),
            is_active=True,
            created_at=datetime.utcnow(),
        )
        self.session.add(user_orm)
        await self.session.flush()

        logger.info(
            "user_registered",
            extra={"tenant_id": str(tenant_id), "username": data.username, "role": data.role},
        )
        return UserSchema.model_validate(user_orm)

    async def authenticate(self, username: str, plain_password: str) -> dict:
        """Validates credentials and returns a JWT access token payload.

        Raises 401 on wrong username or password (generic message to prevent
        username enumeration attacks).
        """
        tenant_id = get_tenant_id()
        if not tenant_id:
            raise HTTPException(status_code=403, detail="Tenant context missing")

        from db.orm_models import UserORM

        result = await self.session.execute(
            select(UserORM).where(
                UserORM.tenant_id == tenant_id,
                UserORM.username == username,
                UserORM.is_active == True,
            )
        )
        user_orm = result.scalar_one_or_none()

        # Constant-time comparison even on missing user (prevents timing attack)
        dummy_hash = "$2b$12$invalidhashfortimingsafety000000000000000000000"
        stored_hash = user_orm.hashed_password if user_orm else dummy_hash

        if not verify_password(plain_password, stored_hash) or user_orm is None:
            logger.warning(
                "login_failed",
                extra={"tenant_id": str(tenant_id), "username": username},
            )
            raise HTTPException(status_code=401, detail="Invalid credentials")

        token = create_jwt_token(
            tenant_id=str(tenant_id),
            user_id=str(user_orm.id),
            role=user_orm.role,
        )
        logger.info(
            "login_success",
            extra={"tenant_id": str(tenant_id), "user_id": str(user_orm.id)},
        )
        return {"access_token": token, "token_type": "bearer", "role": user_orm.role}
