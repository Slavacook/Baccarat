"""API роутер для комнат."""

import secrets
import string
from typing import Any

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.database import get_db
from app.dependencies import get_current_trainer, require_trainer
from app.models.room import Room, RoomStatus
from app.models.room_pin import RoomPin
from app.models.dealer import Dealer
from app.models.trainer import Trainer
from app.schemas.room import (
    RoomCreateRequest,
    RoomCreateResponse,
    RoomResponse,
)
from app.schemas.auth import DealerJoinRequest, DealerJoinResponse
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


def hash_pin(pin: str) -> str:
    """Хэширует PIN bcrypt-ом."""
    return bcrypt.hashpw(pin.encode("utf-8"), bcrypt.gensalt(10)).decode("utf-8")


def verify_pin(pin: str, pin_hash: str) -> bool:
    """Проверяет PIN."""
    return bcrypt.checkpw(pin.encode("utf-8"), pin_hash.encode("utf-8"))


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


@router.get("/{room_code}", response_model=RoomResponse)
async def get_room(room_code: str, db: AsyncSession = Depends(get_db)):
    """Получить детали комнаты."""
    result = await db.execute(select(Room).where(Room.room_code == room_code))
    room = result.scalar_one_or_none()

    if not room:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Room not found")

    return RoomResponse.from_model(room)


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
