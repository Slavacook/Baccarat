import uuid
from datetime import datetime

from sqlalchemy import String, Integer, Boolean, DateTime, func, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Achievement(Base):
    """Справочник достижений."""

    __tablename__ = "achievements"

    id: Mapped[str] = mapped_column(String(50), primary_key=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str] = mapped_column(String, nullable=False)
    icon: Mapped[str] = mapped_column(String(10), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False, index=True)
    xp_reward: Mapped[int] = mapped_column(Integer, default=0)
    condition: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    hidden: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class DealerAchievement(Base):
    """Разблокированные достижения дилера."""

    __tablename__ = "dealer_achievements"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    achievement_id: Mapped[str] = mapped_column(
        String(50), nullable=False, index=True
    )
    unlocked_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    xp_awarded: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        # Уникальная пара: дилер + достижение
    )
