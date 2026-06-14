"""Data statistics: event ingestion + aggregate queries."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import current_player, require_admin
from ..models import Player, StatEvent
from ..schemas import ChapterFunnelRow, StatBatchIn

router = APIRouter(prefix="/stats", tags=["stats"])
settings = get_settings()


@router.post("/events", status_code=status.HTTP_202_ACCEPTED)
async def ingest_events(
    body: StatBatchIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    if len(body.events) > settings.stats_batch_max:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "too many events in one batch")
    for e in body.events:
        session.add(
            StatEvent(
                player_id=player.id,
                event=e.event,
                chapter_id=e.chapter_id,
                difficulty=e.difficulty,
                props=e.props,
            )
        )
    return {"accepted": len(body.events)}


@router.get("/overview", response_model=list[ChapterFunnelRow], dependencies=[Depends(require_admin)])
async def overview(session: AsyncSession = Depends(get_session)) -> list[ChapterFunnelRow]:
    """Chapter funnel: started vs completed per chapter (completion rate).
    Admin-only (X-Admin-Token)."""
    started = dict(
        (await session.execute(
            select(StatEvent.chapter_id, func.count())
            .where(StatEvent.event == "chapter_started", StatEvent.chapter_id.is_not(None))
            .group_by(StatEvent.chapter_id)
        )).all()
    )
    completed = dict(
        (await session.execute(
            select(StatEvent.chapter_id, func.count())
            .where(StatEvent.event == "chapter_completed", StatEvent.chapter_id.is_not(None))
            .group_by(StatEvent.chapter_id)
        )).all()
    )
    rows: list[ChapterFunnelRow] = []
    for chapter_id in sorted(started.keys() | completed.keys()):
        s = int(started.get(chapter_id, 0))
        c = int(completed.get(chapter_id, 0))
        rows.append(
            ChapterFunnelRow(
                chapter_id=chapter_id,
                started=s,
                completed=c,
                completion_rate=round(c / s, 4) if s else 0.0,
            )
        )
    return rows
