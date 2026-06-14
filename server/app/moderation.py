"""Chat moderation: sensitive-word filtering + per-player mute (Redis TTL)."""
from __future__ import annotations

import re
from functools import lru_cache

from . import cache
from .config import get_settings

settings = get_settings()


@lru_cache
def _banned() -> list[str]:
    words: set[str] = {w.strip() for w in settings.banned_words.split(",") if w.strip()}
    if settings.banned_words_file:
        try:
            with open(settings.banned_words_file, encoding="utf-8") as f:
                words.update(line.strip() for line in f if line.strip())
        except OSError:
            pass
    # Longest-first so overlapping words mask fully.
    return sorted(words, key=len, reverse=True)


def filter_text(text: str) -> str:
    """Mask banned words with asterisks (case-insensitive)."""
    out = text
    for w in _banned():
        if not w:
            continue
        out = re.sub(re.escape(w), "*" * len(w), out, flags=re.IGNORECASE)
    return out


# --- Mute (runtime state in Redis; fails open if Redis is down) ---
def _mute_key(player_id: str) -> str:
    return f"mute:{player_id}"


async def mute(player_id: str, minutes: int) -> None:
    try:
        await cache.redis_client.set(_mute_key(player_id), "1", ex=max(1, minutes) * 60)
    except Exception:
        pass


async def unmute(player_id: str) -> None:
    try:
        await cache.redis_client.delete(_mute_key(player_id))
    except Exception:
        pass


async def is_muted(player_id: str) -> bool:
    try:
        return bool(await cache.redis_client.exists(_mute_key(player_id)))
    except Exception:
        return False
