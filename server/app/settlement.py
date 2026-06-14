"""Season settlement and anti-cheat review processing (service layer).

Both are idempotent and safe to run repeatedly (e.g. from cron).
"""
from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from . import boards, scoring
from .models import LeaderboardEntry, Player, ScoreReview, Season, SeasonReward
from .season import current_season, season_id_for
from datetime import date


# --------------------------------------------------------------------------
# Anti-cheat: process the review queue
# --------------------------------------------------------------------------
async def process_reviews(session: AsyncSession, limit: int = 100) -> dict:
    """Recompute pending reviews. Approved ones are added to the live boards;
    rejected ones stay off. Returns counts."""
    result = await session.execute(
        select(ScoreReview).where(ScoreReview.status == "pending")
        .order_by(ScoreReview.created_at).limit(limit)
    )
    pending = result.scalars().all()
    approved = rejected = 0
    for r in pending:
        ok, reason = scoring.recompute_verdict(r.board, r.score, r.meta)
        r.status = "approved" if ok else "rejected"
        r.reason = reason
        r.resolved_at = datetime.now(timezone.utc)
        session.add(r)
        if ok:
            name = await _player_name(session, r.player_id)
            await boards.add_score(r.season, r.board, r.difficulty, r.player_id, name, r.score)
            approved += 1
        else:
            rejected += 1
    return {"processed": len(pending), "approved": approved, "rejected": rejected}


async def _player_name(session: AsyncSession, player_id: str) -> str:
    p = await session.get(Player, player_id)
    return p.display_name if p else "朝圣者"


async def resolve_review(session: AsyncSession, review: ScoreReview, approve: bool, note: str = "") -> None:
    """Manual resolution of an (appealed) review. Approve -> add to live board."""
    review.status = "approved" if approve else "rejected"
    if note:
        review.reason = f"{review.reason} | 人工: {note}".strip(" |")
    review.resolved_at = datetime.now(timezone.utc)
    session.add(review)
    if approve:
        name = await _player_name(session, review.player_id)
        await boards.add_score(review.season, review.board, review.difficulty, review.player_id, name, review.score)


# --------------------------------------------------------------------------
# Season settlement: snapshot top-3, grant reward tokens, mark settled
# --------------------------------------------------------------------------
async def settle_season(session: AsyncSession, season: str) -> dict:
    """Idempotent. Snapshots the top-3 of every board/difficulty and grants a
    reward token to each finisher, then marks the season settled."""
    existing = await session.get(Season, season)
    if existing is not None and existing.status == "settled":
        return {"season": season, "already_settled": True, "granted": 0}

    granted = 0
    winners: list[dict] = []
    for board in boards.BOARDS:
        for diff in boards.DIFFICULTIES:
            top = await boards.top_n(season, board, diff, 3)
            for idx, (player_id, score) in enumerate(top):
                rank = idx + 1
                token = boards.REWARD_TOKENS.get(rank, "pilgrims_staff")
                # Skip if this exact reward slot was already granted (idempotency).
                dup = await session.execute(
                    select(SeasonReward).where(
                        SeasonReward.season == season,
                        SeasonReward.board == board,
                        SeasonReward.difficulty == diff,
                        SeasonReward.rank == rank,
                    )
                )
                if dup.scalar_one_or_none() is not None:
                    continue
                session.add(SeasonReward(
                    player_id=player_id, season=season, board=board,
                    difficulty=diff, rank=rank, token=token,
                ))
                granted += 1
                winners.append({"player_id": player_id, "board": board, "difficulty": diff,
                                "rank": rank, "token": token, "score": score})

    if existing is None:
        session.add(Season(id=season, status="settled", settled_at=datetime.now(timezone.utc)))
    else:
        existing.status = "settled"
        existing.settled_at = datetime.now(timezone.utc)
        session.add(existing)

    return {"season": season, "already_settled": False, "granted": granted, "winners": winners}


def previous_season(today: date | None = None) -> str:
    """The quarterly season immediately before the current one."""
    d = today or datetime.now(timezone.utc).date()
    q = (d.month - 1) // 3 + 1
    if q == 1:
        return f"{d.year - 1}-S4"
    return f"{d.year}-S{q - 1}"


async def rollover(session: AsyncSession) -> dict:
    """Settle the previous quarter's season (if not yet settled). The new season
    opens automatically because the active id is date-derived."""
    prev = previous_season()
    settle = await settle_season(session, prev)
    # Ensure the current season has an 'open' row for visibility.
    cur = current_season()
    if await session.get(Season, cur) is None:
        session.add(Season(id=cur, status="open"))
    return {"settled": settle, "current_open": cur}
