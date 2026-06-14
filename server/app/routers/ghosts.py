"""Multiplayer 多人同行: asynchronous ghost trails / markers + presence."""
from __future__ import annotations

import time

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import cache
from ..config import get_settings
from ..db import get_session
from ..deps import current_player
from ..models import GhostTrail, Player
from ..schemas import GhostOut, PresenceOut, TrailIn

router = APIRouter(prefix="/ghosts", tags=["ghosts"])
settings = get_settings()


def _presence_key(chapter_id: str) -> str:
    return f"presence:{chapter_id}"


async def _touch_presence(chapter_id: str, player_id: str) -> None:
    """Sorted-set of player_id -> last-seen epoch; expired members pruned on read."""
    try:
        await cache.redis_client.zadd(_presence_key(chapter_id), {player_id: time.time()})
    except Exception:
        pass


@router.post("/trail", response_model=GhostOut)
async def post_trail(
    body: TrailIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> GhostOut:
    points = body.points[: settings.max_trail_points]
    trail = GhostTrail(
        player_id=player.id,
        chapter_id=body.chapter_id,
        kind=body.kind,
        points=points,
        message=body.message,
    )
    session.add(trail)
    await session.flush()
    await _touch_presence(body.chapter_id, player.id)
    return GhostOut(
        player_id=player.id,
        display_name=player.display_name,
        chapter_id=trail.chapter_id,
        kind=trail.kind,
        points=trail.points,
        message=trail.message,
        created_at=trail.created_at,
    )


@router.get("/{chapter_id}", response_model=list[GhostOut])
async def get_ghosts(
    chapter_id: str,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> list[GhostOut]:
    """Recent ghosts from OTHER players in this chapter."""
    await _touch_presence(chapter_id, player.id)
    stmt = (
        select(GhostTrail, Player.display_name)
        .join(Player, Player.id == GhostTrail.player_id)
        .where(GhostTrail.chapter_id == chapter_id, GhostTrail.player_id != player.id)
        .order_by(GhostTrail.created_at.desc())
        .limit(settings.ghosts_per_chapter)
    )
    rows = await session.execute(stmt)
    out: list[GhostOut] = []
    for trail, name in rows.all():
        out.append(
            GhostOut(
                player_id=trail.player_id,
                display_name=name,
                chapter_id=trail.chapter_id,
                kind=trail.kind,
                points=trail.points,
                message=trail.message,
                created_at=trail.created_at,
            )
        )
    return out


@router.get("/presence/{chapter_id}", response_model=PresenceOut)
async def presence(
    chapter_id: str,
    player: Player = Depends(current_player),
) -> PresenceOut:
    await _touch_presence(chapter_id, player.id)
    online = 0
    try:
        cutoff = time.time() - settings.presence_ttl_sec
        await cache.redis_client.zremrangebyscore(_presence_key(chapter_id), 0, cutoff)
        online = await cache.redis_client.zcard(_presence_key(chapter_id))
    except Exception:
        pass
    return PresenceOut(chapter_id=chapter_id, online=online)
