"""settlement & anti-cheat: seasons, season_rewards, score_reviews

Revision ID: 0003_settlement
Revises: 0002_seasons
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

revision = "0003_settlement"
down_revision = "0002_seasons"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "score_reviews",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("entry_id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("season", sa.String(length=32), nullable=False),
        sa.Column("board", sa.String(length=32), nullable=False),
        sa.Column("difficulty", sa.String(length=16), nullable=False),
        sa.Column("score", sa.BigInteger(), nullable=False),
        sa.Column("meta", postgresql.JSONB(astext_type=sa.Text()), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("reason", sa.String(length=255), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("resolved_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_score_reviews_entry_id", "score_reviews", ["entry_id"])
    op.create_index("ix_score_reviews_player_id", "score_reviews", ["player_id"])
    op.create_index("ix_review_status", "score_reviews", ["status", "created_at"])

    op.create_table(
        "seasons",
        sa.Column("id", sa.String(length=32), nullable=False),
        sa.Column("status", sa.String(length=16), nullable=False),
        sa.Column("settled_at", sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )

    op.create_table(
        "season_rewards",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("season", sa.String(length=32), nullable=False),
        sa.Column("board", sa.String(length=32), nullable=False),
        sa.Column("difficulty", sa.String(length=16), nullable=False),
        sa.Column("rank", sa.Integer(), nullable=False),
        sa.Column("token", sa.String(length=48), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("season", "board", "difficulty", "rank", name="uq_reward_slot"),
    )
    op.create_index("ix_reward_player", "season_rewards", ["player_id"])


def downgrade() -> None:
    op.drop_table("season_rewards")
    op.drop_table("seasons")
    op.drop_index("ix_review_status", table_name="score_reviews")
    op.drop_table("score_reviews")
