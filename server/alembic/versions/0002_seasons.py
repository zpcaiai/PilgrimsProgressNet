"""seasons: add season column + index to leaderboard_entries

Revision ID: 0002_seasons
Revises: 0001_init
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0002_seasons"
down_revision = "0001_init"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "leaderboard_entries",
        sa.Column("season", sa.String(length=32), nullable=False, server_default="all"),
    )
    op.create_index(
        "ix_season_board_diff_score",
        "leaderboard_entries",
        ["season", "board", "difficulty", "score"],
    )


def downgrade() -> None:
    op.drop_index("ix_season_board_diff_score", table_name="leaderboard_entries")
    op.drop_column("leaderboard_entries", "season")
