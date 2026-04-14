import uuid
import enum
from datetime import datetime

from sqlalchemy import String, Integer, ForeignKey, Enum, DateTime, func, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoomStatus(str, enum.Enum):
    ACTIVE = "active"
    ARCHIVED = "archived"
    CLOSED = "closed"


class Room(Base):
    """Модель комнаты (объединяет тренера и дилеров)."""

    __tablename__ = "rooms"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    trainer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trainers.id"), nullable=False, index=True
    )
    room_code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False, index=True)
    name: Mapped[str] = mapped_column(String(255), nullable=False)
    settings: Mapped[dict] = mapped_column(JSON, nullable=False, default=dict)
    status: Mapped[RoomStatus] = mapped_column(
        Enum(RoomStatus), default=RoomStatus.ACTIVE, index=True
    )
    max_dealers: Mapped[int] = mapped_column(Integer, default=20)
    total_dealers: Mapped[int] = mapped_column(Integer, default=0)
    total_sessions: Mapped[int] = mapped_column(Integer, default=0)
    total_rounds: Mapped[int] = mapped_column(Integer, default=0)
    last_session_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # ─── Relationships ───
    trainer: Mapped["Trainer"] = relationship("Trainer", back_populates="rooms", lazy="selectin")
    dealers: Mapped[list["Dealer"]] = relationship("Dealer", back_populates="room", lazy="selectin")
    sessions: Mapped[list["Session"]] = relationship("Session", back_populates="room", lazy="selectin")
    pins: Mapped[list["RoomPin"]] = relationship("RoomPin", back_populates="room", lazy="selectin")

    def __repr__(self) -> str:
        return f"<Room {self.room_code} - {self.name}>"
