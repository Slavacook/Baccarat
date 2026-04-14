"""FastAPI зависимости для авторизации и проверки прав."""

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.dealer import Dealer
from app.models.trainer import Trainer
from app.utils.auth import decode_token

# ─── Bearer token схема ───
security = HTTPBearer()


# ═══════════════════════════════════════════════════════════════
# Зависимости для получения текущего пользователя
# ═══════════════════════════════════════════════════════════════

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """Раскодировать JWT и вернуть данные пользователя.

    Подходит для обоих ролей (trainer + dealer).
    Для специфичной проверки используй require_trainer() / require_dealer().
    """
    token = credentials.credentials

    try:
        payload = decode_token(token)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token type (expected: access)",
        )

    return payload


async def require_trainer(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Проверить, что пользователь — тренер."""
    if current_user.get("role") != "trainer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Требуется роль тренера",
        )
    return current_user


async def require_dealer(
    current_user: dict = Depends(get_current_user),
) -> dict:
    """Проверить, что пользователь — дилер."""
    if current_user.get("role") != "dealer":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Требуется роль дилера",
        )
    return current_user


# ═══════════════════════════════════════════════════════════════
# Зависимости для получения модели пользователя из БД
# ═══════════════════════════════════════════════════════════════

async def get_current_trainer(
    current_user: dict = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
) -> Trainer:
    """Получить модель Trainer из БД по данным из JWT."""
    trainer_id = current_user.get("sub")
    if not trainer_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    result = await db.execute(select(Trainer).where(Trainer.id == trainer_id))
    trainer = result.scalar_one_or_none()

    if not trainer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Trainer not found",
        )

    if not trainer.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deactivated",
        )

    return trainer


async def get_current_dealer(
    current_user: dict = Depends(require_dealer),
    db: AsyncSession = Depends(get_db),
) -> Dealer:
    """Получить модель Dealer из БД по данным из JWT."""
    dealer_id = current_user.get("sub")
    if not dealer_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    result = await db.execute(select(Dealer).where(Dealer.id == dealer_id))
    dealer = result.scalar_one_or_none()

    if not dealer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dealer not found",
        )

    if not dealer.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account deactivated",
        )

    return dealer
