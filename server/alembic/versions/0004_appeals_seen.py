"""appeals & reward notifications: score_reviews.appeal_note, season_rewards.seen

Revision ID: 0004_appeals_seen
Revises: 0003_settlement
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0004_appeals_seen"
down_revision = "0003_settlement"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "score_reviews",
        sa.Column("appeal_note", sa.String(length=280), nullable=False, server_default=""),
    )
    op.add_column(
        "season_rewards",
        sa.Column("seen", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("season_rewards", "seen")
    op.drop_column("score_reviews", "appeal_note")
