"""Redis client (leaderboards, presence, rate limiting, hot caches)."""
from __future__ import annotations

import redis.asyncio as redis

from .config import get_settings

settings = get_settings()

# decode_responses=True -> str in/out instead of bytes.
redis_client: redis.Redis = redis.from_url(
    settings.redis_url, encoding="utf-8", decode_responses=True
)


async def ping() -> bool:
    try:
        return bool(await redis_client.ping())
    except Exception:
        return False


async def close() -> None:
    await redis_client.aclose()
