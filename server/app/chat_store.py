"""Durable chat persistence (DB-backed), with N-day retention.

scope keys:
  chapter:<chapter_id>   in-chapter channel
  world                  global channel
  dm:<idA>:<idB>         direct messages (sorted player-id pair)
"""
from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from sqlalchemy import delete, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .db import SessionLocal
from .models import ChatMessage, DmPin, DmUnread, Mention, Player

settings = get_settings()

_MENTION_RE = re.compile(r"@([^\s@:：,，.。!！?？]+)")


def chapter_scope(chapter_id: str) -> str:
    return f"chapter:{chapter_id}"


def world_scope() -> str:
    return "world"


def dm_scope(a: str, b: str) -> str:
    lo, hi = sorted([a, b])
    return f"dm:{lo}:{hi}"


async def save(scope: str, channel: str, sender_id: str, sender_name: str,
               text: str, image_url: str | None) -> ChatMessage:
    async with SessionLocal() as session:
        msg = ChatMessage(scope=scope, channel=channel, sender_id=sender_id,
                          sender_name=sender_name, text=text, image_url=image_url)
        session.add(msg)
        await session.commit()
        await session.refresh(msg)
        return msg


async def recent(scope: str, limit: int | None = None) -> list[dict]:
    """Most-recent messages for a scope, returned oldest-first for display."""
    lim = limit or settings.chat_history_limit
    async with SessionLocal() as session:
        rows = (await session.execute(
            select(ChatMessage).where(ChatMessage.scope == scope)
            .order_by(ChatMessage.created_at.desc()).limit(lim)
        )).scalars().all()
    rows.reverse()
    return [
        {"type": "chat", "mid": m.id, "id": m.sender_id, "name": m.sender_name, "channel": m.channel,
         "text": m.text, "image_url": m.image_url, "deleted": m.deleted,
         "ts": int(m.created_at.timestamp() * 1000)}
        for m in rows
    ]


async def get_message(mid: str) -> ChatMessage | None:
    async with SessionLocal() as session:
        return await session.get(ChatMessage, mid)


async def delete_message(mid: str) -> None:
    """Soft-delete: clear the content but keep a tombstone so a '已撤回'
    placeholder persists in history (purged later by retention)."""
    async with SessionLocal() as session:
        row = await session.get(ChatMessage, mid)
        if row is not None:
            row.deleted = True
            row.text = ""
            row.image_url = None
            session.add(row)
            await session.commit()


async def bump_unread(recipient_id: str, sender_id: str) -> None:
    """Increment the recipient's unread counter for the sender's DM thread."""
    async with SessionLocal() as session:
        row = await session.get(DmUnread, (recipient_id, sender_id))
        if row is None:
            session.add(DmUnread(player_id=recipient_id, peer_id=sender_id, count=1))
        else:
            row.count += 1
            session.add(row)
        await session.commit()


async def mark_read(player_id: str, peer_id: str) -> None:
    async with SessionLocal() as session:
        row = await session.get(DmUnread, (player_id, peer_id))
        if row is not None:
            row.count = 0
            session.add(row)
            await session.commit()


async def peer_read_ts(me: str, peer: str) -> int:
    """When did `peer` last read my DMs (ms)? 0 if they have unseen ones."""
    async with SessionLocal() as session:
        row = await session.get(DmUnread, (peer, me))  # peer's unread-from-me
        if row is not None and row.count == 0 and row.updated_at is not None:
            return int(row.updated_at.timestamp() * 1000)
        return 0


async def unread_threads(player_id: str) -> dict:
    """Return {'total': N, 'threads': [{peer_id, peer_name, count}, ...]}."""
    async with SessionLocal() as session:
        rows = (await session.execute(
            select(DmUnread).where(DmUnread.player_id == player_id, DmUnread.count > 0)
        )).scalars().all()
        threads = []
        total = 0
        for r in rows:
            peer = await session.get(Player, r.peer_id)
            threads.append({"peer_id": r.peer_id,
                            "peer_name": peer.display_name if peer else "朝圣者",
                            "count": r.count})
            total += r.count
    return {"total": total, "threads": threads}


