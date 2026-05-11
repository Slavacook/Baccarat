"""add tournament attempt finish reason

Revision ID: 012_tournament_attempt_finish_reason
Revises: 011_tournament_settings
Create Date: 2026-05-11
"""

from alembic import op
import sqlalchemy as sa


revision = "012_tournament_attempt_finish_reason"
down_revision = "011_tournament_settings"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "tournament_attempts",
        sa.Column("finish_reason", sa.String(length=64), nullable=True),
    )


def downgrade() -> None:
    op.drop_column("tournament_attempts", "finish_reason")
