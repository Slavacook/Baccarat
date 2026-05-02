"""Pydantic schemas for tournaments."""

from datetime import datetime

from pydantic import BaseModel, field_validator


class TournamentCreateRequest(BaseModel):
    title: str | None = None

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        if not normalized:
            return None
        if len(normalized) > 255:
            raise ValueError("Название турнира не должно превышать 255 символов")
        return normalized


class TournamentResponse(BaseModel):
    id: str
    title: str
    code: str
    status: str
    max_rounds: int
    attempt_duration_seconds: int
    created_at: datetime | None = None
    updated_at: datetime | None = None
    closed_at: datetime | None = None

    @classmethod
    def from_model(cls, tournament) -> "TournamentResponse":
        return cls(
            id=str(tournament.id),
            title=tournament.title,
            code=tournament.code,
            status=tournament.status.value if hasattr(tournament.status, "value") else str(tournament.status),
            max_rounds=int(tournament.max_rounds),
            attempt_duration_seconds=int(tournament.attempt_duration_seconds),
            created_at=tournament.created_at,
            updated_at=tournament.updated_at,
            closed_at=tournament.closed_at,
        )
