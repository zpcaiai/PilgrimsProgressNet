"""chat: dm_pins (pinned conversations) + mentions (@notifications)

Revision ID: 0007_pins_mentions
Revises: 0006_dm_unread
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0007_pins_mentions"
down_revision = "0006_dm_unread"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "dm_pins",
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("peer_id", sa.String(length=36), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("player_id", "peer_id"),
    )
    op.create_table(
        "mentions",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("from_id", sa.String(length=36), nullable=False),
        sa.Column("from_name", sa.String(length=64), nullable=False),
        sa.Column("channel", sa.String(length=16), nullable=False),
        sa.Column("scope", sa.String(length=96), nullable=False),
        sa.Column("text", sa.String(length=220), nullable=False),
        sa.Column("seen", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mentions_player_id", "mentions", ["player_id"])
    op.create_index("ix_mention_player_seen", "mentions", ["player_id", "seen"])


def downgrade() -> None:
    op.drop_index("ix_mention_player_seen", table_name="mentions")
    op.drop_table("mentions")
    op.drop_table("dm_pins")
