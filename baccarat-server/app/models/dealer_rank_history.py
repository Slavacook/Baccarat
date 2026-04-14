import uuid
from datetime import datetime

from sqlalchemy import String, Integer, Float, DateTime, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class DealerRankHistory(Base):
    """История изменений ранга дилера."""

    __tablename__ = "dealer_ranks_history"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    from_rank: Mapped[int] = mapped_column(Integer, nullable=False)
    to_rank: Mapped[int] = mapped_column(Integer, nullable=False)
    total_xp: Mapped[int] = mapped_column(Integer, nullable=False)
    total_rounds: Mapped[int] = mapped_column(Integer, nullable=False)
    accuracy: Mapped[float] = mapped_column(Float, nullable=False)
    achieved_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), index=True
    )
