"""Pydantic schemas for tournaments."""

from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator

from app.models.tournament import clone_tournament_settings


class TournamentCreateRequest(BaseModel):
    title: str | None = None
    tournament_settings: dict[str, Any] | None = None

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


class TournamentUpdateRequest(BaseModel):
    title: str | None = None
    tournament_settings: dict[str, Any] | None = None

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
    tournament_settings: dict[str, Any]
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
            tournament_settings=clone_tournament_settings(tournament.tournament_settings),
            created_at=tournament.created_at,
            updated_at=tournament.updated_at,
            closed_at=tournament.closed_at,
        )


class TournamentActivateRequest(BaseModel):
    code: str
    display_name: str = Field(max_length=100)

    @field_validator("code")
    @classmethod
    def validate_code(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Код турнира обязателен")
        return normalized

    @field_validator("display_name")
    @classmethod
    def validate_display_name(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Имя участника обязательно")
        return normalized


class TournamentParticipantResponse(BaseModel):
    id: str
    display_name: str

    @classmethod
    def from_model(cls, participant) -> "TournamentParticipantResponse":
        return cls(
            id=str(participant.id),
            display_name=participant.display_name,
        )


class TournamentActivationTournamentResponse(BaseModel):
    id: str
    title: str
    code: str
    status: str
    max_rounds: int
    attempt_duration_seconds: int
    tournament_settings: dict[str, Any]

    @classmethod
    def from_model(cls, tournament) -> "TournamentActivationTournamentResponse":
        return cls(
            id=str(tournament.id),
            title=tournament.title,
            code=tournament.code,
            status=tournament.status.value if hasattr(tournament.status, "value") else str(tournament.status),
            max_rounds=int(tournament.max_rounds),
            attempt_duration_seconds=int(tournament.attempt_duration_seconds),
            tournament_settings=clone_tournament_settings(tournament.tournament_settings),
        )


class TournamentActivateResponse(BaseModel):
    participant_token: str
    token_type: str = "Participant"
    tournament: TournamentActivationTournamentResponse
    participant: TournamentParticipantResponse


class TournamentAttemptSubmitRequest(BaseModel):
    participant_token: str
    finish_reason: str | None = None
    rounds_completed: int = Field(ge=0)
    errors_total: int = Field(ge=0)
    time_spent_seconds: int = Field(ge=0, le=86400)

    @field_validator("participant_token")
    @classmethod
    def validate_participant_token(cls, value: str) -> str:
        normalized = value.strip()
        if not normalized:
            raise ValueError("Participant token is required")
        return normalized

    @field_validator("finish_reason")
    @classmethod
    def validate_finish_reason(cls, value: str | None) -> str | None:
        if value is None:
            return None
        normalized = value.strip()
        return normalized if normalized else None


class TournamentBestResultResponse(BaseModel):
    attempt_number: int
    errors_total: int
    time_spent_seconds: int

    @classmethod
    def from_model(cls, attempt) -> "TournamentBestResultResponse":
        return cls(
            attempt_number=int(attempt.attempt_number),
            errors_total=int(attempt.errors_total),
            time_spent_seconds=int(attempt.time_spent_seconds),
        )


class TournamentAttemptSubmitResponse(BaseModel):
    attempt_id: str
    attempt_number: int
    status: str
    finish_reason: str | None = None
    rounds_completed: int
    errors_total: int
    time_spent_seconds: int
    submitted_at: datetime | None = None
    improved: bool
    best_result: TournamentBestResultResponse | None = None
    rank: int | None = None


class TournamentLeaderboardEntryResponse(BaseModel):
    rank: int
    participant_id: str
    display_name: str
    attempt_id: str
    attempt_number: int
    errors_total: int
    time_spent_seconds: int
    submitted_at: datetime | None = None


class TournamentLeaderboardResponse(BaseModel):
    tournament_id: str
    status: str
    entries: list[TournamentLeaderboardEntryResponse]


class TournamentPublicPageResponse(BaseModel):
    tournament: TournamentActivationTournamentResponse
    leaderboard: TournamentLeaderboardResponse
