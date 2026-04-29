import uuid
from datetime import datetime

from sqlalchemy import String, Boolean, ForeignKey, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Dealer(Base):
    """Модель дилера (участник тренировки в комнате)."""

    __tablename__ = "dealers"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("rooms.id"), nullable=False, index=True
    )
    display_name: Mapped[str] = mapped_column(String(255), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )

    # Invite/device fields from migration 003
    device_id: Mapped[str | None] = mapped_column(String(255), nullable=True)
    device_claimed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # ─── Relationships ───
    room: Mapped["Room"] = relationship("Room", back_populates="dealers", lazy="selectin")

    __table_args__ = (
        # Уникальное имя в пределах комнаты
    )

    def __repr__(self) -> str:
        return f"<Dealer {self.display_name} in room {self.room_id}>"
