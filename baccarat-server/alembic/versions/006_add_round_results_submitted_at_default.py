"""add round results submitted_at default

Revision ID: 006_round_results_default
Revises: 005_session_participant_status
Create Date: 2026-04-28
"""

from alembic import op
import sqlalchemy as sa


revision = "006_round_results_default"
down_revision = "005_session_participant_status"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.alter_column(
        "round_results",
        "submitted_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
        server_default=sa.text("now()"),
    )


def downgrade() -> None:
    op.alter_column(
        "round_results",
        "submitted_at",
        existing_type=sa.DateTime(timezone=True),
        nullable=False,
        server_default=None,
    )
