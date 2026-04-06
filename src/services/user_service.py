"""User registration and authentication service.

Responsibilities:
- Register new users with hashed passwords (bcrypt)
- Authenticate credentials and issue JWT tokens
- Enforce username/email uniqueness per tenant
"""
import logging
from uuid import UUID

from fastapi import HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from auth.jwt_handler import create_jwt_token
from auth.password_handler import hash_password, verify_password
from models.entities import UserCreateSchema, UserSchema, SignupSchema, LoginSchema, UserRole
from db.orm_models import UserORM, TenantORM

logger = logging.getLogger(__name__)


class UserService:

    @staticmethod
    async def signup_company(data: SignupSchema, session: AsyncSession) -> UserSchema:
        """New signup flow: Creates a Tenant AND the first Admin user."""
        # Check global email uniqueness
        existing_email = await session.execute(
            select(UserORM).where(UserORM.email == data.email)
        )
        if existing_email.scalar_one_or_none():
            raise HTTPException(status_code=409, detail="This email is already registered")

        # 1. Create Tenant
        slug = data.company_name.lower().replace(" ", "-")[:50]
        new_tenant = TenantORM(
            name=data.company_name,
            slug=slug,
            is_active=True
        )
        session.add(new_tenant)
        await session.flush() # Get tenant ID

        # 2. Create Admin User
        orm_user = UserORM(
            tenant_id=new_tenant.id,
            username=data.username,
            email=data.email,
            hashed_password=hash_password(data.password),
            role=UserRole.ADMIN,
        )
        session.add(orm_user)
        await session.commit()

        logger.info(f"signup_complete tenant={new_tenant.id} admin={orm_user.id}")

        return UserSchema(
            id=orm_user.id,
            tenant_id=orm_user.tenant_id,
            username=orm_user.username,
            email=orm_user.email,
            role=orm_user.role,
            is_active=orm_user.is_active,
            created_at=orm_user.created_at,
        )

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
            is_active=orm_user.is_active,
            created_at=orm_user.created_at,
        )

    @staticmethod
    async def authenticate(
        email: str,
        plain_password: str,
        session: AsyncSession,
    ) -> dict:
        """Validates credentials and returns a JWT access token.
        Raises 401 on any failure — never reveals whether email or password was wrong.
        """
        result = await session.execute(
            select(UserORM).where(
                UserORM.email == email,
                UserORM.is_active == True,
            )
        )
        user = result.scalar_one_or_none()

        # Constant-time comparison: always verify even if user not found (prevents timing attacks)
        dummy_hash = "$2b$12$invalidhashfortimingprotection000000000000000000000"
        stored_hash = user.hashed_password if user else dummy_hash
        password_ok = verify_password(plain_password, stored_hash)

        if not user or not password_ok:
            logger.warning(f"auth_failed email={email}")
            raise HTTPException(status_code=401, detail="Invalid credentials")

        token = create_jwt_token(
            tenant_id=str(user.tenant_id),
            user_id=str(user.id),
            role=user.role.value,
        )
        logger.info(f"auth_success user={user.id} tenant={user.tenant_id}")
        return {"access_token": token, "token_type": "bearer", "username": user.username, "tenant_id": str(user.tenant_id)}
