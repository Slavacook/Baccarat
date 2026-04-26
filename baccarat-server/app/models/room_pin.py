import uuid
from datetime import datetime

from sqlalchemy import String, Boolean, Integer, ForeignKey, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoomPin(Base):
    """PIN-код для входа дилера в комнату."""

    __tablename__ = "room_pins"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rooms.id"), nullable=False, index=True
    )
    pin_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    dealer_slot: Mapped[int] = mapped_column(Integer, nullable=False)
    dealer_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("dealers.id"), nullable=True, index=True
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    
    # Invite fields
    invite_token: Mapped[str | None] = mapped_column(String(255), nullable=True, unique=True)
    invite_status: Mapped[str] = mapped_column(String(255), nullable=False, default="unused")
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    device_reset_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # ─── Relationships ───
    room: Mapped["Room"] = relationship("Room", back_populates="pins", lazy="selectin")

    __table_args__ = (
        # Уникальный слот в пределах комнаты
    )

    def __repr__(self) -> str:
        return f"<RoomPin slot={self.dealer_slot} room={self.room_id}>"
