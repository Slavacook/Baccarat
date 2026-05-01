"""API роутер для комнат."""

import uuid
from datetime import datetime, timedelta, timezone
import secrets
import string
from typing import Any

import bcrypt
from fastapi import APIRouter, Body, Depends, HTTPException, Response, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_trainer, require_trainer
from app.models.participant_token import ParticipantToken, ParticipantTokenStatus
from app.models.room import Room, RoomStatus
from app.models.room_access import RoomAccess, RoomAccessStatus
from app.models.room_invite import RoomInvite, RoomInviteStatus
from app.models.room_pin import RoomPin
from app.models.dealer import Dealer
from app.models.trainer import Trainer
from app.schemas.room import (
    RoomAccessCreateRequest,
    RoomAccessCreateResponse,
    RoomAccessCreatedResponse,
    RoomAccessResponse,
    RoomAccessUpdateRequest,
    RoomParticipantResponse,
    RoomPersonalInviteResponse,
    RoomInviteCreatedResponse,
    RoomInviteLimitUpdateRequest,
    RoomInviteResponse,
    RoomCreateRequest,
    RoomCreateResponse,
    RoomResponse,
)
from app.schemas.auth import DealerJoinRequest, DealerJoinResponse, DealerInviteJoinRequest
from app.utils.access_codes import (
    generate_room_access_code,
    generate_room_invite_code,
    hash_room_access_code,
    hash_room_invite_code,
    room_access_code_suffix,
    room_invite_code_suffix,
)
from app.utils.auth import create_access_token, create_refresh_token

router = APIRouter(prefix="/rooms")

# ═══════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════

ALPHABET = "ABCDEFGHJKMNPQRTUVWXYZ23456789"  # 34 символа (без 0,1,I,L,O)


def generate_room_code() -> str:
    """Генерирует код комнаты в формате TRAIN-XXXX."""
    return "TRAIN-" + "".join(secrets.choice(ALPHABET) for _ in range(4))


def generate_pin() -> str:
    """Генерирует 6-значный PIN."""
    return "".join(secrets.choice(string.digits) for _ in range(6))


def generate_invite_token() -> str:
    """Генерирует secure invite token для ссылки приглашения."""
    return secrets.token_urlsafe(32)


def hash_pin(pin: str) -> str:
    """Хэширует PIN bcrypt-ом."""
    return bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")


def verify_pin(pin: str, pin_hash: str) -> bool:
    """Проверяет PIN."""
    return bcrypt.checkpw(pin.encode("utf-8"), pin_hash.encode("utf-8"))


async def get_owned_room_or_404(
    room_code: str,
    trainer: Trainer,
    db: AsyncSession,
) -> Room:
    """Return room only when it belongs to current trainer."""
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")
    return room


async def generate_unique_room_access_code(db: AsyncSession) -> tuple[str, str]:
    """Generate plaintext access code and deterministic hash unique in DB."""
    for _ in range(20):
        access_code = generate_room_access_code()
        access_code_hash = hash_room_access_code(access_code)
        exists_res = await db.execute(
            select(RoomAccess.id).where(RoomAccess.access_code_hash == access_code_hash)
        )
        if not exists_res.scalar_one_or_none():
            return access_code, access_code_hash

    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not generate unique access code",
    )


async def generate_unique_room_invite_code(db: AsyncSession) -> tuple[str, str]:
    """Generate plaintext shared invite code and unique lookup hash."""
    for _ in range(20):
        invite_code = generate_room_invite_code()
        invite_code_hash = hash_room_invite_code(invite_code)
        exists_res = await db.execute(
            select(RoomInvite.id).where(RoomInvite.invite_code_hash == invite_code_hash)
        )
        if not exists_res.scalar_one_or_none():
            return invite_code, invite_code_hash

    raise HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="Could not generate unique room invite code",
    )


def room_access_response(access: RoomAccess, dealer: Dealer | None = None) -> RoomAccessResponse:
    return RoomAccessResponse.from_model(access, dealer)


def created_room_access_response(access: RoomAccess, access_code: str) -> RoomAccessCreatedResponse:
    base = RoomAccessResponse.from_model(access)
    return RoomAccessCreatedResponse(**base.model_dump(), access_code=access_code)


