"""add live session fields and detailed round results

Revision ID: 002_live_sessions
Revises: 001_initial
Create Date: 2026-04-21
"""

from alembic import op
import sqlalchemy as sa


revision = "002_live_sessions"
down_revision = "001_initial"
branch_labels = None
depends_on = None


def _has_column(table_name: str, column_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return column_name in [col["name"] for col in inspector.get_columns(table_name)]


def upgrade() -> None:
    # sessions
    if not _has_column("sessions", "master_seed"):
        op.add_column("sessions", sa.Column("master_seed", sa.String(255), nullable=True))
        op.execute("UPDATE sessions SET master_seed = md5(random()::text) WHERE master_seed IS NULL")
        op.alter_column("sessions", "master_seed", nullable=False)

    if not _has_column("sessions", "max_rounds"):
        op.add_column("sessions", sa.Column("max_rounds", sa.Integer(), nullable=True))

    if not _has_column("sessions", "end_reason"):
        op.add_column("sessions", sa.Column("end_reason", sa.String(30), nullable=True))

    if not _has_column("sessions", "created_by"):
        op.add_column("sessions", sa.Column("created_by", sa.UUID(), nullable=True))
        op.execute("UPDATE sessions SET created_by = trainer_id WHERE created_by IS NULL")
        op.alter_column("sessions", "created_by", nullable=False)

    # round_results
    if not _has_column("round_results", "player_third_card"):
        op.add_column("round_results", sa.Column("player_third_card", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "banker_third_card"):
        op.add_column("round_results", sa.Column("banker_third_card", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "player_third_correct"):
        op.add_column("round_results", sa.Column("player_third_correct", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "banker_third_correct"):
        op.add_column("round_results", sa.Column("banker_third_correct", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "winner_chosen"):
        op.add_column("round_results", sa.Column("winner_chosen", sa.String(10), nullable=True))
    if not _has_column("round_results", "winner_correct"):
        op.add_column("round_results", sa.Column("winner_correct", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "payout_correct"):
        op.add_column("round_results", sa.Column("payout_correct", sa.Boolean(), nullable=True))
    if not _has_column("round_results", "lives_remaining"):
        op.add_column("round_results", sa.Column("lives_remaining", sa.Integer(), nullable=True))
    if not _has_column("round_results", "round_xp"):
        op.add_column("round_results", sa.Column("round_xp", sa.Integer(), nullable=False, server_default="0"))
    if not _has_column("round_results", "submitted_at"):
        op.add_column("round_results", sa.Column("submitted_at", sa.DateTime(timezone=True), nullable=True))
        op.execute("UPDATE round_results SET submitted_at = created_at WHERE submitted_at IS NULL")
        op.alter_column("round_results", "submitted_at", nullable=False)
        op.create_index("idx_round_results_submitted_at", "round_results", ["submitted_at"])

    # unique constraints for data consistency
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_session_participant'
            ) THEN
                ALTER TABLE session_participants
                ADD CONSTRAINT uq_session_participant UNIQUE (session_id, dealer_id);
            END IF;
        END$$;
        """
    )
    op.execute(
        """
        DO $$
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_constraint WHERE conname = 'uq_round_result_per_round'
            ) THEN
                ALTER TABLE round_results
                ADD CONSTRAINT uq_round_result_per_round UNIQUE (session_id, dealer_id, round_number);
            END IF;
        END$$;
        """
    )


def downgrade() -> None:
    # Безопасный откат не выполняем автоматически — миграция применяется на прод-данные.
    pass
