"""add tournament settings

Revision ID: 011_tournament_settings
Revises: 010_tournament_attempts
Create Date: 2026-05-04
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "011_tournament_settings"
down_revision = "010_tournament_attempts"
branch_labels = None
depends_on = None


TOURNAMENT_SETTINGS_DEFAULT_JSON = """
{
  "finish_preset": "rounds_time",
  "max_rounds": 50,
  "max_errors": null,
  "max_duration_minutes": 10,
  "limits_mode": "classic",
  "guests_enabled": [true, true, true, true, true, true],
  "bets": {
    "banker": true,
    "player": true,
    "tie": true,
    "pairs": true
  },
  "first_four_cards": {
    "banker_1": "RANDOM",
    "banker_2": "RANDOM",
    "player_1": "RANDOM",
    "player_2": "RANDOM"
  },
  "guest_story_enabled": true,
  "tip_percentage": 0.3,
  "chance_cards_enabled": false,
  "auto_mode_switch_enabled": true,
  "training_hints_enabled": true
}
""".strip()


def upgrade() -> None:
    op.add_column(
        "tournaments",
        sa.Column(
            "tournament_settings",
            postgresql.JSON(astext_type=sa.Text()),
            nullable=True,
            server_default=sa.text("'%s'::json" % TOURNAMENT_SETTINGS_DEFAULT_JSON.replace("'", "''")),
        ),
    )
    op.execute(
        "UPDATE tournaments "
        "SET tournament_settings = '%s'::json "
        "WHERE tournament_settings IS NULL"
        % TOURNAMENT_SETTINGS_DEFAULT_JSON.replace("'", "''")
    )
    op.alter_column("tournaments", "tournament_settings", nullable=False)


def downgrade() -> None:
    op.drop_column("tournaments", "tournament_settings")
