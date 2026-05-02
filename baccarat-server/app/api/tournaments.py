"""Trainer API for tournament foundation."""

from datetime import datetime, timezone
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_trainer
from app.models.tournament import Tournament, TournamentStatus
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
    TournamentCreateRequest,
    TournamentParticipantResponse,
    TournamentResponse,
)
from app.utils.access_codes import (
    generate_participant_token,
    generate_tournament_code,
    hash_participant_token,
)
from app.utils.tournament_participants import normalize_tournament_display_name

router = APIRouter(prefix="/tournaments")

DEFAULT_TOURNAMENT_MAX_ROUNDS = 50
DEFAULT_TOURNAMENT_ATTEMPT_DURATION_SECONDS = 600
DEFAULT_TOURNAMENT_TITLE_PREFIX = "Турнир"


def normalize_tournament_code_for_lookup(code: str) -> str:
    compact = "".join(char for char in code.upper() if char.isalnum())
    if len(compact) != 8:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Tournament code must contain 8 characters",
        )
    return f"{compact[:4]}-{compact[4:]}"


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


@router.post("", response_model=TournamentResponse, status_code=status.HTTP_201_CREATED)
async def create_tournament(
    body: TournamentCreateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    code = await generate_unique_tournament_code(db)
    title = body.title or f"{DEFAULT_TOURNAMENT_TITLE_PREFIX} {code}"

    tournament = Tournament(
        trainer_id=trainer.id,
        title=title,
        code=code,
        status=TournamentStatus.ACTIVE,
        max_rounds=DEFAULT_TOURNAMENT_MAX_ROUNDS,
        attempt_duration_seconds=DEFAULT_TOURNAMENT_ATTEMPT_DURATION_SECONDS,
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

    normalized_display_name = normalize_tournament_display_name(body.display_name)
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
            display_name=body.display_name.strip(),
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
