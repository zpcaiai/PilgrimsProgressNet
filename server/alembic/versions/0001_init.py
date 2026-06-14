"""init: players, cloud_saves, leaderboard_entries, ghost_trails, stat_events

Revision ID: 0001_init
Revises:
Create Date: 2026-06-14

Hand-written initial schema targeting PostgreSQL (JSONB). Mirrors app/models.py.
After the DB is reachable you can equivalently regenerate with:
    alembic revision --autogenerate -m "init"
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0001_init"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "players",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("device_id", sa.String(length=128), nullable=False),
        sa.Column("display_name", sa.String(length=64), nullable=False),
        sa.Column("email", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("last_seen_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("device_id"),
        sa.UniqueConstraint("email"),
    )
    op.create_index("ix_players_device_id", "players", ["device_id"], unique=True)

    op.create_table(
        "cloud_saves",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("slot_id", sa.String(length=32), nullable=False),
        sa.Column("version", sa.Integer(), nullable=False),
        sa.Column("payload", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("device_clock", sa.DateTime(timezone=True), nullable=True),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("player_id", "slot_id", name="uq_save_slot"),
    )
    op.create_index("ix_cloud_saves_player_id", "cloud_saves", ["player_id"])

    op.create_table(
        "leaderboard_entries",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("board", sa.String(length=32), nullable=False),
        sa.Column("difficulty", sa.String(length=16), nullable=False),
        sa.Column("score", sa.BigInteger(), nullable=False),
        sa.Column("meta", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_leaderboard_entries_player_id", "leaderboard_entries", ["player_id"])
    op.create_index("ix_board_diff_score", "leaderboard_entries", ["board", "difficulty", "score"])

    op.create_table(
        "ghost_trails",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("chapter_id", sa.String(length=64), nullable=False),
        sa.Column("kind", sa.String(length=16), nullable=False),
        sa.Column("points", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_ghost_trails_player_id", "ghost_trails", ["player_id"])
    op.create_index("ix_ghost_chapter_created", "ghost_trails", ["chapter_id", "created_at"])

    op.create_table(
        "stat_events",
        sa.Column("id", sa.BigInteger(), autoincrement=True, nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=True),
        sa.Column("event", sa.String(length=64), nullable=False),
        sa.Column("chapter_id", sa.String(length=64), nullable=True),
        sa.Column("difficulty", sa.String(length=16), nullable=True),
        sa.Column("props", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_stat_events_player_id", "stat_events", ["player_id"])
    op.create_index("ix_stat_event_created", "stat_events", ["event", "created_at"])
    op.create_index("ix_stat_chapter", "stat_events", ["chapter_id"])


def downgrade() -> None:
    op.drop_table("stat_events")
    op.drop_table("ghost_trails")
    op.drop_table("leaderboard_entries")
    op.drop_table("cloud_saves")
    op.drop_index("ix_players_device_id", table_name="players")
    op.drop_table("players")
