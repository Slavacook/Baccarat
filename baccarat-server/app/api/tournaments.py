"""Trainer API for tournament foundation."""

from datetime import datetime, timezone
from typing import Any
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_trainer
from app.models.tournament_attempt import TournamentAttempt, TournamentAttemptStatus
from app.models.tournament import (
    Tournament,
    TournamentStatus,
    clone_tournament_settings,
    default_tournament_settings,
)
from app.models.tournament_participant import TournamentParticipant
from app.models.tournament_participant_token import (
    TournamentParticipantToken,
    TournamentParticipantTokenStatus,
)
from app.models.trainer import Trainer
from app.schemas.tournament import (
    TournamentActivateRequest,
    TournamentActivateResponse,
    TournamentActivationTournamentResponse,
    TournamentAttemptSubmitRequest,
    TournamentAttemptSubmitResponse,
    TournamentBestResultResponse,
    TournamentCreateRequest,
    TournamentLeaderboardEntryResponse,
    TournamentLeaderboardResponse,
    TournamentParticipantResponse,
    TournamentPublicPageResponse,
    TournamentResponse,
    TournamentUpdateRequest,
)
from app.utils.access_codes import (
    generate_participant_token,
    generate_tournament_code,
    hash_participant_token,
)
from app.utils.tournament_participants import clean_tournament_display_name, normalize_tournament_display_name

router = APIRouter(prefix="/tournaments")

DEFAULT_TOURNAMENT_MAX_ROUNDS = 50
DEFAULT_TOURNAMENT_ATTEMPT_DURATION_SECONDS = 600
DEFAULT_TOURNAMENT_TITLE_PREFIX = "Турнир"
MAX_TOURNAMENT_ATTEMPT_RETRIES = 2
FINISH_PRESET_ROUNDS_ERRORS = "rounds_errors"
FINISH_PRESET_TIME_ERRORS = "time_errors"
FINISH_PRESET_ROUNDS_TIME = "rounds_time"
ALLOWED_FINISH_PRESETS = {
    FINISH_PRESET_ROUNDS_ERRORS,
    FINISH_PRESET_TIME_ERRORS,
    FINISH_PRESET_ROUNDS_TIME,
}
FINISH_RULES_VALIDATION_ERROR = (
    "Нельзя одновременно использовать раздачи, время и лимит ошибок. "
    "Выберите один из трёх режимов завершения турнира."
)


def normalize_tournament_code_for_lookup(code: str) -> str:
    compact = "".join(char for char in code.upper() if char.isalnum())
    if len(compact) != 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tournament code must contain 8 characters",
        )
    return f"{compact[:4]}-{compact[4:]}"


def _normalize_positive_limit(value: Any, field_name: str) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} must be a positive integer or null",
        )
    if isinstance(value, str):
        normalized = value.strip()
        if normalized == "":
            return None
        if not normalized.isdigit():
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=f"{field_name} must be a positive integer or null",
            )
        parsed = int(normalized)
    elif isinstance(value, int):
        parsed = int(value)
    elif isinstance(value, float) and value.is_integer():
        parsed = int(value)
    else:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} must be a positive integer or null",
        )

    if parsed <= 0:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} must be a positive integer",
        )
    return parsed


