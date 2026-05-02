import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TournamentParticipant(Base):
    """Participant identity scoped to a single tournament."""

    __tablename__ = "tournament_participants"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    tournament_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("tournaments.id"), nullable=False
    )
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    normalized_display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), nullable=False
    )
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )

    __table_args__ = (
        UniqueConstraint(
            "tournament_id",
            "normalized_display_name",
            name="uq_tournament_participants_tournament_normalized_name",
        ),
        Index("idx_tournament_participants_tournament_id", "tournament_id"),
    )

    def __repr__(self) -> str:
        return (
            f"<TournamentParticipant tournament={self.tournament_id} "
            f"name={self.display_name!r}>"
        )
