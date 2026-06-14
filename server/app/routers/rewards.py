"""Player-facing rewards earned from season settlements."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import current_player
from ..models import Player, SeasonReward
from ..schemas import RewardOut

router = APIRouter(prefix="/rewards", tags=["rewards"])


def _to_out(r: SeasonReward) -> RewardOut:
    return RewardOut(
        season=r.season, board=r.board, difficulty=r.difficulty,
        rank=r.rank, token=r.token, created_at=r.created_at,
    )


@router.get("", response_model=list[RewardOut])
async def my_rewards(
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> list[RewardOut]:
    result = await session.execute(
        select(SeasonReward).where(SeasonReward.player_id == player.id)
        .order_by(SeasonReward.created_at.desc())
    )
    return [_to_out(r) for r in result.scalars().all()]


@router.get("/unseen", response_model=list[RewardOut])
async def unseen_rewards(
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> list[RewardOut]:
    """Rewards the player hasn't been shown yet (for the login popup)."""
    result = await session.execute(
        select(SeasonReward).where(
            SeasonReward.player_id == player.id, SeasonReward.seen == False  # noqa: E712
        ).order_by(SeasonReward.created_at.desc())
    )
    return [_to_out(r) for r in result.scalars().all()]


@router.post("/seen")
async def mark_seen(
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Acknowledge all of the player's rewards (call after showing the popup)."""
    await session.execute(
        update(SeasonReward).where(
            SeasonReward.player_id == player.id, SeasonReward.seen == False  # noqa: E712
        ).values(seen=True)
    )
    return {"ok": True}
