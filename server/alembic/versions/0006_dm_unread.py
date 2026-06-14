"""chat: dm_unread counters (private-message red dot)

Revision ID: 0006_dm_unread
Revises: 0005_chat
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0006_dm_unread"
down_revision = "0005_chat"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "dm_unread",
        sa.Column("player_id", sa.String(length=36), nullable=False),
        sa.Column("peer_id", sa.String(length=36), nullable=False),
        sa.Column("count", sa.Integer(), nullable=False, server_default="0"),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("player_id", "peer_id"),
    )


def downgrade() -> None:
    op.drop_table("dm_unread")
