import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Index, Integer, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class RoomAccessStatus:
    CREATED = "created"
    ACTIVATED = "activated"
    REVOKED = "revoked"
    CLOSED = "closed"


class RoomAccess(Base):
    """Personal access slot for one room participant."""

    __tablename__ = "room_accesses"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rooms.id"), nullable=False
    )
    slot_number: Mapped[int] = mapped_column(Integer, nullable=False)
    access_code_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    access_code_suffix: Mapped[str] = mapped_column(String(16), nullable=False)
    trainer_internal_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    dealer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("dealers.id"), nullable=True
    )
    status: Mapped[str] = mapped_column(
        String(20),
        nullable=False,
        default=RoomAccessStatus.CREATED,
        server_default=RoomAccessStatus.CREATED,
    )
    activated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        UniqueConstraint("room_id", "slot_number", name="uq_room_accesses_room_slot"),
        UniqueConstraint("access_code_hash", name="uq_room_accesses_access_code_hash"),
        Index("idx_room_accesses_room_id", "room_id"),
        Index("idx_room_accesses_dealer_id", "dealer_id"),
        Index("idx_room_accesses_room_status", "room_id", "status"),
    )

    def __repr__(self) -> str:
        return f"<RoomAccess slot={self.slot_number} room={self.room_id} status={self.status}>"
