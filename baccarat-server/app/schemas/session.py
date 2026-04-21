"""Pydantic схемы для живых сессий."""

from datetime import datetime

from pydantic import BaseModel, Field
from typing import Any


class SessionCreateRequest(BaseModel):
    """Запрос на создание live-сессии."""

    duration_minutes: int = Field(default=30, ge=5, le=120)
    max_rounds: int | None = Field(default=None, ge=1, le=500)


class SessionStartResponse(BaseModel):
    message: str
    session_id: str
    status: str
    started_at: datetime


class SessionEndResponse(BaseModel):
    message: str
    session_id: str
    status: str
    ended_at: datetime
    end_reason: str


class SessionCreateResponse(BaseModel):
    session_id: str
    room_code: str
    status: str
    duration_seconds: int
    max_rounds: int | None
    websocket_url: str
    created_at: datetime | None = None


class ActiveLiveSessionResponse(BaseModel):
    """Текущая live-сессия комнаты (для дилера в лобби)."""

    session_id: str
    room_code: str
    status: str
    websocket_url: str
    round_seed: str | None = None
    started_at: datetime | None = None
    duration_seconds: int | None = None


class RoundResultIn(BaseModel):
    round_number: int = Field(ge=1)
    accuracy: float = Field(ge=0, le=100)
    errors: list[dict[str, Any] | str] = Field(default_factory=list)
    time_spent_seconds: int = Field(ge=3)
    player_third_card: bool | None = None
    banker_third_card: bool | None = None
    winner_chosen: str | None = None
    winner_correct: bool | None = None
    payout_correct: bool | None = None
    lives_remaining: int | None = None
    round_context: dict[str, Any] = Field(default_factory=dict)


class SessionResultsResponse(BaseModel):
    session_id: str
    status: str
    total_participants: int
    total_round_results: int
    dealers: list[dict]
