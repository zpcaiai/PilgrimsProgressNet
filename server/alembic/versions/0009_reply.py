"""chat: quote-reply fields on chat_messages

Revision ID: 0009_reply
Revises: 0008_chat_deleted
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0009_reply"
down_revision = "0008_chat_deleted"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("chat_messages", sa.Column("reply_to", sa.String(length=36), nullable=True))
    op.add_column("chat_messages", sa.Column("reply_preview", sa.String(length=120), nullable=True))


def downgrade() -> None:
    op.drop_column("chat_messages", "reply_preview")
    op.drop_column("chat_messages", "reply_to")
