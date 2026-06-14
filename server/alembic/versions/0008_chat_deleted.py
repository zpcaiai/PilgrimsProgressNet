"""chat: soft-delete flag on chat_messages (recall placeholder)

Revision ID: 0008_chat_deleted
Revises: 0007_pins_mentions
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0008_chat_deleted"
down_revision = "0007_pins_mentions"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column(
        "chat_messages",
        sa.Column("deleted", sa.Boolean(), nullable=False, server_default=sa.false()),
    )


def downgrade() -> None:
    op.drop_column("chat_messages", "deleted")
