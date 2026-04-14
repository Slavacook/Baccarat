import uuid
from datetime import datetime

from sqlalchemy import String, Integer, Float, Boolean, DateTime, func, JSON
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Assignment(Base):
    """Домашнее задание от тренера."""

    __tablename__ = "assignments"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    room_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    trainer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    assignment_type: Mapped[str] = mapped_column(String(30), nullable=False)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    description: Mapped[str | None] = mapped_column(String, nullable=True)
    target_category: Mapped[str | None] = mapped_column(String(50), nullable=True)
    target_rounds: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target_accuracy: Mapped[float | None] = mapped_column(Float, nullable=True)
    target_time: Mapped[float | None] = mapped_column(Float, nullable=True)
    target_streak: Mapped[int | None] = mapped_column(Integer, nullable=True)
    target_consecutive: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    start_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    is_recurring: Mapped[bool] = mapped_column(Boolean, default=False)
    recurrence_pattern: Mapped[str | None] = mapped_column(String(20), nullable=True)
    assigned_to: Mapped[dict] = mapped_column(JSON, nullable=False)
    bonus_xp: Mapped[int] = mapped_column(Integer, default=0)
    reward_message: Mapped[str | None] = mapped_column(String, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="active", index=True)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    cancelled_by: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)


class AssignmentCompletion(Base):
    """Выполнение задания дилером."""

    __tablename__ = "assignment_completions"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    assignment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    completed_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    bonus_xp_earned: Mapped[int] = mapped_column(Integer, nullable=False)

    __table_args__ = (
        # Уникальная пара: дилер + задание
    )


class AssignmentProgress(Base):
    """Кэш прогресса задания дилером."""

    __tablename__ = "assignment_progress"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), primary_key=True, default=uuid.uuid4
    )
    dealer_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    assignment_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False, index=True)
    rounds_completed: Mapped[int] = mapped_column(Integer, default=0)
    accuracy: Mapped[float | None] = mapped_column(Float, nullable=True)
    avg_time: Mapped[float | None] = mapped_column(Float, nullable=True)
    current_streak: Mapped[int] = mapped_column(Integer, default=0)
    consecutive_correct: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())

    __table_args__ = (
        # Уникальная пара: дилер + задание
    )
