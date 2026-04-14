"""API роутер для авторизации тренера и дилера."""

import bcrypt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.dependencies import get_current_user, require_trainer
from app.models.trainer import Trainer
from app.schemas.auth import (
    DealerJoinRequest,
    DealerJoinResponse,
    RefreshTokenRequest,
    TokenResponse,
    TrainerLoginRequest,
    TrainerRegisterRequest,
    TrainerRegisterResponse,
    WhoamiResponse,
)
from app.utils.auth import create_access_token, create_refresh_token, decode_token

router = APIRouter()


# ═══════════════════════════════════════════════════════════════
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ═══════════════════════════════════════════════════════════════

def hash_password(password: str) -> str:
    """Хэшировать пароль bcrypt-ом."""
    return bcrypt.hashpw(password.encode("utf-8"), bcrypt.gensalt(12)).decode("utf-8")


def verify_password(password: str, password_hash: str) -> bool:
    """Проверить пароль."""
    return bcrypt.checkpw(password.encode("utf-8"), password_hash.encode("utf-8"))


# ═══════════════════════════════════════════════════════════════
# ЭНДПОИНТЫ
# ═══════════════════════════════════════════════════════════════

@router.post("/trainer/register", response_model=TrainerRegisterResponse, status_code=status.HTTP_201_CREATED)
async def trainer_register(body: TrainerRegisterRequest, db: AsyncSession = Depends(get_db)):
    """Регистрация нового тренера."""
    # Проверить, что email не занят
    result = await db.execute(select(Trainer).where(Trainer.email == body.email))
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Email already registered",
        )

    # Создать тренера
    trainer = Trainer(
        email=body.email,
        password_hash=hash_password(body.password),
        full_name=body.full_name,
    )
    db.add(trainer)
    await db.flush()

    # Создать токены
    access_token = create_access_token(str(trainer.id), "trainer")
    refresh_token = create_refresh_token(str(trainer.id), "trainer", str(trainer.id))

    return TrainerRegisterResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        user={"id": str(trainer.id), "email": trainer.email, "full_name": trainer.full_name, "role": "trainer"},
    )


@router.post("/trainer/login", response_model=TokenResponse)
async def trainer_login(body: TrainerLoginRequest, db: AsyncSession = Depends(get_db)):
    """Вход тренера."""
    result = await db.execute(select(Trainer).where(Trainer.email == body.email))
    trainer = result.scalar_one_or_none()

    if not trainer or not verify_password(body.password, trainer.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )

    if not trainer.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deactivated",
        )

    access_token = create_access_token(str(trainer.id), "trainer")
    refresh_token = create_refresh_token(str(trainer.id), "trainer", str(trainer.id))

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        user={"id": str(trainer.id), "email": trainer.email, "full_name": trainer.full_name, "role": "trainer"},
    )


@router.post("/dealer/join", response_model=DealerJoinResponse, status_code=status.HTTP_200_OK)
async def dealer_join(body: DealerJoinRequest, db: AsyncSession = Depends(get_db)):
    """Вход дилера в комнату по коду + PIN."""
    # TODO: Реализовать в следующем шаге
    # 1. Найти комнату по room_code
    # 2. Проверить PIN
    # 3. Создать/найти dealer
    # 4. Вернуть токены
    raise HTTPException(
        status_code=status.HTTP_501_NOT_IMPLEMENTED,
        detail="Not implemented yet — следующий шаг реализации",
    )


# ═══════════════════════════════════════════════════════════════
# REFRESH / LOGOUT / WHOAMI
# ═══════════════════════════════════════════════════════════════

@router.post("/trainer/refresh", response_model=TokenResponse)
async def trainer_refresh(body: RefreshTokenRequest):
    """Обновить access token по refresh token."""
    try:
        payload = decode_token(body.refresh_token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type (expected: refresh)",
        )

    if payload.get("role") != "trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Требуется роль тренера",
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    # Создать новую пару токенов
    access_token = create_access_token(user_id, "trainer")
    refresh_token = create_refresh_token(user_id, "trainer", user_id)

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        token_type="Bearer",
        user={"id": user_id, "role": "trainer"},
    )


@router.post("/trainer/logout", status_code=status.HTTP_204_NO_CONTENT)
async def trainer_logout(current_user: dict = Depends(require_trainer)):
    """Выход тренера (на клиенте удаляем токены).

    В stateless JWT logout — это просто удаление токенов на клиенте.
    Если нужна инвалидация на сервере — добавить blacklist в Redis/БД.
    """
    # В текущей реализации достаточно удалить токены на клиенте.
    # 204 No Content — успешный ответ без тела.
    pass


@router.get("/trainer/whoami", response_model=WhoamiResponse)
async def trainer_whoami(
    current_user: dict = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    """Получить данные текущего тренера."""
    trainer_id = current_user.get("sub")
    result = await db.execute(select(Trainer).where(Trainer.id == trainer_id))
    trainer = result.scalar_one_or_none()

    if not trainer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trainer not found",
        )

    return WhoamiResponse(
        user={
            "id": str(trainer.id),
            "email": trainer.email,
            "full_name": trainer.full_name,
            "role": "trainer",
            "is_active": trainer.is_active,
        }
    )