def normalize_tournament_settings_payload(
    raw_settings: dict[str, Any] | None,
) -> tuple[dict[str, Any], int, int]:
    settings = clone_tournament_settings(raw_settings)
    finish_rule_keys = {"finish_preset", "max_rounds", "max_errors", "max_duration_minutes"}
    if not any(key in settings for key in finish_rule_keys):
        default_finish_settings = default_tournament_settings()
        for key in finish_rule_keys:
            settings[key] = default_finish_settings.get(key)

    finish_preset = str(settings.get("finish_preset", FINISH_PRESET_ROUNDS_TIME)).strip()
    if finish_preset not in ALLOWED_FINISH_PRESETS:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="finish_preset must be one of: rounds_errors, time_errors, rounds_time",
        )

    max_rounds = _normalize_positive_limit(settings.get("max_rounds"), "max_rounds")
    max_errors = _normalize_positive_limit(settings.get("max_errors"), "max_errors")
    max_duration_minutes = _normalize_positive_limit(
        settings.get("max_duration_minutes"),
        "max_duration_minutes",
    )

    active_limits = {
        field_name
        for field_name, field_value in {
            "max_rounds": max_rounds,
            "max_errors": max_errors,
            "max_duration_minutes": max_duration_minutes,
        }.items()
        if field_value is not None
    }

    if len(active_limits) == 0 or len(active_limits) > 2:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=FINISH_RULES_VALIDATION_ERROR,
        )

    allowed_active_limits_by_preset = {
        FINISH_PRESET_ROUNDS_ERRORS: [
            {"max_rounds"},
            {"max_rounds", "max_errors"},
        ],
        FINISH_PRESET_TIME_ERRORS: [
            {"max_duration_minutes"},
            {"max_duration_minutes", "max_errors"},
        ],
        FINISH_PRESET_ROUNDS_TIME: [
            {"max_rounds"},
            {"max_rounds", "max_duration_minutes"},
        ],
    }
    if active_limits not in allowed_active_limits_by_preset[finish_preset]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=FINISH_RULES_VALIDATION_ERROR,
        )

    normalized_settings = clone_tournament_settings(settings)
    normalized_settings["finish_preset"] = finish_preset
    normalized_settings["max_rounds"] = max_rounds
    normalized_settings["max_errors"] = max_errors
    normalized_settings["max_duration_minutes"] = max_duration_minutes

    max_rounds_mirror = max_rounds if max_rounds is not None else 0
    attempt_duration_seconds_mirror = (
        max_duration_minutes * 60 if max_duration_minutes is not None else 0
    )
    return normalized_settings, max_rounds_mirror, attempt_duration_seconds_mirror


async def get_owned_tournament_or_404(
    tournament_id: str,
    trainer: Trainer,
    db: AsyncSession,
) -> Tournament:
    try:
        tournament_uuid = uuid.UUID(tournament_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")

    result = await db.execute(select(Tournament).where(Tournament.id == tournament_uuid))
    tournament = result.scalar_one_or_none()
    if not tournament:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")
    if tournament.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not tournament owner")
    return tournament


async def get_tournament_or_404(tournament_id: str, db: AsyncSession) -> Tournament:
    try:
        tournament_uuid = uuid.UUID(tournament_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")

    result = await db.execute(select(Tournament).where(Tournament.id == tournament_uuid))
    tournament = result.scalar_one_or_none()
    if not tournament:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")
    return tournament


async def generate_unique_tournament_code(db: AsyncSession) -> str:
    for _ in range(20):
        code = generate_tournament_code()
        exists_res = await db.execute(select(Tournament.id).where(Tournament.code == code))
        if not exists_res.scalar_one_or_none():
            return code
    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not generate unique tournament code",
    )


async def verify_tournament_participant_token(
    participant_token: str,
    tournament_id: uuid.UUID,
    db: AsyncSession,
) -> tuple[TournamentParticipant, TournamentParticipantToken]:
    token_value = participant_token.strip() if isinstance(participant_token, str) else ""
    if not token_value:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Participant token is required",
        )
    if not token_value.startswith("pt_"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid participant token",
        )

    token_hash = hash_participant_token(token_value)
    token_res = await db.execute(
        select(TournamentParticipantToken).where(
            TournamentParticipantToken.token_hash == token_hash
        )
    )
    token_entry = token_res.scalar_one_or_none()
    if not token_entry:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid participant token",
        )
    if token_entry.status != TournamentParticipantTokenStatus.ACTIVE:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Participant token is not active",
        )

    participant = await db.get(
        TournamentParticipant,
        token_entry.tournament_participant_id,
    )
    if not participant:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Participant token participant is not valid",
        )
    if participant.tournament_id != tournament_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Participant does not belong to this tournament",
        )

    now = datetime.now(timezone.utc)
    participant.last_seen_at = now
    token_entry.last_used_at = now
    return participant, token_entry


def is_successful_tournament_attempt(
    tournament: Tournament,
    rounds_completed: int,
    time_spent_seconds: int,
    finish_reason: str = "",
) -> bool:
    normalized_finish_reason = normalize_finish_reason(finish_reason)
    active_finish_reasons = get_active_finish_reasons_for_tournament(tournament)
    if active_finish_reasons is not None and normalized_finish_reason != "":
        return normalized_finish_reason in active_finish_reasons
    return is_successful_tournament_attempt_legacy_compatible(
        tournament,
        rounds_completed,
        time_spent_seconds,
    )


