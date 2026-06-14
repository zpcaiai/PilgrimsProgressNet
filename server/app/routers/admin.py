"""Privileged operations: anti-cheat review processing and season settlement.
All endpoints require the X-Admin-Token header (PP_ADMIN_TOKEN)."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

import hmac

from fastapi import HTTPException, status

from .. import moderation, settlement
from ..config import get_settings
from ..db import get_session
from ..deps import require_admin
from ..models import ScoreReview
from ..schemas import (
    AdminLoginIn,
    AdminLoginOut,
    ProcessReviewsOut,
    ResolveIn,
    ReviewOut,
    SettleOut,
)
from ..security import make_admin_token

settings = get_settings()

# Login is NOT behind require_admin (it issues the admin session).
login_router = APIRouter(prefix="/admin", tags=["admin"])


@login_router.post("/login", response_model=AdminLoginOut)
async def admin_login(body: AdminLoginIn) -> AdminLoginOut:
    ok_user = hmac.compare_digest(body.username, settings.admin_user)
    ok_pw = hmac.compare_digest(body.password, settings.admin_password)
    if not (ok_user and ok_pw):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "用户名或密码错误")
    return AdminLoginOut(token=make_admin_token(), expires_in_min=settings.admin_session_ttl_min)


router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_admin)])


@router.get("/reviews", response_model=list[ReviewOut])
async def list_reviews(
    status_filter: str = Query(default="pending", alias="status"),
    limit: int = Query(default=100, ge=1, le=500),
    session: AsyncSession = Depends(get_session),
) -> list[ReviewOut]:
    result = await session.execute(
        select(ScoreReview).where(ScoreReview.status == status_filter)
        .order_by(ScoreReview.created_at).limit(limit)
    )
    return [
        ReviewOut(
            id=r.id, player_id=r.player_id, season=r.season, board=r.board,
            difficulty=r.difficulty, score=r.score, status=r.status,
            reason=r.reason, created_at=r.created_at,
        )
        for r in result.scalars().all()
    ]


@router.post("/reviews/recompute", response_model=ProcessReviewsOut)
async def recompute_reviews(
    limit: int = Query(default=100, ge=1, le=1000),
    session: AsyncSession = Depends(get_session),
) -> ProcessReviewsOut:
    """Process the pending review queue: approved scores join the live board,
    rejected ones are dropped."""
    res = await settlement.process_reviews(session, limit)
    return ProcessReviewsOut(**res)


@router.post("/reviews/{review_id}/resolve", response_model=ReviewOut)
async def resolve_review(
    review_id: str,
    body: ResolveIn,
    session: AsyncSession = Depends(get_session),
) -> ReviewOut:
    """Manually resolve a review (typically an appealed one)."""
    review = await session.get(ScoreReview, review_id)
    if review is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "review not found")
    await settlement.resolve_review(session, review, body.decision == "approve", body.note)
    return ReviewOut(
        id=review.id, player_id=review.player_id, season=review.season, board=review.board,
        difficulty=review.difficulty, score=review.score, status=review.status,
        reason=review.reason, created_at=review.created_at,
    )


@router.post("/mute/{player_id}")
async def mute_player(player_id: str, minutes: int = 60) -> dict:
    await moderation.mute(player_id, minutes)
    return {"muted": player_id, "minutes": minutes}


@router.delete("/mute/{player_id}")
async def unmute_player(player_id: str) -> dict:
    await moderation.unmute(player_id)
    return {"unmuted": player_id}


@router.post("/seasons/{season}/settle", response_model=SettleOut)
async def settle(season: str, session: AsyncSession = Depends(get_session)) -> SettleOut:
    res = await settlement.settle_season(session, season)
    return SettleOut(
        season=res["season"], already_settled=res["already_settled"],
        granted=res.get("granted", 0), winners=res.get("winners", []),
    )


@router.post("/seasons/rollover", response_model=SettleOut)
async def rollover(session: AsyncSession = Depends(get_session)) -> SettleOut:
    """Settle the previous quarter's season; the new one opens automatically."""
    res = await settlement.rollover(session)
    s = res["settled"]
    return SettleOut(
        season=s["season"], already_settled=s["already_settled"],
        granted=s.get("granted", 0), winners=s.get("winners", []),
    )
