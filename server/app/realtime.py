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

from fastapi import WebSocket

from . import cache

logger = logging.getLogger("pilgrim.realtime")

WORLD_KEY = "__world__"


def _channel(room_key: str) -> str:
    return f"ghostws:{room_key}"


def dm_key(player_id: str) -> str:
    return f"__dm__{player_id}"


class RoomManager:
    def __init__(self) -> None:
        self._rooms: dict[str, set[WebSocket]] = {}
        self._tasks: dict[str, asyncio.Task] = {}
        self._socket_keys: dict[WebSocket, list[str]] = {}

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