def is_successful_tournament_attempt_legacy_compatible(
    tournament: Tournament,
    rounds_completed: int,
    time_spent_seconds: int,
) -> bool:
    settings = tournament.tournament_settings if isinstance(tournament.tournament_settings, dict) else {}
    has_new_finish_settings = "finish_preset" in settings
    if has_new_finish_settings:
        max_rounds = _settings_positive_int_or_none(settings.get("max_rounds"))
        max_duration_minutes = _settings_positive_int_or_none(settings.get("max_duration_minutes"))
        limit_checks: list[bool] = []
        if max_rounds is not None:
            limit_checks.append(int(rounds_completed) >= max_rounds)
        if max_duration_minutes is not None:
            limit_checks.append(int(time_spent_seconds) <= (max_duration_minutes * 60))
        if limit_checks:
            return all(limit_checks)
    return (
        int(rounds_completed) >= int(tournament.max_rounds)
        and int(time_spent_seconds) <= int(tournament.attempt_duration_seconds)
    )


def normalize_finish_reason(value: str | None) -> str:
    return value.strip() if isinstance(value, str) else ""


def _settings_positive_int_or_none(value: Any) -> int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value > 0 else None
    if isinstance(value, float):
        int_value = int(value)
        return int_value if float(int_value) == value and int_value > 0 else None
    if isinstance(value, str):
        normalized = value.strip()
        if not normalized or not normalized.isdigit():
            return None
        parsed = int(normalized)
        return parsed if parsed > 0 else None
    return None


def get_active_finish_reasons_for_tournament(tournament: Tournament) -> set[str] | None:
    settings = tournament.tournament_settings if isinstance(tournament.tournament_settings, dict) else {}
    if "finish_preset" not in settings:
        return None

    finish_preset = str(settings.get("finish_preset", "")).strip()
    if finish_preset not in ALLOWED_FINISH_PRESETS:
        return set()

    max_rounds = _settings_positive_int_or_none(settings.get("max_rounds"))
    max_errors = _settings_positive_int_or_none(settings.get("max_errors"))
    max_duration_minutes = _settings_positive_int_or_none(settings.get("max_duration_minutes"))

    active_reasons: set[str] = set()
    if finish_preset == FINISH_PRESET_ROUNDS_ERRORS:
        if max_rounds is not None:
            active_reasons.add("round_limit")
        if max_errors is not None:
            active_reasons.add("error_limit")
    elif finish_preset == FINISH_PRESET_TIME_ERRORS:
        if max_duration_minutes is not None:
            active_reasons.add("time_limit")
        if max_errors is not None:
            active_reasons.add("error_limit")
    elif finish_preset == FINISH_PRESET_ROUNDS_TIME:
        if max_rounds is not None:
            active_reasons.add("round_limit")
        if max_duration_minutes is not None:
            active_reasons.add("time_limit")

    return active_reasons


def is_attempt_better(candidate: TournamentAttempt, incumbent: TournamentAttempt) -> bool:
    candidate_key = (
        int(candidate.errors_total),
        int(candidate.time_spent_seconds),
        candidate.submitted_at or datetime.max.replace(tzinfo=timezone.utc),
        str(candidate.id),
    )
    incumbent_key = (
        int(incumbent.errors_total),
        int(incumbent.time_spent_seconds),
        incumbent.submitted_at or datetime.max.replace(tzinfo=timezone.utc),
        str(incumbent.id),
    )
    return candidate_key < incumbent_key


async def get_best_success_attempt_for_participant(
    tournament_participant_id: uuid.UUID,
    db: AsyncSession,
) -> TournamentAttempt | None:
    result = await db.execute(
        select(TournamentAttempt)
        .where(
            TournamentAttempt.tournament_participant_id == tournament_participant_id,
            TournamentAttempt.status == TournamentAttemptStatus.SUCCESS,
        )
        .order_by(
            TournamentAttempt.errors_total.asc(),
            TournamentAttempt.time_spent_seconds.asc(),
            TournamentAttempt.submitted_at.asc(),
            TournamentAttempt.id.asc(),
        )
        .limit(1)
    )
    return result.scalars().first()


