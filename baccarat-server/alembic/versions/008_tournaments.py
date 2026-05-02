"""add tournaments

Revision ID: 008_tournaments
Revises: 007_room_invites
Create Date: 2026-05-02
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


revision = "008_tournaments"
down_revision = "007_room_invites"
branch_labels = None
depends_on = None


def upgrade() -> None:
    tournament_status = postgresql.ENUM(
        "active",
        "closed",
        name="tournamentstatus",
        create_type=False,
    )
    tournament_status.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "tournaments",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
            server_default=sa.text("gen_random_uuid()"),
        ),
        sa.Column("trainer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("trainers.id"), nullable=False),
        sa.Column("title", sa.String(length=255), nullable=False),
        sa.Column("code", sa.String(length=32), nullable=False),
        sa.Column("status", tournament_status, nullable=False, server_default="active"),
        sa.Column("max_rounds", sa.Integer(), nullable=False, server_default="50"),
        sa.Column("attempt_duration_seconds", sa.Integer(), nullable=False, server_default="600"),
        sa.Column("created_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("updated_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.text("now()")),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
        sa.UniqueConstraint("code", name="uq_tournaments_code"),
    )
    op.create_index("idx_tournaments_trainer_id", "tournaments", ["trainer_id"])
    op.create_index("idx_tournaments_status", "tournaments", ["status"])


def downgrade() -> None:
    op.drop_index("idx_tournaments_status", table_name="tournaments")
    op.drop_index("idx_tournaments_trainer_id", table_name="tournaments")
    op.drop_table("tournaments")

    tournament_status = postgresql.ENUM(
        "active",
        "closed",
        name="tournamentstatus",
        create_type=False,
    )
    tournament_status.drop(op.get_bind(), checkfirst=True)
