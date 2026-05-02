"""Trainer API for tournament foundation."""

from datetime import datetime, timezone
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_trainer
from app.models.tournament import Tournament, TournamentStatus
from app.models.trainer import Trainer
from app.schemas.tournament import TournamentCreateRequest, TournamentResponse
from app.utils.access_codes import generate_tournament_code

router = APIRouter(prefix="/tournaments")

DEFAULT_TOURNAMENT_MAX_ROUNDS = 50
DEFAULT_TOURNAMENT_ATTEMPT_DURATION_SECONDS = 600
DEFAULT_TOURNAMENT_TITLE_PREFIX = "Турнир"


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