async def get_next_attempt_number(
    tournament_participant_id: uuid.UUID,
    db: AsyncSession,
) -> int:
    result = await db.execute(
        select(func.max(TournamentAttempt.attempt_number)).where(
            TournamentAttempt.tournament_participant_id == tournament_participant_id
        )
    )
    max_attempt_number = result.scalar_one_or_none()
    return int(max_attempt_number or 0) + 1


async def get_tournament_leaderboard_rows(
    tournament_id: uuid.UUID,
    db: AsyncSession,
) -> list[tuple[TournamentParticipant, TournamentAttempt]]:
    result = await db.execute(
        select(TournamentParticipant, TournamentAttempt)
        .join(
            TournamentAttempt,
            TournamentAttempt.tournament_participant_id == TournamentParticipant.id,
        )
        .where(
            TournamentParticipant.tournament_id == tournament_id,
            TournamentAttempt.tournament_id == tournament_id,
            TournamentAttempt.status == TournamentAttemptStatus.SUCCESS,
        )
        .order_by(
            TournamentParticipant.id.asc(),
            TournamentAttempt.errors_total.asc(),
            TournamentAttempt.time_spent_seconds.asc(),
            TournamentAttempt.submitted_at.asc(),
            TournamentAttempt.id.asc(),
        )
    )
    best_by_participant: dict[str, tuple[TournamentParticipant, TournamentAttempt]] = {}
    for participant, attempt in result.all():
        key = str(participant.id)
        if key not in best_by_participant:
            best_by_participant[key] = (participant, attempt)

    rows = list(best_by_participant.values())
    rows.sort(
        key=lambda item: (
            int(item[1].errors_total),
            int(item[1].time_spent_seconds),
            item[1].submitted_at or datetime.max.replace(tzinfo=timezone.utc),
            str(item[1].id),
        )
    )
    return rows


def build_tournament_leaderboard_entries(
    rows: list[tuple[TournamentParticipant, TournamentAttempt]],
) -> list[TournamentLeaderboardEntryResponse]:
    entries: list[TournamentLeaderboardEntryResponse] = []
    for index, (participant, attempt) in enumerate(rows, start=1):
        entries.append(
            TournamentLeaderboardEntryResponse(
                rank=index,
                participant_id=str(participant.id),
                display_name=participant.display_name,
                attempt_id=str(attempt.id),
                attempt_number=int(attempt.attempt_number),
                errors_total=int(attempt.errors_total),
                time_spent_seconds=int(attempt.time_spent_seconds),
                submitted_at=attempt.submitted_at,
            )
        )
    return entries


def build_tournament_leaderboard_response(
    tournament: Tournament,
    rows: list[tuple[TournamentParticipant, TournamentAttempt]],
) -> TournamentLeaderboardResponse:
    return TournamentLeaderboardResponse(
        tournament_id=str(tournament.id),
        status=tournament.status.value if hasattr(tournament.status, "value") else str(tournament.status),
        entries=build_tournament_leaderboard_entries(rows),
    )


