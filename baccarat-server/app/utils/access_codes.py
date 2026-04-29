"""Helpers for room access codes."""

import hashlib
import hmac
import secrets

from app.config import settings


ACCESS_CODE_ALPHABET = "ABCDEFGHJKMNPQRTUVWXYZ23456789"
ACCESS_CODE_GROUP_SIZE = 4
ACCESS_CODE_GROUPS = 3


def generate_room_access_code() -> str:
    """Generate a human-readable room access code like XXXX-XXXX-XXXX."""
    raw_code = "".join(
        secrets.choice(ACCESS_CODE_ALPHABET)
        for _ in range(ACCESS_CODE_GROUP_SIZE * ACCESS_CODE_GROUPS)
    )
    return "-".join(
        raw_code[index : index + ACCESS_CODE_GROUP_SIZE]
        for index in range(0, len(raw_code), ACCESS_CODE_GROUP_SIZE)
    )


def normalize_room_access_code(code: str) -> str:
    """Normalize access code before hashing or future lookup."""
    return "".join(char for char in code.upper() if char.isalnum())


def hash_room_access_code(code: str) -> str:
    """Create stable lookup hash without storing the plaintext access code."""
    normalized = normalize_room_access_code(code)
    secret = settings.ROOM_ACCESS_CODE_PEPPER or settings.JWT_SECRET_KEY
    return hmac.new(
        secret.encode("utf-8"),
        f"room-access:{normalized}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def room_access_code_suffix(code: str) -> str:
    """Return last characters safe to show in list responses."""
    return normalize_room_access_code(code)[-ACCESS_CODE_GROUP_SIZE:]


def generate_participant_token() -> str:
    """Generate a local participant token returned only once to the game."""
    return "pt_" + secrets.token_urlsafe(32)


def hash_participant_token(token: str) -> str:
    """Create stable participant token hash without storing the plaintext token."""
    secret = (
        settings.PARTICIPANT_TOKEN_PEPPER
        or settings.ROOM_ACCESS_CODE_PEPPER
        or settings.JWT_SECRET_KEY
    )
    return hmac.new(
        secret.encode("utf-8"),
        f"participant-token:{token}".encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()
