"""Pydantic схемы для авторизации."""

from pydantic import BaseModel, EmailStr, Field, field_validator


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
    # MVP / тест: без сложных правил (достаточно длины). Ужесточить перед публичным релизом.
    password: str = Field(min_length=4, max_length=128)
    full_name: str | None = None

    @field_validator("password")
    @classmethod
    def password_non_empty_chars(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Пароль не может состоять только из пробелов")
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


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class WhoamiResponse(BaseModel):
    user: dict
