import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TournamentStatus(str, enum.Enum):
    ACTIVE = "active"
    CLOSED = "closed"


class Tournament(Base):
    """Tournament is an entity independent from training rooms and live sessions."""

    __tablename__ = "tournaments"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    trainer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("trainers.id"), nullable=False, index=True
    )
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    code: Mapped[str] = mapped_column(String(32), nullable=False, unique=True, index=True)
    status: Mapped[TournamentStatus] = mapped_column(
        Enum(TournamentStatus, values_callable=lambda obj: [e.value for e in obj]),
        default=TournamentStatus.ACTIVE,
        index=True,
    )
    max_rounds: Mapped[int] = mapped_column(Integer, nullable=False, default=50)
    attempt_duration_seconds: Mapped[int] = mapped_column(Integer, nullable=False, default=600)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    closed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    def __repr__(self) -> str:
        return f"<Tournament {self.code} ({self.status})>"