@router.post("", response_model=TournamentResponse, status_code=status.HTTP_201_CREATED)
async def create_tournament(
    body: TournamentCreateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    code = await generate_unique_tournament_code(db)
    title = body.title or f"{DEFAULT_TOURNAMENT_TITLE_PREFIX} {code}"
    tournament_settings, max_rounds_mirror, attempt_duration_seconds_mirror = (
        normalize_tournament_settings_payload(body.tournament_settings)
    )

    tournament = Tournament(
        trainer_id=trainer.id,
        title=title,
        code=code,
        status=TournamentStatus.ACTIVE,
        max_rounds=max_rounds_mirror,
        attempt_duration_seconds=attempt_duration_seconds_mirror,
        tournament_settings=tournament_settings,
    )
    db.add(tournament)
    await db.commit()
    await db.refresh(tournament)
    return TournamentResponse.from_model(tournament)


@router.post("/activate", response_model=TournamentActivateResponse)
async def activate_tournament_participant(
    body: TournamentActivateRequest,
    db: AsyncSession = Depends(get_db),
):
    formatted_code = normalize_tournament_code_for_lookup(body.code)
    tournament_res = await db.execute(select(Tournament).where(Tournament.code == formatted_code))
    tournament = tournament_res.scalar_one_or_none()
    if not tournament:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")
    if tournament.status == TournamentStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tournament is closed",
        )

    display_name = clean_tournament_display_name(body.display_name)
    normalized_display_name = normalize_tournament_display_name(display_name)
    now = datetime.now(timezone.utc)

    participant_res = await db.execute(
        select(TournamentParticipant).where(
            TournamentParticipant.tournament_id == tournament.id,
            TournamentParticipant.normalized_display_name == normalized_display_name,
        )
    )
    participant = participant_res.scalar_one_or_none()
    if participant is None:
        participant = TournamentParticipant(
            tournament_id=tournament.id,
            display_name=display_name,
            normalized_display_name=normalized_display_name,
            last_seen_at=now,
        )
        db.add(participant)
        await db.flush()
    else:
        participant.last_seen_at = now

    old_tokens_res = await db.execute(
        select(TournamentParticipantToken).where(
            TournamentParticipantToken.tournament_participant_id == participant.id,
            TournamentParticipantToken.status == TournamentParticipantTokenStatus.ACTIVE,
        )
    )
    old_tokens = old_tokens_res.scalars().all()
    for item in old_tokens:
        item.status = TournamentParticipantTokenStatus.REVOKED
        item.revoked_at = now

    plain_token = generate_participant_token()
    token = TournamentParticipantToken(
        tournament_participant_id=participant.id,
        token_hash=hash_participant_token(plain_token),
        status=TournamentParticipantTokenStatus.ACTIVE,
        last_used_at=now,
    )
    db.add(token)
    await db.commit()
    await db.refresh(participant)

    return TournamentActivateResponse(
        participant_token=plain_token,
        tournament=TournamentActivationTournamentResponse.from_model(tournament),
        participant=TournamentParticipantResponse.from_model(participant),
    )


@router.post("/{tournament_id}/attempts", response_model=TournamentAttemptSubmitResponse)
async def submit_tournament_attempt(
    tournament_id: str,
    body: TournamentAttemptSubmitRequest,
    db: AsyncSession = Depends(get_db),
):
    tournament = await get_tournament_or_404(tournament_id, db)
    if tournament.status == TournamentStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Tournament is closed",
        )

    participant, _token_entry = await verify_tournament_participant_token(
        body.participant_token,
        tournament.id,
        db,
    )
    previous_best = await get_best_success_attempt_for_participant(participant.id, db)
    normalized_finish_reason = normalize_finish_reason(body.finish_reason)
    attempt_status = (
        TournamentAttemptStatus.SUCCESS
        if is_successful_tournament_attempt(
            tournament,
            body.rounds_completed,
            body.time_spent_seconds,
            normalized_finish_reason,
        )
        else TournamentAttemptStatus.FAILED
    )
    now = datetime.now(timezone.utc)

    created_attempt: TournamentAttempt | None = None
    for attempt_index in range(MAX_TOURNAMENT_ATTEMPT_RETRIES):
        next_attempt_number = await get_next_attempt_number(participant.id, db)
        created_attempt = TournamentAttempt(
            tournament_id=tournament.id,
            tournament_participant_id=participant.id,
            attempt_number=next_attempt_number,
            status=attempt_status,
            finish_reason=normalized_finish_reason if normalized_finish_reason != "" else None,
            rounds_completed=int(body.rounds_completed),
            errors_total=int(body.errors_total),
            time_spent_seconds=int(body.time_spent_seconds),
            submitted_at=now,
        )
        db.add(created_attempt)
        try:
            await db.commit()
            break
        except IntegrityError:
            await db.rollback()
            if attempt_index + 1 >= MAX_TOURNAMENT_ATTEMPT_RETRIES:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Could not allocate attempt number",
                )
            tournament = await get_tournament_or_404(tournament_id, db)
            if tournament.status == TournamentStatus.CLOSED:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail="Tournament is closed",
                )
            participant, _token_entry = await verify_tournament_participant_token(
                body.participant_token,
                tournament.id,
                db,
            )
            previous_best = await get_best_success_attempt_for_participant(participant.id, db)

    assert created_attempt is not None
    await db.refresh(created_attempt)

    improved = False
    if created_attempt.status == TournamentAttemptStatus.SUCCESS:
        improved = previous_best is None or is_attempt_better(created_attempt, previous_best)

    best_result = await get_best_success_attempt_for_participant(participant.id, db)
    rank: int | None = None
    if best_result is not None:
        leaderboard_rows = await get_tournament_leaderboard_rows(tournament.id, db)
        for index, (row_participant, row_attempt) in enumerate(leaderboard_rows, start=1):
            if row_participant.id == participant.id and row_attempt.id == best_result.id:
                rank = index
                break

    return TournamentAttemptSubmitResponse(
        attempt_id=str(created_attempt.id),
        attempt_number=int(created_attempt.attempt_number),
        status=created_attempt.status,
        finish_reason=created_attempt.finish_reason,
        rounds_completed=int(created_attempt.rounds_completed),
        errors_total=int(created_attempt.errors_total),
        time_spent_seconds=int(created_attempt.time_spent_seconds),
        submitted_at=created_attempt.submitted_at,
        improved=improved,
        best_result=TournamentBestResultResponse.from_model(best_result) if best_result else None,
        rank=rank,
    )


