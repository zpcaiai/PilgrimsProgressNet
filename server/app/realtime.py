"""Real-time rooms over WebSocket, fanned out across replicas via Redis pub/sub.

A socket joins three logical rooms on connect:
  - its chapter room (presence + chapter chat)
  - the global world room (world chat)
  - its own direct-message room (private chat)

Each room has a Redis channel; every replica subscribes and re-broadcasts to its
local sockets, so players on different replicas still reach each other. If Redis
is down we fall back to local-only broadcast (single replica / dev).
"""
from __future__ import annotations

import asyncio
import json
import logging
import time

from fastapi import WebSocket

from . import cache

logger = logging.getLogger("pilgrim.realtime")

WORLD_KEY = "__world__"
ROOM_MEMBER_TTL = 90  # seconds without a heartbeat before a member is evicted


def _channel(room_key: str) -> str:
    return f"ghostws:{room_key}"


def dm_key(player_id: str) -> str:
    return f"__dm__{player_id}"


class RoomManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}
        self._tasks: dict[str, asyncio.Task] = {}
        self._socket_keys: dict[WebSocket, list[str]] = {}
        # Local fallback: room_key -> {player_id: {"name": str, "ts": float}}.
        self._room_members: dict[str, dict[str, dict]] = {}

    @staticmethod
    def _zkey(room_key: str) -> str:
        return f"memberz:{room_key}"   # ZSET: member=player_id, score=last_active

    @staticmethod
    def _nkey(room_key: str) -> str:
        return f"membern:{room_key}"   # HASH: player_id -> display_name

    @staticmethod
    def _akey(room_key: str) -> str:
        return f"membera:{room_key}"   # HASH: player_id -> avatar_url

    async def add_member(self, room_key: str, player_id: str, name: str, avatar: str = "") -> None:
        await self.touch_member(room_key, player_id, name, avatar)

    async def touch_member(self, room_key: str, player_id: str, name: str = "", avatar: str = "") -> None:
        """Refresh a member's last-active time (join + heartbeat). Cross-replica
        via Redis ZSET; local dict as fallback."""
        now = time.time()
        local = self._room_members.setdefault(room_key, {}).setdefault(
            player_id, {"name": name, "avatar": avatar, "ts": now})
        local["ts"] = now
        if name:
            local["name"] = name
        if avatar:
            local["avatar"] = avatar
        try:
            await cache.redis_client.zadd(self._zkey(room_key), {player_id: now})
            await cache.redis_client.expire(self._zkey(room_key), 6 * 3600)
            if name:
                await cache.redis_client.hset(self._nkey(room_key), player_id, name)
                await cache.redis_client.expire(self._nkey(room_key), 6 * 3600)
            if avatar:
                await cache.redis_client.hset(self._akey(room_key), player_id, avatar)
                await cache.redis_client.expire(self._akey(room_key), 6 * 3600)
        except Exception:
            pass

    async def remove_member(self, room_key: str, player_id: str) -> None:
        members = self._room_members.get(room_key)
        if members is not None:
            members.pop(player_id, None)
            if not members:
                self._room_members.pop(room_key, None)
        try:
            await cache.redis_client.zrem(self._zkey(room_key), player_id)
            await cache.redis_client.hdel(self._nkey(room_key), player_id)
            await cache.redis_client.hdel(self._akey(room_key), player_id)
        except Exception:
            pass

    def _local_prune(self, room_key: str) -> int:
        cutoff = time.time() - ROOM_MEMBER_TTL
        members = self._room_members.get(room_key, {})
        stale = [pid for pid, v in members.items() if v.get("ts", 0) < cutoff]
        for pid in stale:
            members.pop(pid, None)
        return len(stale)

    async def sweep(self, room_key: str) -> bool:
        """Evict members with no recent heartbeat. Returns True if any removed."""
        cutoff = time.time() - ROOM_MEMBER_TTL
        try:
            removed = await cache.redis_client.zremrangebyscore(self._zkey(room_key), 0, cutoff)
            self._local_prune(room_key)
            return bool(removed)
        except Exception:
            return self._local_prune(room_key) > 0

    async def members(self, room_key: str) -> list[dict]:
        """Members sorted most-recently-active first. Cross-replica via Redis ZSET;
        local fallback when Redis is unavailable."""
        try:
            await cache.redis_client.zremrangebyscore(self._zkey(room_key), 0, time.time() - ROOM_MEMBER_TTL)
            ids = await cache.redis_client.zrevrange(self._zkey(room_key), 0, -1)
            if ids:
                names = await cache.redis_client.hmget(self._nkey(room_key), ids)
                avatars = await cache.redis_client.hmget(self._akey(room_key), ids)
                return [{"id": pid, "name": names[i] or "朝圣者", "avatar": avatars[i] or ""}
                        for i, pid in enumerate(ids)]
            # No Redis members; if local has some, fall through to local.
            if not self._room_members.get(room_key):
                return []
        except Exception:
            pass
        # Local fallback: recency-sorted.
        self._local_prune(room_key)
        items = sorted(self._room_members.get(room_key, {}).items(),
                       key=lambda kv: kv[1].get("ts", 0), reverse=True)
        return [{"id": pid, "name": v.get("name", "朝圣者"), "avatar": v.get("avatar", "")} for pid, v in items]

    async def connect(self, chapter_id: str, ws: WebSocket, player_id: str) -> None:
        await ws.accept()
        keys = [chapter_id, WORLD_KEY, dm_key(player_id)]
        self._socket_keys[ws] = keys
        for k in keys:
            self._rooms.setdefault(k, set()).add(ws)
            await self._ensure_subscriber(k)

    async def join(self, room_key: str, ws: WebSocket) -> None:
        """Dynamically add a socket to an extra room (e.g. an ad-hoc group)."""
        keys = self._socket_keys.setdefault(ws, [])
        if room_key not in keys:
            keys.append(room_key)
        self._rooms.setdefault(room_key, set()).add(ws)
        await self._ensure_subscriber(room_key)

    def leave(self, room_key: str, ws: WebSocket) -> None:
        keys = self._socket_keys.get(ws, [])
        if room_key in keys:
            keys.remove(room_key)
        room = self._rooms.get(room_key)
        if room is not None:
            room.discard(ws)
            if not room:
                self._rooms.pop(room_key, None)
                task = self._tasks.pop(room_key, None)
                if task:
                    task.cancel()

    def disconnect(self, ws: WebSocket) -> None:
        for k in self._socket_keys.pop(ws, []):
            room = self._rooms.get(k)
            if room is None:
                continue
            room.discard(ws)
            if not room:
                self._rooms.pop(k, None)
                task = self._tasks.pop(k, None)
                if task:
                    task.cancel()

    def room_size(self, room_key: str) -> int:
        return len(self._rooms.get(room_key, ()))

    async def publish(self, room_key: str, message: dict) -> None:
        """Broadcast to a room across replicas (or locally if Redis is down)."""
        data = json.dumps(message)
        try:
            await cache.redis_client.publish(_channel(room_key), data)
        except Exception:
            await self._local_broadcast(room_key, data)

    async def _ensure_subscriber(self, room_key: str) -> None:
        if room_key in self._tasks:
            return
        try:
            await cache.redis_client.ping()
        except Exception:
            return  # no Redis -> local-only; publish() delivers directly
        self._tasks[room_key] = asyncio.create_task(self._subscribe(room_key))

    async def _subscribe(self, room_key: str) -> None:
        pubsub = cache.redis_client.pubsub()
        try:
            await pubsub.subscribe(_channel(room_key))
            async for msg in pubsub.listen():
                if msg.get("type") == "message":
                    await self._local_broadcast(room_key, msg["data"])
        except asyncio.CancelledError:
            pass
        except Exception as exc:  # pragma: no cover
            logger.warning("pubsub subscriber for %s stopped: %s", room_key, exc)
        finally:
            try:
                await pubsub.unsubscribe(_channel(room_key))
                await pubsub.aclose()
            except Exception:
                pass

    async def _local_broadcast(self, room_key: str, data: str) -> None:
        for ws in list(self._rooms.get(room_key, ())):
            try:
                await ws.send_text(data)
            except Exception:
                self.disconnect(ws)


manager = RoomManager()
