import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomInviteStatus:
    ACTIVE = "active"
    REVOKED = "revoked"
    EXPIRED = "expired"


class RoomInvite(Base):
    """Shared room invite code. Plaintext is shown only at generation time."""

    __tablename__ = "room_invites"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rooms.id"), nullable=False
    )
    invite_code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    invite_code_suffix: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=RoomInviteStatus.ACTIVE,
        server_default=RoomInviteStatus.ACTIVE,
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    __table_args__ = (
        UniqueConstraint("invite_code_hash", name="uq_room_invites_invite_code_hash"),
        Index("idx_room_invites_room_id", "room_id"),
        Index("idx_room_invites_room_status", "room_id", "status"),
    )

    def __repr__(self) -> str:
        return f"<RoomInvite room={self.room_id} status={self.status}>"
