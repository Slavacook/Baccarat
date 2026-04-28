"""add session participant status

Revision ID: 005_session_participant_status
Revises: 004_room_accesses
Create Date: 2026-04-28
"""

from alembic import op
import sqlalchemy as sa


revision = "005_session_participant_status"
down_revision = "004_room_accesses"
branch_labels = None
depends_on = None


def _has_column(table_name: str, column_name: str) -> bool:
    bind = op.get_bind()
    inspector = sa.inspect(bind)
    return column_name in [col["name"] for col in inspector.get_columns(table_name)]


def upgrade() -> None:
    if not _has_column("session_participants", "status"):
        op.add_column(
            "session_participants",
            sa.Column("status", sa.String(20), nullable=False, server_default="joined"),
        )


def downgrade() -> None:
    if _has_column("session_participants", "status"):
        op.drop_column("session_participants", "status")
