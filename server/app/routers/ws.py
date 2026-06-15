"""WebSocket endpoint: real-time presence + multi-channel chat."""
from __future__ import annotations

import time
from datetime import datetime, timezone

import jwt
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect

from .. import chat_store, moderation
from ..config import get_settings
from ..db import SessionLocal
from ..models import Player
from ..realtime import WORLD_KEY, dm_key, manager
from ..security import decode_token

router = APIRouter(tags=["realtime"])
settings = get_settings()

CHAT_MAX_LEN = 200


def _audience_keys(channel: str, scope: str, chapter_id: str) -> list[str]:
    """Room keys that should receive a message/delete for a given scope."""
    if channel == "world":
        return [WORLD_KEY]
    if channel == "dm":
        parts = scope.split(":")  # dm:lo:hi
        if len(parts) == 3:
            return [dm_key(parts[1]), dm_key(parts[2])]
        return []
    if channel == "room":
        return [scope]  # scope is already "room:<id>"
    return [chapter_id]


async def _authenticate(token: str) -> tuple[str, str, str | None] | None:
    try:
        player_id = decode_token(token, "access")
    except jwt.PyJWTError:
        return None
    async with SessionLocal() as session:
        player = await session.get(Player, player_id)
        if player is None:
            return None
        return player.id, player.display_name, player.avatar_url


def _safe_image(url) -> str | None:
    """Only allow image references that point at our own /media/ store."""
    if isinstance(url, str) and url.startswith("/media/") and ".." not in url:
        return url
    return None


@router.websocket("/ws/ghosts/{chapter_id}")
async def ws_ghosts(websocket: WebSocket, chapter_id: str, token: str = Query(default="")):
    auth = await _authenticate(token)
    if auth is None:
        await websocket.close(code=4401)
        return
    player_id, name, avatar = auth

    await manager.connect(chapter_id, websocket, player_id)
    history = await chat_store.recent(chat_store.chapter_scope(chapter_id))
    if history:
        await websocket.send_json({"type": "chat_history", "channel": "chapter", "items": history})
    await manager.publish(chapter_id, {"type": "join", "id": player_id, "name": name})
    joined_rooms: set[str] = set()
    try:
        while True:
            raw = await websocket.receive_json()
            if not isinstance(raw, dict):
                continue
            kind = raw.get("type")
            if kind == "pos":
                await manager.publish(chapter_id, {
                    "type": "peer", "id": player_id, "name": name, "avatar": avatar,
                    "x": float(raw.get("x", 0.0)), "y": float(raw.get("y", 0.0)),
                    "z": float(raw.get("z", 0.0)), "yaw": float(raw.get("yaw", 0.0)),
                })
            elif kind == "chat":
                await _handle_chat(websocket, raw, chapter_id, player_id, name, avatar)
            elif kind == "chat_delete":
                await _handle_delete(websocket, raw, chapter_id, player_id)
            elif kind == "room_join":
                room = str(raw.get("room", "")).strip()[:32]
                if room:
                    key = chat_store.room_scope(room)
                    await manager.join(key, websocket)
                    await manager.add_member(key, player_id, name, avatar or "")
                    joined_rooms.add(room)
                    rname = await chat_store.get_room_name(room)
                    mlist = await manager.members(key)
                    await websocket.send_json({
                        "type": "system",
                        "text": "已加入群聊「%s」（%d 人）" % (rname or room, len(mlist))})
                    await manager.publish(key, {"type": "room_members", "room": room,
                                                "name": rname, "members": mlist})
            elif kind == "room_leave":
                room = str(raw.get("room", "")).strip()[:32]
                if room:
                    key = chat_store.room_scope(room)
                    manager.leave(key, websocket)
                    await manager.remove_member(key, player_id)
                    joined_rooms.discard(room)
                    await manager.publish(key, {"type": "room_members", "room": room,
                                                "members": await manager.members(key)})
            elif kind == "ping":
                await websocket.send_json({"type": "pong", "t": raw.get("t")})
                # Heartbeat keeps room membership fresh; evict stale members and
                # tell the room when someone drops off without a clean leave.
                for room in joined_rooms:
                    key = chat_store.room_scope(room)
                    await manager.touch_member(key, player_id, name, avatar or "")
                    if await manager.sweep(key):
                        await manager.publish(key, {"type": "room_members", "room": room,
                                                    "members": await manager.members(key)})
    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(websocket)
        await manager.publish(chapter_id, {"type": "leave", "id": player_id})
        for room in joined_rooms:
            key = chat_store.room_scope(room)
            await manager.remove_member(key, player_id)
            await manager.publish(key, {"type": "room_members", "room": room,
                                        "members": await manager.members(key)})


