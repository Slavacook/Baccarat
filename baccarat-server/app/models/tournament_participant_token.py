import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class TournamentParticipantTokenStatus:
    ACTIVE = "active"
    REVOKED = "revoked"


class TournamentParticipantToken(Base):
    """Stored hash of a tournament participant token."""

    __tablename__ = "tournament_participant_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    tournament_participant_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("tournament_participants.id"),
        nullable=False,
    )
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=TournamentParticipantTokenStatus.ACTIVE,
        server_default=TournamentParticipantTokenStatus.ACTIVE,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), nullable=False
    )
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint(
            "token_hash",
            name="uq_tournament_participant_tokens_token_hash",
        ),
        Index(
            "idx_tournament_participant_tokens_participant_id",
            "tournament_participant_id",
        ),
        Index("idx_tournament_participant_tokens_status", "status"),
    )

    def __repr__(self) -> str:
        return (
            f"<TournamentParticipantToken participant={self.tournament_participant_id} "
            f"status={self.status}>"
        )
