"""Pydantic схемы для комнат."""

from pydantic import BaseModel, field_validator
from typing import Any
from datetime import datetime


# ═══════════════════════════════════════════════════════════════
# Создание комнаты
# ═══════════════════════════════════════════════════════════════

class RoomSettingsCreate(BaseModel):
    """Настройки комнаты при создании."""
    survival_mode: bool = True
    lives_count: int = 7
    enable_main_bets: bool = True
    enable_tie_bets: bool = True
    enable_pair_bets: bool = False
    min_bet: int = 100
    max_bet: int = 10000
    tie_min_bet: int = 50
    tie_max_bet: int = 5000
    session_duration_minutes: int = 30
    enable_guest_bets: bool = True
    guest_count: int = 6


class RoomCreateRequest(BaseModel):
    """Запрос на создание комнаты."""
    name: str
    max_dealers: int = 20
    settings: RoomSettingsCreate | None = None

    @field_validator("name")
    @classmethod
    def name_length(cls, v: str) -> str:
        if len(v) < 3:
            raise ValueError("Название должно содержать минимум 3 символа")
        if len(v) > 100:
            raise ValueError("Название не должно превышать 100 символов")
        return v

    @field_validator("max_dealers")
    @classmethod
    def max_dealers_range(cls, v: int) -> int:
        if v < 5 or v > 100:
            raise ValueError("Максимум дилеров должен быть от 5 до 100")
        return v


class PinResponse(BaseModel):
    pin: str
    dealer_slot: int


class RoomResponse(BaseModel):
    id: str
    room_code: str
    name: str
    status: str
    max_dealers: int
    total_dealers: int
    total_sessions: int
    total_rounds: int
    created_at: datetime | None = None

    @classmethod
    def from_model(cls, room) -> "RoomResponse":
        return cls(
            id=str(room.id),
            room_code=room.room_code,
            name=room.name,
            status=room.status.value if hasattr(room.status, "value") else str(room.status),
            max_dealers=room.max_dealers,
            total_dealers=room.total_dealers,
            total_sessions=room.total_sessions,
            total_rounds=room.total_rounds,
            created_at=room.created_at,
        )


class RoomCreateResponse(BaseModel):
    room: RoomResponse
    pins: list[PinResponse]
