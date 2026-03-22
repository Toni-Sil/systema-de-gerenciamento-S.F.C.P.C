"""User registration and authentication service.

Responsibilities:
- Register new users with hashed passwords (bcrypt)
- Authenticate credentials and issue JWT tokens
- Enforce username/email uniqueness per tenant
"""
import logging
from sqlalchemy import or_
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.jwt_handler import create_jwt_token
from auth.password_handler import hash_password, verify_password
from db.orm_models import UserORM
from models.entities import UserCreateSchema, UserSchema

logger = logging.getLogger(__name__)


class UserService:

    @staticmethod
    async def register(data: UserCreateSchema, session: AsyncSession) -> UserSchema:
        """Creates a new user. Raises 409 if username or email already exist in the tenant."""
        # Check uniqueness within the tenant
        existing = await session.execute(
            select(UserORM).where(
                UserORM.tenant_id == data.tenant_id,
                UserORM.username == data.username,
            )
        )
        if existing.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Username already exists for this tenant")

        existing_email = await session.execute(
            select(UserORM).where(
                UserORM.tenant_id == data.tenant_id,
                UserORM.email == data.email,
            )
        )
        if existing_email.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="Email already registered for this tenant")

        orm_user = UserORM(
            tenant_id=data.tenant_id,
            username=data.username,
            email=data.email,
            hashed_password=hash_password(data.plain_password),
            role=data.role,
        )
        session.add(orm_user)
        await session.flush()

        logger.info(f"user_registered tenant={data.tenant_id} user={orm_user.id} role={data.role}")

        return UserSchema(
            id=orm_user.id,
            tenant_id=orm_user.tenant_id,
            username=orm_user.username,
            email=orm_user.email,
            role=orm_user.role,
            hashed_password=orm_user.hashed_password,
            is_active=orm_user.is_active,
            created_at=orm_user.created_at,
        )

    @staticmethod
    async def authenticate(
        tenant_id: UUID | None,
        username: str | None,
        plain_password: str,
        session: AsyncSession,
        email: str | None = None,
    ) -> dict:
        """Validates credentials and returns a JWT access token.

        Supports the legacy username+tenant login flow and the current frontend
        email/password flow. When tenant_id is omitted we only authenticate via
        e-mail if there is a single active match; otherwise the caller must
        provide tenant context explicitly.
        """
        identity = (username or email or "").strip().lower()
        if not identity:
            raise HTTPException(status_code=400, detail="username or email is required")

        if tenant_id is not None:
            result = await session.execute(
                select(UserORM).where(
                    UserORM.tenant_id == tenant_id,
                    UserORM.is_active == True,
                    or_(
                        UserORM.username == identity,
                        UserORM.email == identity,
                    ),
                )
            )
            user = result.scalar_one_or_none()
        elif email:
            result = await session.execute(
                select(UserORM).where(
                    UserORM.email == email.lower(),
                    UserORM.is_active == True,
                )
            )
            matches = result.scalars().all()
            if len(matches) > 1:
                logger.warning("auth_failed_multiple_tenants email=%s", email.lower())
                raise HTTPException(
                    status_code=400,
                    detail="Multiple tenants found for this email. Provide tenant_id to continue.",
                )
            user = matches[0] if matches else None
        else:
            raise HTTPException(
                status_code=400,
                detail="tenant_id is required when authenticating with username",
            )

        auth_label = email.lower() if email else identity
        tenant_label = tenant_id or (user.tenant_id if user else None)

        # Constant-time comparison: always verify even if user not found (prevents timing attacks)
        dummy_hash = "$2b$12$invalidhashfortimingprotection000000000000000000000"
        stored_hash = user.hashed_password if user else dummy_hash
        password_ok = verify_password(plain_password, stored_hash)

        if not user or not password_ok:
            logger.warning("auth_failed tenant=%s identity=%s", tenant_label, auth_label)
            raise HTTPException(status_code=401, detail="Invalid credentials")

        token = create_jwt_token(
            tenant_id=str(user.tenant_id),
            user_id=str(user.id),
            role=user.role.value,
        )
        logger.info("auth_success tenant=%s user=%s", user.tenant_id, user.id)
        return {"access_token": token, "token_type": "bearer"}
