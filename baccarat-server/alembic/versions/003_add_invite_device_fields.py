"""Add invite fields to RoomPin and device fields to Dealer

Revision ID: 003_invite_device
Revises: 002_live_sessions
Create Date: 2026-04-26
"""

from alembic import op
import sqlalchemy as sa


revision = "003_invite_device"
down_revision = "002_live_sessions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # room_pins
    op.add_column("room_pins", sa.Column("invite_token", sa.String(255), nullable=True))
    op.add_column("room_pins", sa.Column("invite_status", sa.String(255), nullable=False, server_default="unused"))
    op.add_column("room_pins", sa.Column("claimed_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("room_pins", sa.Column("revoked_at", sa.DateTime(timezone=True), nullable=True))
    op.add_column("room_pins", sa.Column("device_reset_at", sa.DateTime(timezone=True), nullable=True))
    
    # dealers
    op.add_column("dealers", sa.Column("device_id", sa.String(255), nullable=True))
    op.add_column("dealers", sa.Column("device_claimed_at", sa.DateTime(timezone=True), nullable=True))
    
    # Create unique index on invite_token
    op.create_index("ix_room_pins_invite_token", "room_pins", ["invite_token"], unique=True)


def downgrade() -> None:
    # Drop unique index
    op.drop_index("ix_room_pins_invite_token", table_name="room_pins")
    
    # Drop columns from room_pins
    op.drop_column("room_pins", "device_reset_at")
    op.drop_column("room_pins", "revoked_at")
    op.drop_column("room_pins", "claimed_at")
    op.drop_column("room_pins", "invite_status")
    op.drop_column("room_pins", "invite_token")
    
    # Drop columns from dealers
    op.drop_column("dealers", "device_claimed_at")
    op.drop_column("dealers", "device_id")