def room_access_error(status_code: int, code: str, message: str) -> HTTPException:
    return HTTPException(status_code=status_code, detail={"code": code, "message": message})


def sync_room_invite_status(invite: RoomInvite, now: datetime) -> bool:
    """Mark active invite as expired when time is over."""
    if invite.status == RoomInviteStatus.ACTIVE and invite.expires_at <= now:
        invite.status = RoomInviteStatus.EXPIRED
        return True
    return False


def room_invite_response(invite: RoomInvite) -> RoomInviteResponse:
    return RoomInviteResponse.from_model(invite)


def created_room_invite_response(invite: RoomInvite, invite_code: str) -> RoomInviteCreatedResponse:
    base = RoomInviteResponse.from_model(invite)
    return RoomInviteCreatedResponse(**base.model_dump(), invite_code=invite_code)


def get_room_invite_participant_limit(room: Room) -> int | None:
    settings_data = room.settings if isinstance(room.settings, dict) else {}
    raw_value = settings_data.get("invite_participant_limit")
    if raw_value is None:
        return None
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        return None
    return value if value >= 1 else None


def set_room_invite_participant_limit(room: Room, participant_limit: int | None) -> None:
    settings_data = dict(room.settings) if isinstance(room.settings, dict) else {}
    if participant_limit is None:
        settings_data.pop("invite_participant_limit", None)
    else:
        settings_data["invite_participant_limit"] = int(participant_limit)
    room.settings = settings_data


async def count_active_room_participants(room_id: uuid.UUID, db: AsyncSession) -> int:
    result = await db.execute(
        select(func.count())
        .select_from(Dealer)
        .where(
            Dealer.room_id == room_id,
            Dealer.is_active.is_(True),
        )
    )
    return int(result.scalar() or 0)


def room_invite_metadata_response(
    invite: RoomInvite | None,
    participant_limit: int | None,
    active_participants_count: int,
) -> RoomInviteResponse:
    if invite is None:
        return RoomInviteResponse.empty(
            active_participants_count=active_participants_count,
            participant_limit=participant_limit,
        )
    return RoomInviteResponse.from_model(
        invite,
        active_participants_count=active_participants_count,
        participant_limit=participant_limit,
    )


def created_room_invite_metadata_response(
    invite: RoomInvite,
    invite_code: str,
    participant_limit: int | None,
    active_participants_count: int,
) -> RoomInviteCreatedResponse:
    base = RoomInviteResponse.from_model(
        invite,
        active_participants_count=active_participants_count,
        participant_limit=participant_limit,
    )
    return RoomInviteCreatedResponse(**base.model_dump(), invite_code=invite_code)


async def get_room_access_or_404(
    access_id: uuid.UUID,
    room_id: uuid.UUID,
    db: AsyncSession,
) -> RoomAccess:
    access_res = await db.execute(
        select(RoomAccess).where(RoomAccess.id == access_id, RoomAccess.room_id == room_id)
    )
    access = access_res.scalar_one_or_none()
    if not access:
        raise room_access_error(
            status.HTTP_404_NOT_FOUND,
            "ACCESS_NOT_FOUND",
            "Room access not found",
        )
    return access


async def revoke_active_participant_tokens(
    room_access_id: uuid.UUID,
    now: datetime,
    db: AsyncSession,
) -> None:
    tokens_res = await db.execute(
        select(ParticipantToken).where(
            ParticipantToken.room_access_id == room_access_id,
            ParticipantToken.status == ParticipantTokenStatus.ACTIVE,
        )
    )
    for token in tokens_res.scalars().all():
        token.status = ParticipantTokenStatus.REVOKED
        token.revoked_at = now


async def revoke_all_participant_tokens(
    room_access_id: uuid.UUID,
    now: datetime,
    db: AsyncSession,
) -> None:
    tokens_res = await db.execute(
        select(ParticipantToken).where(ParticipantToken.room_access_id == room_access_id)
    )
    for token in tokens_res.scalars().all():
        token.status = ParticipantTokenStatus.REVOKED
        token.revoked_at = now


