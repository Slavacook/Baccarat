"""add tournament attempts

Revision ID: 010_tournament_attempts
Revises: 009_tournament_participants
Create Date: 2026-05-02
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "010_tournament_attempts"
down_revision = "009_tournament_participants"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tournament_attempts",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("tournament_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tournaments.id"), nullable=False),
        sa.Column(
            "tournament_participant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tournament_participants.id"),
            nullable=False,
        ),
        sa.Column("attempt_number", sa.Integer(), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False),
        sa.Column("rounds_completed", sa.Integer(), nullable=False),
        sa.Column("errors_total", sa.Integer(), nullable=False),
        sa.Column("time_spent_seconds", sa.Integer(), nullable=False),
        sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint(
            "tournament_participant_id",
            "attempt_number",
            name="uq_tournament_attempts_participant_attempt_number",
        ),
    )
    op.create_index("idx_tournament_attempts_tournament_id", "tournament_attempts", ["tournament_id"])
    op.create_index(
        "idx_tournament_attempts_tournament_participant_id",
        "tournament_attempts",
        ["tournament_participant_id"],
    )
    op.create_index(
        "idx_tournament_attempts_tournament_status",
        "tournament_attempts",
        ["tournament_id", "status"],
    )
    op.create_index("idx_tournament_attempts_submitted_at", "tournament_attempts", ["submitted_at"])


def downgrade() -> None:
    op.drop_index("idx_tournament_attempts_submitted_at", table_name="tournament_attempts")
    op.drop_index("idx_tournament_attempts_tournament_status", table_name="tournament_attempts")
    op.drop_index(
        "idx_tournament_attempts_tournament_participant_id",
        table_name="tournament_attempts",
    )
    op.drop_index("idx_tournament_attempts_tournament_id", table_name="tournament_attempts")
    op.drop_table("tournament_attempts")
