import uuid
import enum
from datetime import datetime

from sqlalchemy import String, Integer, ForeignKey, Enum, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class SessionStatus(str, enum.Enum):
    CREATED = "created"
    ACTIVE = "active"
    COMPLETED = "completed"
    ABORTED = "aborted"


class SessionType(str, enum.Enum):
    LIVE = "live"
    ASYNC = "async"


class Session(Base):
    """Модель сессии (живая или асинхронная тренировка)."""

    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rooms.id"), nullable=False, index=True
    )
    trainer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trainers.id"), nullable=False, index=True
    )
    status: Mapped[SessionStatus] = mapped_column(
        Enum(SessionStatus), default=SessionStatus.CREATED, index=True
    )
    type: Mapped[SessionType] = mapped_column(
        Enum(SessionType), default=SessionType.LIVE
    )
    master_seed: Mapped[str] = mapped_column(String(255), nullable=False)
    duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    max_rounds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    end_reason: Mapped[str | None] = mapped_column(String(30), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    created_by: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)

    # ─── Relationships ───
    room: Mapped["Room"] = relationship("Room", back_populates="sessions", lazy="selectin")
    participants: Mapped[list["SessionParticipant"]] = relationship(
        "SessionParticipant", back_populates="session", lazy="selectin"
    )
    round_results: Mapped[list["RoundResult"]] = relationship(
        "RoundResult", back_populates="session", lazy="selectin"
    )

    def __repr__(self) -> str:
        return f"<Session {self.id} ({self.status})>"


class SessionParticipant(Base):
    """Участник живой сессии."""

    __tablename__ = "session_participants"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False, index=True
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("dealers.id"), nullable=False, index=True
    )
    joined_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    left_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    rounds_completed: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(20), default="joined")

    # ─── Relationships ───
    session: Mapped["Session"] = relationship("Session", back_populates="participants", lazy="selectin")

    __table_args__ = (
        # Уникальная пара сессия + дилер
    )

    def __repr__(self) -> str:
        return f"<SessionParticipant {self.dealer_id} in {self.session_id}>"