async def deactivate_access_dealer(
    access: RoomAccess,
    room: Room,
    now: datetime,
    db: AsyncSession,
) -> Dealer | None:
    if not access.dealer_id:
        return None

    dealer_res = await db.execute(select(Dealer).where(Dealer.id == access.dealer_id))
    dealer = dealer_res.scalar_one_or_none()
    if not dealer:
        return None

    if dealer.is_active:
        dealer.is_active = False
        dealer.last_seen_at = now
        active_dealers_count = int(room.total_dealers or 0)
        if active_dealers_count > 0:
            room.total_dealers = active_dealers_count - 1

    return dealer


# ═══════════════════════════════════════════════════════════════
# ЭНДПОИНТЫ
# ═══════════════════════════════════════════════════════════════

@router.post("/", response_model=RoomCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_room(
    body: RoomCreateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Создать комнату. Возвращает код комнаты и PIN-ы (только один раз!)."""
    # Генерируем уникальный код
    while True:
        room_code = generate_room_code()
        result = await db.execute(select(Room).where(Room.room_code == room_code))
        if not result.scalar_one_or_none():
            break  # Уникальный код найден

    # Создаём комнату
    room = Room(
        trainer_id=trainer.id,  # Берём из JWT токена
        room_code=room_code,
        name=body.name,
        settings=body.settings.model_dump() if body.settings else {},
        max_dealers=body.max_dealers,
    )
    db.add(room)
    await db.flush()

    # Генерируем PIN-ы
    pins = []
    for slot in range(1, body.max_dealers + 1):
        pin = generate_pin()
        pin_entry = RoomPin(
            room_id=room.id,
            pin_hash=hash_pin(pin),
            dealer_slot=slot,
            invite_token=generate_invite_token(),
            invite_status="unused",
        )
        db.add(pin_entry)
        pins.append({"pin": pin, "dealer_slot": slot})

    await db.commit()
    await db.refresh(room)

    return RoomCreateResponse(
        room=RoomResponse.from_model(room),
        pins=pins,
    )


@router.get("/", response_model=list[RoomResponse])
async def list_rooms(
    trainer: Trainer = Depends(get_current_trainer),
    status_filter: str | None = None,
    db: AsyncSession = Depends(get_db),
):
    """Список комнат тренера."""
    query = select(Room).where(Room.trainer_id == trainer.id)
    if status_filter:
        query = query.where(Room.status == status_filter)

    query = query.order_by(Room.created_at.desc())
    result = await db.execute(query)
    rooms = result.scalars().all()

    return [RoomResponse.from_model(room) for room in rooms]


@router.get("/{room_code}/dealers")
async def list_room_dealers(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Список дилеров комнаты (для тренера), даже если live-сессия ещё не запущена."""
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    dealers_res = await db.execute(
        select(Dealer)
        .where(Dealer.room_id == room.id, Dealer.is_active == True)
        .order_by(Dealer.display_name)
    )
    dealers = dealers_res.scalars().all()
    return [
        {
            "dealer_id": str(d.id),
            "display_name": d.display_name,
            "last_seen_at": d.last_seen_at,
        }
        for d in dealers
    ]


@router.get("/{room_code}/pins")
async def list_room_pins(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    pins_res = await db.execute(
        select(RoomPin, Dealer)
        .outerjoin(Dealer, Dealer.id == RoomPin.dealer_id)
        .where(RoomPin.room_id == room.id, RoomPin.is_active == True)
        .order_by(RoomPin.dealer_slot.asc())
    )
    rows = pins_res.all()
    return [
        {
            "pin_id": str(pin.id),
            "dealer_slot": pin.dealer_slot,
            "dealer_id": str(pin.dealer_id) if pin.dealer_id else None,
            "display_name": dealer.display_name if dealer else None,
        }
        for pin, dealer in rows
    ]


@router.post("/{room_code}/pins")
async def add_room_pin_slot(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    slot_res = await db.execute(
        select(func.coalesce(func.max(RoomPin.dealer_slot), 0)).where(
            RoomPin.room_id == room.id,
            RoomPin.is_active == True,
        )
    )
    next_slot = int(slot_res.scalar() or 0) + 1
    pin = generate_pin()
    pin_entry = RoomPin(
        room_id=room.id,
        pin_hash=hash_pin(pin),
        dealer_slot=next_slot,
        is_active=True,
        invite_token=generate_invite_token(),
        invite_status="unused",
    )
    db.add(pin_entry)
    room.max_dealers = max(int(room.max_dealers or 0), next_slot)
    await db.commit()
    await db.refresh(pin_entry)
    return {"pin": pin, "dealer_slot": next_slot}


@router.post("/{room_code}/pins/{dealer_slot}/reset")
async def reset_room_pin_slot(
    room_code: str,
    dealer_slot: int,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    pin_res = await db.execute(
        select(RoomPin).where(
            RoomPin.room_id == room.id,
            RoomPin.dealer_slot == dealer_slot,
            RoomPin.is_active == True,
        )
    )
    pin_entry = pin_res.scalar_one_or_none()
    if not pin_entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PIN slot not found")

    if pin_entry.dealer_id:
        dealer_res = await db.execute(select(Dealer).where(Dealer.id == pin_entry.dealer_id))
        dealer = dealer_res.scalar_one_or_none()
        if dealer:
            dealer.is_active = False
            dealer.last_seen_at = datetime.now(timezone.utc)
            if room.total_dealers > 0:
                room.total_dealers -= 1

    new_pin = generate_pin()
    pin_entry.pin_hash = hash_pin(new_pin)
    pin_entry.dealer_id = None
    await db.commit()
    return {"pin": new_pin, "dealer_slot": dealer_slot}


@router.delete("/{room_code}/pins/{dealer_slot}")
async def delete_room_pin_slot(
    room_code: str,
    dealer_slot: int,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    room_res = await db.execute(select(Room).where(Room.room_code == room_code))
    room = room_res.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    pin_res = await db.execute(
        select(RoomPin).where(
            RoomPin.room_id == room.id,
            RoomPin.dealer_slot == dealer_slot,
            RoomPin.is_active == True,
        )
    )
    pin_entry = pin_res.scalar_one_or_none()
    if not pin_entry:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="PIN slot not found")

    if pin_entry.dealer_id:
        dealer_res = await db.execute(select(Dealer).where(Dealer.id == pin_entry.dealer_id))
        dealer = dealer_res.scalar_one_or_none()
        if dealer:
            dealer.is_active = False
            dealer.last_seen_at = datetime.now(timezone.utc)
            if room.total_dealers > 0:
                room.total_dealers -= 1

    pin_entry.is_active = False
    await db.commit()
    return {"deleted": True, "dealer_slot": dealer_slot}


@router.get("/{room_code}/accesses", response_model=list[RoomAccessResponse])
async def list_room_accesses(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """List personal room access slots for the room owner."""
    room = await get_owned_room_or_404(room_code, trainer, db)

    accesses_res = await db.execute(
        select(RoomAccess, Dealer)
        .outerjoin(Dealer, Dealer.id == RoomAccess.dealer_id)
        .where(RoomAccess.room_id == room.id)
        .order_by(RoomAccess.slot_number.asc())
    )
    return [
        room_access_response(access, dealer)
        for access, dealer in accesses_res.all()
    ]


@router.get("/{room_code}/participants", response_model=list[RoomParticipantResponse])
async def list_room_participants(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """List real room participants based on Dealer records."""
    room = await get_owned_room_or_404(room_code, trainer, db)

    dealers_res = await db.execute(
        select(Dealer)
        .where(
            Dealer.room_id == room.id,
            Dealer.is_active.is_(True),
        )
        .order_by(Dealer.created_at.asc(), Dealer.display_name.asc())
    )
    return [
        RoomParticipantResponse.from_model(dealer, online_status="unknown")
        for dealer in dealers_res.scalars().all()
    ]


@router.get("/{room_code}/personal-invites", response_model=list[RoomPersonalInviteResponse])
async def list_room_personal_invites(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """List pending personal invites that are not activated yet."""
    room = await get_owned_room_or_404(room_code, trainer, db)

    invites_res = await db.execute(
        select(RoomAccess)
        .where(
            RoomAccess.room_id == room.id,
            RoomAccess.status == RoomAccessStatus.CREATED,
            RoomAccess.dealer_id.is_(None),
        )
        .order_by(RoomAccess.slot_number.asc(), RoomAccess.created_at.asc())
    )
    return [
        RoomPersonalInviteResponse.from_model(access)
        for access in invites_res.scalars().all()
    ]


@router.delete(
    "/{room_code}/participants/{dealer_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
async def delete_room_participant(
    room_code: str,
    dealer_id: uuid.UUID,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Soft-delete a room participant and revoke all room-scoped participant tokens."""
    room = await get_owned_room_or_404(room_code, trainer, db)

    dealer_res = await db.execute(
        select(Dealer).where(
            Dealer.id == dealer_id,
            Dealer.room_id == room.id,
        )
    )
    dealer = dealer_res.scalar_one_or_none()
    if not dealer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "PARTICIPANT_NOT_FOUND", "message": "Room participant not found"},
        )

    now = datetime.now(timezone.utc)
    if dealer.is_active:
        dealer.is_active = False
        dealer.last_seen_at = now
        active_dealers_count = int(room.total_dealers or 0)
        if active_dealers_count > 0:
            room.total_dealers = active_dealers_count - 1

    tokens_res = await db.execute(
        select(ParticipantToken).where(ParticipantToken.dealer_id == dealer.id)
    )
    tokens = tokens_res.scalars().all()

    access_ids: set[uuid.UUID] = set()
    invite_ids: set[uuid.UUID] = set()
    for token in tokens:
        if token.room_access_id:
            access_ids.add(token.room_access_id)
        if token.room_invite_id:
            invite_ids.add(token.room_invite_id)

    room_access_ids: set[uuid.UUID] = set()
    if access_ids:
        access_rows_res = await db.execute(
            select(RoomAccess.id).where(
                RoomAccess.id.in_(access_ids),
                RoomAccess.room_id == room.id,
            )
        )
        room_access_ids = set(access_rows_res.scalars().all())

    room_invite_ids: set[uuid.UUID] = set()
    if invite_ids:
        invite_rows_res = await db.execute(
            select(RoomInvite.id).where(
                RoomInvite.id.in_(invite_ids),
                RoomInvite.room_id == room.id,
            )
        )
        room_invite_ids = set(invite_rows_res.scalars().all())

    for token in tokens:
        is_room_access_token = bool(token.room_access_id and token.room_access_id in room_access_ids)
        is_room_invite_token = bool(token.room_invite_id and token.room_invite_id in room_invite_ids)
        if not is_room_access_token and not is_room_invite_token:
            continue
        token.status = ParticipantTokenStatus.REVOKED
        token.revoked_at = now

    access_res = await db.execute(
        select(RoomAccess).where(
            RoomAccess.room_id == room.id,
            RoomAccess.dealer_id == dealer.id,
        )
    )
    for access in access_res.scalars().all():
        access.status = RoomAccessStatus.REVOKED
        access.revoked_at = access.revoked_at or now

    await db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{room_code}/invite",
    response_model=RoomInviteCreatedResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_room_invite(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Create or replace the shared invite code for a room."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    if room.status == RoomStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "ROOM_CLOSED", "message": "Cannot create invite for closed room"},
        )

    now = datetime.now(timezone.utc)
    existing_res = await db.execute(
        select(RoomInvite)
        .where(RoomInvite.room_id == room.id, RoomInvite.status == RoomInviteStatus.ACTIVE)
        .with_for_update()
    )
    for invite in existing_res.scalars().all():
        if sync_room_invite_status(invite, now):
            continue
        invite.status = RoomInviteStatus.REVOKED
        invite.revoked_at = now

    invite_code, invite_code_hash = await generate_unique_room_invite_code(db)
    invite = RoomInvite(
        room_id=room.id,
        invite_code_hash=invite_code_hash,
        invite_code_suffix=room_invite_code_suffix(invite_code),
        status=RoomInviteStatus.ACTIVE,
        expires_at=now + timedelta(hours=1),
    )
    db.add(invite)

    await db.commit()
    await db.refresh(invite)

    active_participants_count = await count_active_room_participants(room.id, db)
    participant_limit = get_room_invite_participant_limit(room)
    return created_room_invite_metadata_response(
        invite,
        invite_code,
        participant_limit,
        active_participants_count,
    )


@router.get("/{room_code}/invite", response_model=RoomInviteResponse)
async def get_room_invite(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Return current shared room invite metadata without plaintext code."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    now = datetime.now(timezone.utc)
    participant_limit = get_room_invite_participant_limit(room)
    active_participants_count = await count_active_room_participants(room.id, db)

    invite_res = await db.execute(
        select(RoomInvite)
        .where(RoomInvite.room_id == room.id)
        .order_by(RoomInvite.created_at.desc())
    )
    invites = invite_res.scalars().all()
    changed = False
    for invite in invites:
        changed = sync_room_invite_status(invite, now) or changed
        if invite.status == RoomInviteStatus.ACTIVE:
            if changed:
                await db.commit()
                await db.refresh(invite)
            return room_invite_metadata_response(
                invite,
                participant_limit,
                active_participants_count,
            )

    if changed:
        await db.commit()
    return room_invite_metadata_response(
        None,
        participant_limit,
        active_participants_count,
    )


@router.patch("/{room_code}/invite-limit", response_model=RoomInviteResponse)
async def update_room_invite_limit(
    room_code: str,
    body: RoomInviteLimitUpdateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Update shared invite participant limit stored in room settings."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    set_room_invite_participant_limit(room, body.participant_limit)
    await db.commit()
    await db.refresh(room)

    now = datetime.now(timezone.utc)
    participant_limit = get_room_invite_participant_limit(room)
    active_participants_count = await count_active_room_participants(room.id, db)

    invite_res = await db.execute(
        select(RoomInvite)
        .where(RoomInvite.room_id == room.id)
        .order_by(RoomInvite.created_at.desc())
    )
    invites = invite_res.scalars().all()
    changed = False
    active_invite: RoomInvite | None = None
    for invite in invites:
        changed = sync_room_invite_status(invite, now) or changed
        if invite.status == RoomInviteStatus.ACTIVE:
            active_invite = invite
            break

    if changed:
        await db.commit()
        if active_invite:
            await db.refresh(active_invite)

    return room_invite_metadata_response(
        active_invite,
        participant_limit,
        active_participants_count,
    )


@router.post(
    "/{room_code}/accesses",
    response_model=RoomAccessCreateResponse,
    status_code=status.HTTP_201_CREATED,
)
async def create_room_accesses(
    room_code: str,
    body: RoomAccessCreateRequest = Body(default_factory=RoomAccessCreateRequest),
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Create new personal access slots without touching legacy PIN slots."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    if room.status == RoomStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={"code": "ROOM_CLOSED", "message": "Cannot create access slots for closed room"},
        )

    slots_res = await db.execute(
        select(RoomAccess.slot_number).where(RoomAccess.room_id == room.id)
    )
    used_slots = set(slots_res.scalars().all())
    max_dealers = int(room.max_dealers or 0)
    available_slots = [
        slot_number
        for slot_number in range(1, max_dealers + 1)
        if slot_number not in used_slots
    ]

    if not available_slots:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "ROOM_ACCESS_LIMIT_REACHED",
                "message": "Room already has access slots for all dealer seats",
            },
        )

    if body.count > len(available_slots):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "code": "ROOM_ACCESS_LIMIT_EXCEEDED",
                "message": f"Only {len(available_slots)} access slots are available",
            },
        )

    created: list[tuple[RoomAccess, str]] = []
    for slot_number in available_slots[: body.count]:
        access_code, access_code_hash = await generate_unique_room_access_code(db)
        access = RoomAccess(
            room_id=room.id,
            slot_number=slot_number,
            access_code_hash=access_code_hash,
            access_code_suffix=room_access_code_suffix(access_code),
            status=RoomAccessStatus.CREATED,
        )
        db.add(access)
        created.append((access, access_code))

    await db.commit()
    for access, _ in created:
        await db.refresh(access)

    return RoomAccessCreateResponse(
        accesses=[
            created_room_access_response(access, access_code)
            for access, access_code in created
        ]
    )


@router.patch("/{room_code}/accesses/{access_id}", response_model=RoomAccessResponse)
async def update_room_access(
    room_code: str,
    access_id: uuid.UUID,
    body: RoomAccessUpdateRequest,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Update trainer-only metadata for an access slot."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    access_res = await db.execute(
        select(RoomAccess, Dealer)
        .outerjoin(Dealer, Dealer.id == RoomAccess.dealer_id)
        .where(RoomAccess.id == access_id, RoomAccess.room_id == room.id)
    )
    row = access_res.one_or_none()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room access not found")

    access, dealer = row
    access.trainer_internal_name = body.trainer_internal_name
    await db.commit()
    await db.refresh(access)

    return room_access_response(access, dealer)


@router.post("/{room_code}/accesses/{access_id}/revoke", response_model=RoomAccessResponse)
async def revoke_room_access(
    room_code: str,
    access_id: uuid.UUID,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Revoke a personal room access slot and its active participant tokens."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    access = await get_room_access_or_404(access_id, room.id, db)
    now = datetime.now(timezone.utc)

    dealer = await deactivate_access_dealer(access, room, now, db)
    await revoke_active_participant_tokens(access.id, now, db)

    access.status = RoomAccessStatus.REVOKED
    access.revoked_at = access.revoked_at or now
    access.last_used_at = now

    await db.commit()
    await db.refresh(access)
    if dealer:
        await db.refresh(dealer)

    return room_access_response(access, dealer)


@router.post("/{room_code}/accesses/{access_id}/reset", response_model=RoomAccessCreatedResponse)
async def reset_room_access(
    room_code: str,
    access_id: uuid.UUID,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Regenerate a personal access code for the same slot."""
    room = await get_owned_room_or_404(room_code, trainer, db)
    access = await get_room_access_or_404(access_id, room.id, db)
    now = datetime.now(timezone.utc)

    await deactivate_access_dealer(access, room, now, db)
    await revoke_all_participant_tokens(access.id, now, db)

    access_code, access_code_hash = await generate_unique_room_access_code(db)
    access.access_code_hash = access_code_hash
    access.access_code_suffix = room_access_code_suffix(access_code)
    access.status = RoomAccessStatus.CREATED
    access.dealer_id = None
    access.activated_at = None
    access.revoked_at = None
    access.last_used_at = None

    await db.commit()
    await db.refresh(access)

    return created_room_access_response(access, access_code)


@router.get("/{room_code}", response_model=RoomResponse)
async def get_room(room_code: str, db: AsyncSession = Depends(get_db)):
    """Получить детали комнаты."""
    result = await db.execute(select(Room).where(Room.room_code == room_code))
    room = result.scalar_one_or_none()

    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")

    return RoomResponse.from_model(room)


@router.delete("/{room_code}")
async def delete_room(
    room_code: str,
    trainer: Trainer = Depends(get_current_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Мягкое удаление комнаты тренера (скрываем из интерфейса)."""
    result = await db.execute(select(Room).where(Room.room_code == room_code))
    room = result.scalar_one_or_none()
    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")
    if room.trainer_id != trainer.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not room owner")

    room.status = RoomStatus.CLOSED
    pins_res = await db.execute(select(RoomPin).where(RoomPin.room_id == room.id))
    for pin in pins_res.scalars().all():
        pin.is_active = False
    dealers_res = await db.execute(select(Dealer).where(Dealer.room_id == room.id))
    for dealer in dealers_res.scalars().all():
        dealer.is_active = False
    await db.commit()
    return {"deleted": True, "room_code": room_code}


@router.post("/dealer/join", response_model=DealerJoinResponse, status_code=status.HTTP_200_OK)
async def dealer_join_room(
    body: DealerJoinRequest,
    db: AsyncSession = Depends(get_db),
):
    """Вход дилера в комнату по коду + PIN."""
    # 1. Найти комнату
    result = await db.execute(select(Room).where(Room.room_code == body.room_code))
    room = result.scalar_one_or_none()

    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "ROOM_NOT_FOUND", "message": "Комната с таким кодом не найдена"},
        )

    if room.status == RoomStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"code": "ROOM_CLOSED", "message": "Эта комната закрыта"},
        )

    # 2. Найти PIN
    result = await db.execute(select(RoomPin).where(RoomPin.room_id == room.id, RoomPin.is_active == True))
    pins = result.scalars().all()

    matched_pin = None
    for pin_entry in pins:
        if verify_pin(body.pin, pin_entry.pin_hash):
            matched_pin = pin_entry
            break

    if not matched_pin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "INVALID_PIN", "message": "Неверный PIN-код"},
        )

    # 3. Создать или найти дилера
    is_first_login = False

    if matched_pin.dealer_id:
        # PIN уже использован — проверяем имя
        result = await db.execute(select(Dealer).where(Dealer.id == matched_pin.dealer_id))
        dealer = result.scalar_one_or_none()

        if not dealer or not dealer.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "DEALER_INACTIVE", "message": "Дилер неактивен"},
            )

        if dealer.display_name != body.display_name:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={
                    "code": "NAME_MISMATCH",
                    "message": f"Этот PIN привязан к имени '{dealer.display_name}'. Введите то же имя.",
                },
            )
    else:
        # Новый дилер
        is_first_login = True
        dealer = Dealer(
            room_id=room.id,
            display_name=body.display_name,
        )
        db.add(dealer)
        await db.flush()

        # Привязать PIN к дилеру
        matched_pin.dealer_id = dealer.id
        room.total_dealers += 1

    # Обновить last_seen_at
    from datetime import datetime, timezone
    dealer.last_seen_at = datetime.now(timezone.utc)

    await db.commit()
    await db.refresh(dealer)

    # 4. Создать токены
    access_token = create_access_token(str(dealer.id), "dealer", str(room.id))
    refresh_token = create_refresh_token(str(dealer.id), "dealer", str(dealer.id))

    return DealerJoinResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        user={
            "id": str(dealer.id),
            "display_name": dealer.display_name,
            "room_id": str(room.id),
            "room_code": room.room_code,
            "role": "dealer",
            "is_first_login": is_first_login,
        },
    )


@router.post("/dealer/join-invite", response_model=DealerJoinResponse, status_code=status.HTTP_200_OK)
async def dealer_join_room_invite(
    body: DealerInviteJoinRequest,
    db: AsyncSession = Depends(get_db),
):
    """Вход дилера в комнату по invite token."""
    # 1. Найти RoomPin по invite_token
    result = await db.execute(
        select(RoomPin).where(
            RoomPin.invite_token == body.invite_token,
            RoomPin.is_active == True,
        )
    )
    matched_pin = result.scalar_one_or_none()
    
    if not matched_pin or not matched_pin.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "INVITE_INVALID", "message": "Неверный или просроченный токен приглашения"},
        )
        
    if matched_pin.invite_status == "revoked":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail={"code": "INVITE_REVOKED", "message": "Токен приглашения был отозван"},
        )

    # 2. Найти Room
    result = await db.execute(select(Room).where(Room.id == matched_pin.room_id))
    room = result.scalar_one_or_none()
    
    if not room:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"code": "ROOM_NOT_FOUND", "message": "Комната не найдена"},
        )
        
    if room.status == RoomStatus.CLOSED:
        raise HTTPException(
            status_code=status.HTTP_410_GONE,
            detail={"code": "ROOM_CLOSED", "message": "Эта комната закрыта"},
        )

    # 3. Обработать дилера
    is_first_login = False
    
    if matched_pin.dealer_id:
        # Дилер уже существует
        result = await db.execute(select(Dealer).where(Dealer.id == matched_pin.dealer_id))
        dealer = result.scalar_one_or_none()
        
        if not dealer or not dealer.is_active:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"code": "DEALER_INACTIVE", "message": "Дилер неактивен"},
            )
            
        # Проверка устройства
        if dealer.device_id is None:
            dealer.device_id = body.device_id
            dealer.device_claimed_at = datetime.now(timezone.utc)
            matched_pin.device_reset_at = None
        elif dealer.device_id != body.device_id:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail={"code": "DEVICE_MISMATCH", "message": "Устройство не соответствует"},
            )
    else:
        # Новый дилер
        is_first_login = True
        dealer = Dealer(
            room_id=room.id,
            display_name=body.display_name,
            device_id=body.device_id,
            device_claimed_at=datetime.now(timezone.utc),
        )
        db.add(dealer)
        await db.flush()
        
        # Привязать PIN к дилеру
        matched_pin.dealer_id = dealer.id
        matched_pin.invite_status = "claimed"
        matched_pin.claimed_at = datetime.now(timezone.utc)
        room.total_dealers += 1

    # Обновить last_seen_at
    dealer.last_seen_at = datetime.now(timezone.utc)
    
    await db.commit()
    await db.refresh(dealer)
    
    # 4. Создать токены
    access_token = create_access_token(str(dealer.id), "dealer", str(room.id))
    refresh_token = create_refresh_token(str(dealer.id), "dealer", str(dealer.id))

    return DealerJoinResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        user={
            "id": str(dealer.id),
            "display_name": dealer.display_name,
            "room_id": str(room.id),
            "room_code": room.room_code,
            "role": "dealer",
            "is_first_login": is_first_login,
        },
    )
