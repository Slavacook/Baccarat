import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class ParticipantTokenStatus:
    ACTIVE = "active"
    REVOKED = "revoked"
    EXPIRED = "expired"


class ParticipantToken(Base):
    """Stored hash of a local room participant token."""

    __tablename__ = "participant_tokens"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_access_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("room_accesses.id"), nullable=False
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("dealers.id"), nullable=False
    )
    token_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=ParticipantTokenStatus.ACTIVE,
        server_default=ParticipantTokenStatus.ACTIVE,
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("token_hash", name="uq_participant_tokens_token_hash"),
        Index("idx_participant_tokens_room_access_id", "room_access_id"),
        Index("idx_participant_tokens_dealer_id", "dealer_id"),
        Index("idx_participant_tokens_status", "status"),
    )

    def __repr__(self) -> str:
        return f"<ParticipantToken dealer={self.dealer_id} status={self.status}>"
