"""initial - create all tables with foreign keys

Revision ID: 001_initial
Revises: 
Create Date: 2026-04-13
"""

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "001_initial"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ═══════════════════════════════════════════════════════════
    # trainers
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "trainers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("email", sa.String(255), unique=True, nullable=False),
        sa.Column("password_hash", sa.String(255), nullable=False),
        sa.Column("full_name", sa.String(255), nullable=True),
        sa.Column("is_active", sa.Boolean, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_trainers_email", "trainers", ["email"])

    # ═══════════════════════════════════════════════════════════
    # rooms (с FK на trainers)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "rooms",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("trainer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("trainers.id"), nullable=False),
        sa.Column("room_code", sa.String(20), unique=True, nullable=False),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("settings", postgresql.JSON, nullable=False, server_default="{}"),
        sa.Column("status", sa.Enum("active", "archived", "closed", name="roomstatus"), server_default="active"),
        sa.Column("max_dealers", sa.Integer, server_default="20"),
        sa.Column("total_dealers", sa.Integer, server_default="0"),
        sa.Column("total_sessions", sa.Integer, server_default="0"),
        sa.Column("total_rounds", sa.Integer, server_default="0"),
        sa.Column("last_session_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("archived_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("closed_at", sa.DateTime(timezone=True), nullable=True),
    )
    op.create_index("idx_rooms_trainer_id", "rooms", ["trainer_id"])
    op.create_index("idx_rooms_room_code", "rooms", ["room_code"])
    op.create_index("idx_rooms_status", "rooms", ["status"])

    # ═══════════════════════════════════════════════════════════
    # dealers (с FK на rooms)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "dealers",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rooms.id"), nullable=False),
        sa.Column("display_name", sa.String(255), nullable=False),
        sa.Column("is_active", sa.Boolean, server_default=sa.text("true")),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_dealers_room_id", "dealers", ["room_id"])

    # ═══════════════════════════════════════════════════════════
    # room_pins (с FK на rooms и dealers)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "room_pins",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rooms.id"), nullable=False),
        sa.Column("pin_hash", sa.String(255), nullable=False),
        sa.Column("dealer_slot", sa.Integer, nullable=False),
        sa.Column("dealer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dealers.id"), nullable=True),
        sa.Column("is_active", sa.Boolean, server_default=sa.text("true")),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_room_pins_room_id", "room_pins", ["room_id"])
    op.create_index("idx_room_pins_dealer_id", "room_pins", ["dealer_id"])

    # ═══════════════════════════════════════════════════════════
    # sessions (с FK на rooms и trainers)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "sessions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("room_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("rooms.id"), nullable=False),
        sa.Column("trainer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("trainers.id"), nullable=False),
        sa.Column("status", sa.Enum("created", "active", "completed", "aborted", name="sessionstatus"), server_default="created"),
        sa.Column("session_type", sa.Enum("live", "async", name="sessiontype"), server_default="live"),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("ended_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("duration_seconds", sa.Integer, nullable=True),
        sa.Column("total_rounds", sa.Integer, server_default="0"),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_sessions_room_id", "sessions", ["room_id"])
    op.create_index("idx_sessions_trainer_id", "sessions", ["trainer_id"])

    # ═══════════════════════════════════════════════════════════
    # session_participants (с FK на sessions и dealers)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "session_participants",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sessions.id"), nullable=False),
        sa.Column("dealer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dealers.id"), nullable=False),
        sa.Column("joined_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("left_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("rounds_completed", sa.Integer, server_default="0"),
    )
    op.create_index("idx_session_participants_session_id", "session_participants", ["session_id"])
    op.create_index("idx_session_participants_dealer_id", "session_participants", ["dealer_id"])

    # ═══════════════════════════════════════════════════════════
    # round_results (с FK на sessions и dealers)
    # ═══════════════════════════════════════════════════════════
    op.create_table(
        "round_results",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True, server_default=sa.text("gen_random_uuid()")),
        sa.Column("session_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("sessions.id"), nullable=False),
        sa.Column("dealer_id", postgresql.UUID(as_uuid=True), sa.ForeignKey("dealers.id"), nullable=False),
        sa.Column("round_number", sa.Integer, nullable=False),
        sa.Column("accuracy", sa.Float, nullable=False),
        sa.Column("errors", postgresql.JSON, nullable=False, server_default="[]"),
        sa.Column("time_spent_seconds", sa.Integer, nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("idx_round_results_session_id", "round_results", ["session_id"])
    op.create_index("idx_round_results_dealer_id", "round_results", ["dealer_id"])


def downgrade() -> None:
    op.drop_table("round_results")
    op.drop_table("session_participants")
    op.drop_table("sessions")
    op.drop_table("room_pins")
    op.drop_table("dealers")
    op.drop_table("rooms")
    op.drop_table("trainers")
    op.execute("DROP TYPE IF EXISTS roomstatus")
    op.execute("DROP TYPE IF EXISTS sessionstatus")
    op.execute("DROP TYPE IF EXISTS sessiontype")
