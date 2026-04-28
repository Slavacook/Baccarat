"""Pydantic схемы для авторизации."""

from pydantic import BaseModel, EmailStr, field_validator
import re


# ═══════════════════════════════════════════════════════════════
# ОБЩИЕ
# ═══════════════════════════════════════════════════════════════

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "Bearer"
    user: dict


# ═══════════════════════════════════════════════════════════════
# ТРЕНЕР — Регистрация
# ═══════════════════════════════════════════════════════════════

class TrainerRegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None

    @field_validator("password")
    @classmethod
    def password_strength(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Пароль должен содержать минимум 8 символов")
        if not re.search(r"[A-Z]", v):
            raise ValueError("Пароль должен содержать хотя бы одну заглавную букву")
        if not re.search(r"\d", v):
            raise ValueError("Пароль должен содержать хотя бы одну цифру")
        return v


class TrainerRegisterResponse(TokenResponse):
    pass


# ═══════════════════════════════════════════════════════════════
# ТРЕНЕР — Вход
# ═══════════════════════════════════════════════════════════════

class TrainerLoginRequest(BaseModel):
    email: EmailStr
    password: str


# ═══════════════════════════════════════════════════════════════
# ДИЛЕР — Вход
# ═══════════════════════════════════════════════════════════════

class DealerJoinRequest(BaseModel):
    room_code: str
    pin: str
    display_name: str

    @field_validator("pin")
    @classmethod
    def pin_format(cls, v: str) -> str:
        if not v.isdigit() or len(v) != 6:
            raise ValueError("PIN должен состоять из 6 цифр")
        return v


class DealerJoinResponse(TokenResponse):
    pass


# ═══════════════════════════════════════════════════════════════
# ДИЛЕР — Вход по инвайту
# ═══════════════════════════════════════════════════════════════

class DealerInviteJoinRequest(BaseModel):
    invite_token: str
    device_id: str
    display_name: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class WhoamiResponse(BaseModel):
    user: dict
