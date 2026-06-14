"""chat: durable chat_messages log (retained N days)

Revision ID: 0005_chat
Revises: 0004_appeals_seen
Create Date: 2026-06-14
"""
from alembic import op
import sqlalchemy as sa

revision = "0005_chat"
down_revision = "0004_appeals_seen"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "chat_messages",
        sa.Column("id", sa.String(length=36), nullable=False),
        sa.Column("scope", sa.String(length=96), nullable=False),
        sa.Column("channel", sa.String(length=16), nullable=False),
        sa.Column("sender_id", sa.String(length=36), nullable=False),
        sa.Column("sender_name", sa.String(length=64), nullable=False),
        sa.Column("text", sa.Text(), nullable=False),
        sa.Column("image_url", sa.String(length=255), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_chat_messages_sender_id", "chat_messages", ["sender_id"])
    op.create_index("ix_chat_scope_created", "chat_messages", ["scope", "created_at"])


def downgrade() -> None:
    op.drop_index("ix_chat_scope_created", table_name="chat_messages")
    op.drop_table("chat_messages")
