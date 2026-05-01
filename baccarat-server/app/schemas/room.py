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


# ═══════════════════════════════════════════════════════════════
# Room Access slots
# ═══════════════════════════════════════════════════════════════

class RoomAccessResponse(BaseModel):
    id: str
    slot_number: int
    access_code_suffix: str
    trainer_internal_name: str | None = None
    status: str
    dealer_id: str | None = None
    dealer_display_name: str | None = None
    activated_at: datetime | None = None
    revoked_at: datetime | None = None
    last_used_at: datetime | None = None
    created_at: datetime | None = None
    updated_at: datetime | None = None

    @classmethod
    def from_model(cls, access, dealer=None) -> "RoomAccessResponse":
        return cls(
            id=str(access.id),
            slot_number=access.slot_number,
            access_code_suffix=access.access_code_suffix,
            trainer_internal_name=access.trainer_internal_name,
            status=access.status,
            dealer_id=str(access.dealer_id) if access.dealer_id else None,
            dealer_display_name=dealer.display_name if dealer else None,
            activated_at=access.activated_at,
            revoked_at=access.revoked_at,
            last_used_at=access.last_used_at,
            created_at=access.created_at,
            updated_at=access.updated_at,
        )


class RoomAccessCreatedResponse(RoomAccessResponse):
    access_code: str


class RoomAccessCreateRequest(BaseModel):
    count: int = 1

    @field_validator("count")
    @classmethod
    def count_range(cls, value: int) -> int:
        if value < 1:
            raise ValueError("Нужно создать минимум один access slot")
        if value > 100:
            raise ValueError("За один запрос можно создать не больше 100 access slots")
        return value


class RoomAccessCreateResponse(BaseModel):
    accesses: list[RoomAccessCreatedResponse]


class RoomAccessUpdateRequest(BaseModel):
    trainer_internal_name: str | None = None

    @field_validator("trainer_internal_name")
    @classmethod
    def trainer_internal_name_length(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            return None
        if len(value) > 255:
            raise ValueError("Внутреннее имя не должно превышать 255 символов")
        return value


class RoomParticipantResponse(BaseModel):
    dealer_id: str
    display_name: str
    is_active: bool
    last_seen_at: datetime | None = None
    created_at: datetime | None = None
    online_status: str = "unknown"

    @classmethod
    def from_model(cls, dealer, online_status: str = "unknown") -> "RoomParticipantResponse":
        return cls(
            dealer_id=str(dealer.id),
            display_name=dealer.display_name,
            is_active=bool(dealer.is_active),
            last_seen_at=dealer.last_seen_at,
            created_at=dealer.created_at,
            online_status=online_status,
        )


class RoomPersonalInviteResponse(BaseModel):
    access_id: str
    trainer_internal_name: str | None = None
    created_at: datetime | None = None
    access_code_suffix: str | None = None
    status: str = "created"

    @classmethod
    def from_model(cls, access) -> "RoomPersonalInviteResponse":
        return cls(
            access_id=str(access.id),
            trainer_internal_name=access.trainer_internal_name,
            created_at=access.created_at,
            access_code_suffix=access.access_code_suffix,
            status=access.status,
        )


class RoomInviteResponse(BaseModel):
    id: str
    status: str
    invite_code_suffix: str
    expires_at: datetime
    created_at: datetime | None = None
    updated_at: datetime | None = None
    revoked_at: datetime | None = None

    @classmethod
    def from_model(cls, invite) -> "RoomInviteResponse":
        return cls(
            id=str(invite.id),
            status=invite.status,
            invite_code_suffix=invite.invite_code_suffix,
            expires_at=invite.expires_at,
            created_at=invite.created_at,
            updated_at=invite.updated_at,
            revoked_at=invite.revoked_at,
        )


class RoomInviteCreatedResponse(RoomInviteResponse):
    invite_code: str
