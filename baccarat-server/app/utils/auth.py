"""Утилиты для работы с JWT."""

import uuid
from datetime import datetime, timedelta, timezone

import jwt

from app.config import settings


def create_access_token(user_id: str, role: str, room_id: str | None = None) -> str:
    """Создать access JWT-токен (действует 1 час)."""
    payload = {
        "sub": user_id,
        "role": role,
        "room_id": room_id,
        "type": "access",
        "exp": datetime.now(timezone.utc) + timedelta(minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def create_refresh_token(user_id: str, role: str, session_id: str) -> str:
    """Создать refresh JWT-токен (действует 7-30 дней)."""
    expire_days = (
        settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS_TRAINER
        if role == "trainer"
        else settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS_DEALER
    )
    payload = {
        "sub": user_id,
        "role": role,
        "type": "refresh",
        "session_id": session_id,
        "exp": datetime.now(timezone.utc) + timedelta(days=expire_days),
        "iat": datetime.now(timezone.utc),
    }
    return jwt.encode(payload, settings.JWT_SECRET_KEY, algorithm=settings.JWT_ALGORITHM)


def decode_token(token: str) -> dict:
    """Раскодировать JWT-токен. Бросает ошибку если невалидный."""
    return jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