@router.get("/{tournament_id}/leaderboard", response_model=TournamentLeaderboardResponse)
async def get_tournament_leaderboard(
    tournament_id: str,
    db: AsyncSession = Depends(get_db),
):
    tournament = await get_tournament_or_404(tournament_id, db)
    rows = await get_tournament_leaderboard_rows(tournament.id, db)
    return build_tournament_leaderboard_response(tournament, rows)


@router.get("/public/{code}", response_model=TournamentPublicPageResponse)
async def get_tournament_public_page(
    code: str,
    db: AsyncSession = Depends(get_db),
):
    formatted_code = normalize_tournament_code_for_lookup(code)
    tournament_res = await db.execute(select(Tournament).where(Tournament.code == formatted_code))
    tournament = tournament_res.scalar_one_or_none()
    if not tournament:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Tournament not found")

    rows = await get_tournament_leaderboard_rows(tournament.id, db)
    return TournamentPublicPageResponse(
        tournament=TournamentActivationTournamentResponse.from_model(tournament),
        leaderboard=build_tournament_leaderboard_response(tournament, rows),
    )


@router.get("", response_model=list[TournamentResponse])
async def list_tournaments(
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Tournament)
        .where(Tournament.trainer_id == trainer.id)
        .order_by(Tournament.created_at.desc())
    )
    tournaments = result.scalars().all()
    return [TournamentResponse.from_model(item) for item in tournaments]


@router.get("/{tournament_id}", response_model=TournamentResponse)
async def get_tournament(
    tournament_id: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    tournament = await get_owned_tournament_or_404(tournament_id, trainer, db)
    return TournamentResponse.from_model(tournament)


@router.patch("/{tournament_id}", response_model=TournamentResponse)
async def update_tournament(
    tournament_id: str,
    body: TournamentUpdateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    tournament = await get_owned_tournament_or_404(tournament_id, trainer, db)
    settings_changed = False

    if body.title is not None:
        tournament.title = body.title

    if body.tournament_settings is not None:
        (
            tournament.tournament_settings,
            tournament.max_rounds,
            tournament.attempt_duration_seconds,
        ) = normalize_tournament_settings_payload(body.tournament_settings)
        settings_changed = True

    if body.title is not None or settings_changed:
        await db.commit()
        await db.refresh(tournament)

    return TournamentResponse.from_model(tournament)


@router.post("/{tournament_id}/close", response_model=TournamentResponse)
async def close_tournament(
    tournament_id: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    tournament = await get_owned_tournament_or_404(tournament_id, trainer, db)
    if tournament.status != TournamentStatus.CLOSED:
        tournament.status = TournamentStatus.CLOSED
        tournament.closed_at = datetime.now(timezone.utc)
        await db.commit()
        await db.refresh(tournament)
    return TournamentResponse.from_model(tournament)
