"""Secure password hashing and verification using bcrypt.

Dependency: pip install bcrypt
"""
import bcrypt


def hash_password(plain_password: str) -> str:
    """Hashes a plain-text password using bcrypt with auto-generated salt."""
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Returns True if plain_password matches the stored bcrypt hash."""
    return bcrypt.checkpw(plain_password.encode("utf-8"), hashed_password.encode("utf-8"))
