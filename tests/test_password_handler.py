"""Tests for bcrypt password utilities."""
import pytest
from src.auth.password_handler import hash_password, verify_password


def test_hash_is_not_plain_text():
    hashed = hash_password("mysecretpassword")
    assert hashed != "mysecretpassword"
    assert hashed.startswith("$2b$")


def test_correct_password_verifies():
    hashed = hash_password("correct-horse-battery")
    assert verify_password("correct-horse-battery", hashed) is True


def test_wrong_password_fails():
    hashed = hash_password("correct-horse-battery")
    assert verify_password("wrong-password", hashed) is False


def test_different_hashes_for_same_password():
    """bcrypt must generate a unique salt each time."""
    h1 = hash_password("same-password")
    h2 = hash_password("same-password")
    assert h1 != h2
    assert verify_password("same-password", h1)
    assert verify_password("same-password", h2)
