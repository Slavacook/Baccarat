"""add room accesses and participant tokens

Revision ID: 004_room_accesses
Revises: 003_invite_device
Create Date: 2026-04-28
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "004_room_accesses"
down_revision = "003_invite_device"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "room_accesses",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rooms.id"), nullable=False),
        sa.Column("slot_number", sa.Integer(), nullable=False),
        sa.Column("access_code_hash", sa.String(255), nullable=False),
        sa.Column("access_code_suffix", sa.String(16), nullable=False),
        sa.Column("trainer_internal_name", sa.String(255), nullable=True),
        sa.Column("dealer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dealers.id"), nullable=True),
        sa.Column("status", sa.String(20), nullable=False, server_default="created"),
        sa.Column("activated_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("room_id", "slot_number", name="uq_room_accesses_room_slot"),
        sa.UniqueConstraint("access_code_hash", name="uq_room_accesses_access_code_hash"),
    )
    op.create_index("idx_room_accesses_room_id", "room_accesses", ["room_id"])
    op.create_index("idx_room_accesses_dealer_id", "room_accesses", ["dealer_id"])
    op.create_index("idx_room_accesses_room_status", "room_accesses", ["room_id", "status"])

    op.create_table(
        "participant_tokens",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column(
            "room_access_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("room_accesses.id"),
            nullable=False,
        ),
        sa.Column("dealer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dealers.id"), nullable=False),
        sa.Column("token_hash", sa.String(255), nullable=False),
        sa.Column("status", sa.String(20), nullable=False, server_default="active"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.Column("last_used_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("token_hash", name="uq_participant_tokens_token_hash"),
    )
    op.create_index("idx_participant_tokens_room_access_id", "participant_tokens", ["room_access_id"])
    op.create_index("idx_participant_tokens_dealer_id", "participant_tokens", ["dealer_id"])
    op.create_index("idx_participant_tokens_status", "participant_tokens", ["status"])


def downgrade() -> None:
    op.drop_index("idx_participant_tokens_status", table_name="participant_tokens")
    op.drop_index("idx_participant_tokens_dealer_id", table_name="participant_tokens")
    op.drop_index("idx_participant_tokens_room_access_id", table_name="participant_tokens")
    op.drop_table("participant_tokens")

    op.drop_index("idx_room_accesses_room_status", table_name="room_accesses")
    op.drop_index("idx_room_accesses_dealer_id", table_name="room_accesses")
    op.drop_index("idx_room_accesses_room_id", table_name="room_accesses")
    op.drop_table("room_accesses")
