"""Player profile: self-uploaded avatars + batch avatar lookup."""
from __future__ import annotations

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import media
from ..db import get_session
from ..deps import current_player
from ..models import Player
from ..schemas import AvatarOut, AvatarUploadIn

router = APIRouter(prefix="/players", tags=["players"])


@router.post("/avatar", response_model=AvatarOut)
async def upload_avatar(
    body: AvatarUploadIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> AvatarOut:
    """Set the current player's avatar (compressed; the thumbnail is used)."""
    _, thumb_url = media.save_image_b64(body.data, body.ext)
    player.avatar_url = thumb_url
    session.add(player)
    return AvatarOut(avatar_url=thumb_url)


@router.get("/avatars")
async def avatars(
    ids: str = Query(default="", description="comma-separated player ids"),
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    """Batch resolve player_id -> avatar_url (for chat/member-list rendering)."""
    id_list = [x for x in ids.split(",") if x][:100]
    if not id_list:
        return {}
    rows = (await session.execute(
        select(Player.id, Player.avatar_url).where(Player.id.in_(id_list))
    )).all()
    return {pid: url for pid, url in rows if url}
