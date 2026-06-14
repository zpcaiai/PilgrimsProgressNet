"""ORM models. See docs/ARCHITECTURE_BACKEND.md section 4."""
from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import (
    JSON,
    BigInteger,
    DateTime,
    Index,
    Integer,
    String,
    Text,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

# JSONB on PostgreSQL (GIN-indexable), generic JSON on SQLite (tests/dev).
JSONType = JSONB().with_variant(JSON(), "sqlite")
# UUIDs stored as 36-char strings — portable across PostgreSQL and SQLite.
UUIDType = String(36)


def _uuid() -> str:
    return str(uuid.uuid4())


class Player(Base):
    __tablename__ = "players"

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    device_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(64), default="无名的朝圣者")
    email: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    last_seen_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class CloudSave(Base):
    __tablename__ = "cloud_saves"
    __table_args__ = (UniqueConstraint("player_id", "slot_id", name="uq_save_slot"),)

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)
    slot_id: Mapped[str] = mapped_column(String(32), default="slot_1")
    version: Mapped[int] = mapped_column(Integer, default=1)  # optimistic lock
    payload: Mapped[dict] = mapped_column(JSONType)
    device_clock: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class LeaderboardEntry(Base):
    __tablename__ = "leaderboard_entries"
    __table_args__ = (
        Index("ix_board_diff_score", "board", "difficulty", "score"),
        Index("ix_season_board_diff_score", "season", "board", "difficulty", "score"),
    )

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)
    season: Mapped[str] = mapped_column(String(32), default="all")  # e.g. "2026-S2"
    board: Mapped[str] = mapped_column(String(32))       # fastest_run | fewest_falls | devout_score
    difficulty: Mapped[str] = mapped_column(String(16))  # standard | child
    score: Mapped[int] = mapped_column(BigInteger)       # normalized: higher is better
    meta: Mapped[dict] = mapped_column(JSONType, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class GhostTrail(Base):
    __tablename__ = "ghost_trails"
    __table_args__ = (
        Index("ix_ghost_chapter_created", "chapter_id", "created_at"),
    )

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)
    chapter_id: Mapped[str] = mapped_column(String(64))
    kind: Mapped[str] = mapped_column(String(16), default="trail")  # trail | marker
    points: Mapped[list] = mapped_column(JSONType, default=list)       # [[x,y,z,t], ...]
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ScoreReview(Base):
    """Anti-cheat queue. Suspicious submissions land here and stay OFF the live
    board until a recompute pass approves (or rejects) them."""
    __tablename__ = "score_reviews"
    __table_args__ = (Index("ix_review_status", "status", "created_at"),)

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    entry_id: Mapped[str] = mapped_column(UUIDType, index=True)  # -> leaderboard_entries.id
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)
    season: Mapped[str] = mapped_column(String(32))
    board: Mapped[str] = mapped_column(String(32))
    difficulty: Mapped[str] = mapped_column(String(16))
    score: Mapped[int] = mapped_column(BigInteger)
    meta: Mapped[dict] = mapped_column(JSONType, default=dict)
    status: Mapped[str] = mapped_column(String(16), default="pending")  # pending|approved|rejected|appealed
    reason: Mapped[str] = mapped_column(String(255), default="")
    appeal_note: Mapped[str] = mapped_column(String(280), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class Season(Base):
    """Tracks settlement state of a season."""
    __tablename__ = "seasons"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)  # e.g. "2026-S2"
    status: Mapped[str] = mapped_column(String(16), default="open")  # open|settled
    settled_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class SeasonReward(Base):
    """A token granted to a top-3 finisher when a season is settled."""
    __tablename__ = "season_rewards"
    __table_args__ = (
        Index("ix_reward_player", "player_id"),
        UniqueConstraint("season", "board", "difficulty", "rank", name="uq_reward_slot"),
    )

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)
    season: Mapped[str] = mapped_column(String(32))
    board: Mapped[str] = mapped_column(String(32))
    difficulty: Mapped[str] = mapped_column(String(16))
    rank: Mapped[int] = mapped_column(Integer)
    token: Mapped[str] = mapped_column(String(48))
    seen: Mapped[bool] = mapped_column(default=False)  # shown to player yet?
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class ChatMessage(Base):
    """Durable chat log (retained N days, purged by a cron job).
    scope: 'chapter:<id>' | 'world' | 'dm:<idA>:<idB>' (sorted pair)."""
    __tablename__ = "chat_messages"
    __table_args__ = (Index("ix_chat_scope_created", "scope", "created_at"),)

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    scope: Mapped[str] = mapped_column(String(96))
    channel: Mapped[str] = mapped_column(String(16))   # chapter | world | dm
    sender_id: Mapped[str] = mapped_column(UUIDType, index=True)
    sender_name: Mapped[str] = mapped_column(String(64))
    text: Mapped[str] = mapped_column(Text, default="")
    image_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    deleted: Mapped[bool] = mapped_column(default=False)  # recalled -> show placeholder
    reply_to: Mapped[str | None] = mapped_column(String(36), nullable=True)      # quoted message id
    reply_preview: Mapped[str | None] = mapped_column(String(120), nullable=True)  # quoted snippet
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class DmUnread(Base):
    """Per-(player, peer) unread DM counter; survives offline so the red dot
    shows on next login."""
    __tablename__ = "dm_unread"

    player_id: Mapped[str] = mapped_column(UUIDType, primary_key=True)
    peer_id: Mapped[str] = mapped_column(UUIDType, primary_key=True)
    count: Mapped[int] = mapped_column(Integer, default=0)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )


class DmPin(Base):
    """Pinned DM conversations (sort to the top of the list)."""
    __tablename__ = "dm_pins"

    player_id: Mapped[str] = mapped_column(UUIDType, primary_key=True)
    peer_id: Mapped[str] = mapped_column(UUIDType, primary_key=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class Mention(Base):
    """A persisted @mention so the target sees it even if they were offline."""
    __tablename__ = "mentions"
    __table_args__ = (Index("ix_mention_player_seen", "player_id", "seen"),)

    id: Mapped[str] = mapped_column(UUIDType, primary_key=True, default=_uuid)
    player_id: Mapped[str] = mapped_column(UUIDType, index=True)   # the mentioned player
    from_id: Mapped[str] = mapped_column(UUIDType)
    from_name: Mapped[str] = mapped_column(String(64))
    channel: Mapped[str] = mapped_column(String(16))
    scope: Mapped[str] = mapped_column(String(96))
    text: Mapped[str] = mapped_column(String(220), default="")
    seen: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())


class StatEvent(Base):
    __tablename__ = "stat_events"
    __table_args__ = (
        Index("ix_stat_event_created", "event", "created_at"),
        Index("ix_stat_chapter", "chapter_id"),
    )

    id: Mapped[int] = mapped_column(
        BigInteger().with_variant(Integer, "sqlite"), primary_key=True, autoincrement=True
    )
    player_id: Mapped[str | None] = mapped_column(UUIDType, nullable=True, index=True)
    event: Mapped[str] = mapped_column(String(64))
    chapter_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    difficulty: Mapped[str | None] = mapped_column(String(16), nullable=True)
    props: Mapped[dict] = mapped_column(JSONType, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
