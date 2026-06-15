"""players: self-uploaded avatar_url

Revision ID: 0010_avatar
Revises: 0009_reply
Create Date: 2026-06-15
"""
from alembic import op
import sqlalchemy as sa

revision = "0010_avatar"
down_revision = "0009_reply"
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.add_column("players", sa.Column("avatar_url", sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column("players", "avatar_url")
