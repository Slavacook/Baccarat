"""add tournament participants

Revision ID: 009_tournament_participants
Revises: 008_tournaments
Create Date: 2026-05-02
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "009_tournament_participants"
down_revision = "008_tournaments"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "tournament_participants",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("tournament_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("tournaments.id"), nullable=False),
        sa.Column("display_name", sa.String(length=100), nullable=False),
        sa.Column("normalized_display_name", sa.String(length=100), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.UniqueConstraint(
            "tournament_id",
            "normalized_display_name",
            name="uq_tournament_participants_tournament_normalized_name",
        ),
    )
    op.create_index(
        "idx_tournament_participants_tournament_id",
        "tournament_participants",
        ["tournament_id"],
    )

    op.create_table(
        "tournament_participant_tokens",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "tournament_participant_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("tournament_participants.id"),
            nullable=False,
        ),
        sa.Column("token_hash", sa.String(length=255), nullable=False),
        sa.Column("status", sa.String(length=20), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("token_hash", name="uq_tournament_participant_tokens_token_hash"),
    )
    op.create_index(
        "idx_tournament_participant_tokens_participant_id",
        "tournament_participant_tokens",
        ["tournament_participant_id"],
    )
    op.create_index(
        "idx_tournament_participant_tokens_status",
        "tournament_participant_tokens",
        ["status"],
    )


def downgrade() -> None:
    op.drop_index(
        "idx_tournament_participant_tokens_status",
        table_name="tournament_participant_tokens",
    )
    op.drop_index(
        "idx_tournament_participant_tokens_participant_id",
        table_name="tournament_participant_tokens",
    )
    op.drop_table("tournament_participant_tokens")

    op.drop_index(
        "idx_tournament_participants_tournament_id",
        table_name="tournament_participants",
    )
    op.drop_table("tournament_participants")
