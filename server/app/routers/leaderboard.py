"""Leaderboards: Redis ZSET for live ranking, PostgreSQL as durable backstop.
Season-aware (current + all-time). Suspicious scores are queued for review and
kept off the live board until the recompute pass approves them."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from .. import boards, cache, scoring
from ..config import get_settings
from ..db import get_session
from ..deps import current_player
from ..models import LeaderboardEntry, Player, ScoreReview
from ..schemas import LeaderboardOut, LeaderboardRow, ScoreSubmitIn, SeasonOut
from ..season import current_season, season_window

router = APIRouter(prefix="/leaderboard", tags=["leaderboard"])
settings = get_settings()


@router.get("/seasons/current", response_model=SeasonOut)
async def seasons_current(player: Player = Depends(current_player)) -> SeasonOut:
    return SeasonOut(**season_window(current_season()))


@router.post("/submit", response_model=LeaderboardOut)
async def submit(
    body: ScoreSubmitIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> LeaderboardOut:
    # Layer 1: hard reject impossible submissions.
    hard = scoring.hard_reject(body.board, body.score, body.meta)
    if hard:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, hard)

    season = current_season()

    # Durable record (history + Redis rebuild source).
    entry = LeaderboardEntry(
        player_id=player.id, season=season, board=body.board,
        difficulty=body.difficulty, score=body.score, meta=body.meta,
    )
    session.add(entry)
    await session.flush()

    # Layer 2: suspicious -> review queue, NOT on the live board yet.
    reason = scoring.suspicion(body.board, body.score, body.meta)
    if reason:
        session.add(ScoreReview(
            entry_id=entry.id, player_id=player.id, season=season,
            board=body.board, difficulty=body.difficulty, score=body.score,
            meta=body.meta, status="pending", reason=reason,
        ))
    else:
        await boards.add_score(season, body.board, body.difficulty, player.id, player.display_name, body.score)

    return await _board_view(body.board, body.difficulty, season, player.id)


@router.get("/{board}", response_model=LeaderboardOut)
async def get_board(
    board: str,
    difficulty: str = Query(default="standard"),
    season: str = Query(default="current", description="'current', 'all', or a season id like '2026-S2'"),
    limit: int = Query(default=20, ge=1, le=100),
    player: Player = Depends(current_player),
) -> LeaderboardOut:
    resolved = current_season() if season == "current" else season
    return await _board_view(board, difficulty, resolved, player.id, limit)


async def _board_view(board: str, difficulty: str, season: str, player_id: str, limit: int = 20) -> LeaderboardOut:
    zkey = boards.zkey(season, board, difficulty)
    nkey = boards.name_key(season, board, difficulty)
    rows: list[LeaderboardRow] = []
    my_rank: int | None = None
    my_score: int | None = None
    try:
        top = await cache.redis_client.zrevrange(zkey, 0, limit - 1, withscores=True)
        ids = [pid for pid, _ in top]
        names = await cache.redis_client.hmget(nkey, ids) if ids else []
        for i, (pid, score) in enumerate(top):
            rows.append(LeaderboardRow(
                rank=i + 1, player_id=pid,
                display_name=names[i] or "朝圣者", score=int(score),
            ))
        rank = await cache.redis_client.zrevrank(zkey, player_id)
        if rank is not None:
            my_rank = rank + 1
            s = await cache.redis_client.zscore(zkey, player_id)
            my_score = int(s) if s is not None else None
    except Exception:
        pass

    return LeaderboardOut(
        board=board,  # type: ignore[arg-type]
        difficulty=difficulty,  # type: ignore[arg-type]
        season=season,
        top=rows,
        my_rank=my_rank,
        my_score=my_score,
    )
