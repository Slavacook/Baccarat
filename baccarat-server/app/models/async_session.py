import uuid
import enum
from datetime import datetime

from sqlalchemy import String, Integer, Enum, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class AsyncSessionStatus(str, enum.Enum):
    ACTIVE = "active"
    COMPLETED = "completed"
    TIMEOUT = "timeout"
    LIMIT_REACHED = "limit_reached"


class AsyncSession(Base):
    """Модель асинхронной сессии (свободная тренировка дилера)."""

    __tablename__ = "async_sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), nullable=False, index=True
    )
    status: Mapped[AsyncSessionStatus] = mapped_column(
        Enum(AsyncSessionStatus), default=AsyncSessionStatus.ACTIVE, index=True
    )
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    end_reason: Mapped[str | None] = mapped_column(String(30), nullable=True)
    rounds_completed: Mapped[int] = mapped_column(Integer, default=0)
    total_time_seconds: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    def __repr__(self) -> str:
        return f"<AsyncSession {self.id} dealer={self.dealer_id} status={self.status}>"