async def _handle_chat(websocket: WebSocket, raw: dict, chapter_id: str, player_id: str,
                       name: str, avatar: str | None = None) -> None:
    if await moderation.is_muted(player_id):
        await websocket.send_json({"type": "system", "text": "你已被禁言，暂时无法发言。"})
        return
    text = str(raw.get("text", "")).strip()[:CHAT_MAX_LEN]
    image_url = _safe_image(raw.get("image_url"))
    if not text and not image_url:
        return
    text = moderation.filter_text(text) if text else text
    channel = str(raw.get("channel", "chapter"))
    reply_to = str(raw.get("reply_to", "")) or None
    reply_preview = (str(raw.get("reply_preview", ""))[:120] or None) if reply_to else None
    ts = int(time.time() * 1000)
    base = {"type": "chat", "id": player_id, "name": name, "avatar": avatar, "text": text,
            "image_url": image_url, "ts": ts, "channel": channel,
            "reply_to": reply_to, "reply_preview": reply_preview}

    if channel == "world":
        scope = chat_store.world_scope()
        saved = await chat_store.save(scope, "world", player_id, name, text, image_url, reply_to, reply_preview)
        base["mid"] = saved.id
        await manager.publish(WORLD_KEY, base)
    elif channel == "room":
        room = str(raw.get("room", "")).strip()[:32]
        if not room:
            return
        scope = chat_store.room_scope(room)
        base["room"] = room
        saved = await chat_store.save(scope, "room", player_id, name, text, image_url, reply_to, reply_preview)
        base["mid"] = saved.id
        await manager.publish(scope, base)
    elif channel == "dm":
        to = str(raw.get("to", ""))
        if not to:
            return
        base["to"] = to
        scope = chat_store.dm_scope(player_id, to)
        saved = await chat_store.save(scope, "dm", player_id, name, text, image_url, reply_to, reply_preview)
        base["mid"] = saved.id
        await manager.publish(dm_key(to), base)
        if to != player_id:
            await chat_store.bump_unread(to, player_id)     # red dot for the recipient
            await manager.publish(dm_key(player_id), base)  # echo to sender
    else:
        scope = chat_store.chapter_scope(chapter_id)
        saved = await chat_store.save(scope, "chapter", player_id, name, text, image_url, reply_to, reply_preview)
        base["mid"] = saved.id
        await manager.publish(chapter_id, base)

    # Persist @mentions so the target sees them even if offline (best-effort).
    if text:
        try:
            await chat_store.add_mentions(scope, channel, player_id, name, text)
        except Exception:
            pass


async def _handle_delete(websocket: WebSocket, raw: dict, chapter_id: str, player_id: str) -> None:
    """Recall (delete) one of your own messages within the recall window."""
    mid = str(raw.get("mid", ""))
    if not mid:
        return
    msg = await chat_store.get_message(mid)
    if msg is None:
        return
    if msg.sender_id != player_id:
        await websocket.send_json({"type": "system", "text": "只能撤回自己的消息。"})
        return
    created = msg.created_at
    if created.tzinfo is None:  # SQLite stores naive datetimes
        created = created.replace(tzinfo=timezone.utc)
    age = (datetime.now(timezone.utc) - created).total_seconds()
    if age > settings.chat_recall_seconds:
        await websocket.send_json({"type": "system", "text": "超过可撤回时间。"})
        return
    channel, scope = msg.channel, msg.scope
    await chat_store.delete_message(mid)
    note = {"type": "chat_delete", "mid": mid, "channel": channel}
    for key in _audience_keys(channel, scope, chapter_id):
        await manager.publish(key, note)
