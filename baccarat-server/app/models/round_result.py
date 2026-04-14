import uuid
from datetime import datetime

from sqlalchemy import String, Integer, Float, Boolean, ForeignKey, DateTime, func, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class RoundResult(Base):
    """Результат одного раунда дилера."""

    __tablename__ = "round_results"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("sessions.id"), nullable=False, index=True
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("dealers.id"), nullable=False, index=True
    )
    round_number: Mapped[int] = mapped_column(Integer, nullable=False)

    # ─── Результаты ───
    accuracy: Mapped[float] = mapped_column(Float, nullable=False)
    errors: Mapped[list] = mapped_column(JSON, nullable=False, default=list)
    time_spent_seconds: Mapped[int] = mapped_column(Integer, nullable=False)

    # ─── Решения дилера ───
    player_third_card: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    banker_third_card: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    player_third_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    banker_third_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    winner_chosen: Mapped[str | None] = mapped_column(String(10), nullable=True)
    winner_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)
    payout_correct: Mapped[bool | None] = mapped_column(Boolean, nullable=True)

    # ─── Состояние ───
    lives_remaining: Mapped[int | None] = mapped_column(Integer, nullable=True)
    round_xp: Mapped[int] = mapped_column(Integer, default=0)

    # ─── Время ───
    submitted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )

    # ─── Relationships ───
    session: Mapped["Session"] = relationship("Session", back_populates="round_results", lazy="selectin")

    __table_args__ = (
        # Уникальная пара: сессия + дилер + номер раунда
    )

    def __repr__(self) -> str:
        return f"<RoundResult R{self.round_number} dealer={self.dealer_id} acc={self.accuracy}>"
