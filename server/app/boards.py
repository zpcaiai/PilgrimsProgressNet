"""Shared leaderboard constants and Redis ZSET helpers."""
from __future__ import annotations

from . import cache
from .season import ALL_TIME

BOARDS = ["fastest_run", "fewest_falls", "devout_score"]
DIFFICULTIES = ["standard", "child"]

REWARD_TOKENS = {1: "crown_of_life", 2: "palm_branch", 3: "pilgrims_staff"}


def zkey(season: str, board: str, difficulty: str) -> str:
    return f"lb:{season}:{board}:{difficulty}"


def name_key(season: str, board: str, difficulty: str) -> str:
    return f"lb:{season}:{board}:{difficulty}:names"


async def add_score(season: str, board: str, difficulty: str, player_id: str, name: str, score: int) -> None:
    """Add a score to both the season board and the all-time board (best-only)."""
    for s in (season, ALL_TIME):
        try:
            await cache.redis_client.zadd(zkey(s, board, difficulty), {player_id: score}, gt=True)
            await cache.redis_client.hset(name_key(s, board, difficulty), player_id, name)
        except Exception:
            pass


async def top_n(season: str, board: str, difficulty: str, n: int = 3) -> list[tuple[str, int]]:
    """Return [(player_id, score), ...] for the top N of a board."""
    try:
        rows = await cache.redis_client.zrevrange(zkey(season, board, difficulty), 0, n - 1, withscores=True)
        return [(pid, int(score)) for pid, score in rows]
    except Exception:
        return []
