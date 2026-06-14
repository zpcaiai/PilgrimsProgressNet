"""Player-facing score reviews: see your flagged scores and appeal rejections."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import current_player
from ..models import Player, ScoreReview
from ..schemas import AppealIn, MyReviewOut

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.get("/mine", response_model=list[MyReviewOut])
async def my_reviews(
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> list[MyReviewOut]:
    result = await session.execute(
        select(ScoreReview).where(ScoreReview.player_id == player.id)
        .order_by(ScoreReview.created_at.desc())
    )
    return [
        MyReviewOut(
            id=r.id, board=r.board, difficulty=r.difficulty, season=r.season,
            score=r.score, status=r.status, reason=r.reason,
            appeal_note=r.appeal_note, created_at=r.created_at,
        )
        for r in result.scalars().all()
    ]


@router.post("/{review_id}/appeal", response_model=MyReviewOut)
async def appeal(
    review_id: str,
    body: AppealIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> MyReviewOut:
    """Appeal a rejected score. Moves it to 'appealed' for human review."""
    review = await session.get(ScoreReview, review_id)
    if review is None or review.player_id != player.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "review not found")
    if review.status != "rejected":
        raise HTTPException(status.HTTP_409_CONFLICT, "只有被拒绝的成绩可以申诉")
    review.status = "appealed"
    review.appeal_note = body.note
    review.resolved_at = None
    session.add(review)
    return MyReviewOut(
        id=review.id, board=review.board, difficulty=review.difficulty, season=review.season,
        score=review.score, status=review.status, reason=review.reason,
        appeal_note=review.appeal_note, created_at=review.created_at,
    )
