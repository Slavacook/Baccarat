import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TournamentAttemptStatus:
    SUCCESS = "success"
    FAILED = "failed"


class TournamentAttempt(Base):
    """One stored tournament attempt submitted by a participant."""

    __tablename__ = "tournament_attempts"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    tournament_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tournaments.id"), nullable=False
    )
    tournament_participant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tournament_participants.id"), nullable=False
    )
    attempt_number: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False)
    finish_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    rounds_completed: Mapped[int] = mapped_column(Integer, nullable=False)
    errors_total: Mapped[int] = mapped_column(Integer, nullable=False)
    time_spent_seconds: Mapped[int] = mapped_column(Integer, nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        UniqueConstraint(
            "tournament_participant_id",
            "attempt_number",
            name="uq_tournament_attempts_participant_attempt_number",
        ),
        Index("idx_tournament_attempts_tournament_id", "tournament_id"),
        Index(
            "idx_tournament_attempts_tournament_participant_id",
            "tournament_participant_id",
        ),
        Index(
            "idx_tournament_attempts_tournament_status",
            "tournament_id",
            "status",
        ),
        Index("idx_tournament_attempts_submitted_at", "submitted_at"),
    )

    def __repr__(self) -> str:
        return (
            f"<TournamentAttempt tournament={self.tournament_id} "
            f"participant={self.tournament_participant_id} "
            f"attempt={self.attempt_number} status={self.status}>"
        )
