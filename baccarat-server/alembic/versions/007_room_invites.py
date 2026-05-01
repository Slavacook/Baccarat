"""add room invites

Revision ID: 007_room_invites
Revises: 006_round_results_default
Create Date: 2026-05-01
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "007_room_invites"
down_revision = "006_round_results_default"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "room_invites",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rooms.id"), nullable=False),
        sa.Column("invite_code_hash", sa.String(255), nullable=False),
        sa.Column("invite_code_suffix", sa.String(16), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("invite_code_hash", name="uq_room_invites_invite_code_hash"),
    )
    op.create_index("idx_room_invites_room_id", "room_invites", ["room_id"])
    op.create_index("idx_room_invites_room_status", "room_invites", ["room_id", "status"])

    op.add_column(
        "participant_tokens",
        sa.Column("room_invite_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("room_invites.id"), nullable=True),
    )
    op.create_index("idx_participant_tokens_room_invite_id", "participant_tokens", ["room_invite_id"])
    op.alter_column("participant_tokens", "room_access_id", existing_type=postgresql.UUID(as_uuid=True), nullable=True)
    op.create_check_constraint(
        "ck_participant_tokens_exactly_one_access_source",
        "participant_tokens",
        "(room_access_id IS NOT NULL AND room_invite_id IS NULL) OR "
        "(room_access_id IS NULL AND room_invite_id IS NOT NULL)",
    )


def downgrade() -> None:
    op.execute("DELETE FROM participant_tokens WHERE room_access_id IS NULL")
    op.execute(
        "ALTER TABLE participant_tokens "
        "DROP CONSTRAINT IF EXISTS ck_participant_tokens_exactly_one_access_source"
    )
    op.alter_column("participant_tokens", "room_access_id", existing_type=postgresql.UUID(as_uuid=True), nullable=False)
    op.drop_index("idx_participant_tokens_room_invite_id", table_name="participant_tokens")
    op.drop_column("participant_tokens", "room_invite_id")

    op.drop_index("idx_room_invites_room_status", table_name="room_invites")
    op.drop_index("idx_room_invites_room_id", table_name="room_invites")
    op.drop_table("room_invites")