async def dm_threads(player_id: str) -> list[dict]:
    """List the player's DM conversations: peer, last message, unread, pinned."""
    async with SessionLocal() as session:
        rows = (await session.execute(
            select(ChatMessage).where(
                ChatMessage.channel == "dm",
                or_(ChatMessage.scope.like(f"dm:{player_id}:%"),
                    ChatMessage.scope.like(f"dm:%:{player_id}")),
            ).order_by(ChatMessage.created_at.desc())
        )).scalars().all()

        latest: dict[str, ChatMessage] = {}
        for m in rows:
            latest.setdefault(m.scope, m)  # rows are desc -> first is newest

        unread_rows = (await session.execute(
            select(DmUnread).where(DmUnread.player_id == player_id, DmUnread.count > 0)
        )).scalars().all()
        unread = {r.peer_id: r.count for r in unread_rows}

        pin_rows = (await session.execute(
            select(DmPin).where(DmPin.player_id == player_id)
        )).scalars().all()
        pinned = {r.peer_id for r in pin_rows}

        threads = []
        for scope, m in latest.items():
            parts = scope.split(":")  # ['dm', lo, hi]
            peer = parts[2] if len(parts) == 3 and parts[1] == player_id else parts[1]
            peer_p = await session.get(Player, peer)
            preview = m.text if m.text else ("[图片]" if m.image_url else "")
            threads.append({
                "peer_id": peer,
                "peer_name": peer_p.display_name if peer_p else "朝圣者",
                "last_text": preview,
                "last_ts": int(m.created_at.timestamp() * 1000),
                "unread": unread.get(peer, 0),
                "pinned": peer in pinned,
            })
        # Pinned first, then by recency.
        threads.sort(key=lambda t: (t["pinned"], t["last_ts"]), reverse=True)
        return threads


async def set_pin(player_id: str, peer_id: str, pinned: bool) -> None:
    async with SessionLocal() as session:
        row = await session.get(DmPin, (player_id, peer_id))
        if pinned and row is None:
            session.add(DmPin(player_id=player_id, peer_id=peer_id))
        elif not pinned and row is not None:
            await session.delete(row)
        await session.commit()


async def add_mentions(scope: str, channel: str, from_id: str, from_name: str, text: str) -> None:
    """Resolve @display_name tokens and persist a mention for each matched player."""
    tokens = set(_MENTION_RE.findall(text))
    if not tokens:
        return
    async with SessionLocal() as session:
        players = (await session.execute(
            select(Player).where(Player.display_name.in_(tokens))
        )).scalars().all()
        for p in players:
            if p.id == from_id:
                continue
            session.add(Mention(player_id=p.id, from_id=from_id, from_name=from_name,
                                channel=channel, scope=scope, text=text[:200]))
        await session.commit()


async def unseen_mentions(player_id: str) -> list[dict]:
    async with SessionLocal() as session:
        rows = (await session.execute(
            select(Mention).where(Mention.player_id == player_id, Mention.seen == False)  # noqa: E712
            .order_by(Mention.created_at.desc())
        )).scalars().all()
    return [{"from_name": m.from_name, "channel": m.channel, "text": m.text,
             "ts": int(m.created_at.timestamp() * 1000)} for m in rows]


async def mark_mentions_seen(player_id: str) -> None:
    async with SessionLocal() as session:
        await session.execute(
            update(Mention).where(Mention.player_id == player_id, Mention.seen == False)  # noqa: E712
            .values(seen=True)
        )
        await session.commit()


async def purge_expired(session: AsyncSession) -> int:
    """Delete messages older than the retention window. Returns rows removed."""
    cutoff = datetime.now(timezone.utc) - timedelta(days=settings.chat_retention_days)
    result = await session.execute(delete(ChatMessage).where(ChatMessage.created_at < cutoff))
    return result.rowcount or 0
