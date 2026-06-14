"""Cloud saves with optimistic-lock conflict handling."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import current_player
from ..models import CloudSave, Player
from ..schemas import SaveIn, SaveOut, SaveSummary

router = APIRouter(prefix="/saves", tags=["saves"])


def _chapter_of(payload: dict) -> str:
    gs = payload.get("game_state", {}) if isinstance(payload, dict) else {}
    return str(gs.get("current_chapter_id", "")) if isinstance(gs, dict) else ""


@router.get("", response_model=list[SaveSummary])
async def list_saves(
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> list[SaveSummary]:
    result = await session.execute(select(CloudSave).where(CloudSave.player_id == player.id))
    return [
        SaveSummary(
            slot_id=s.slot_id,
            version=s.version,
            chapter=_chapter_of(s.payload),
            updated_at=s.updated_at,
        )
        for s in result.scalars().all()
    ]


@router.get("/{slot_id}", response_model=SaveOut)
async def get_save(
    slot_id: str,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> SaveOut:
    result = await session.execute(
        select(CloudSave).where(CloudSave.player_id == player.id, CloudSave.slot_id == slot_id)
    )
    save = result.scalar_one_or_none()
    if save is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "no cloud save in this slot")
    return SaveOut(slot_id=save.slot_id, version=save.version, payload=save.payload, updated_at=save.updated_at)


@router.put("/{slot_id}", response_model=SaveOut)
async def put_save(
    slot_id: str,
    body: SaveIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> SaveOut:
    """Upload a save. version is the client's last-known version (optimistic lock).
    A 409 means the cloud has a newer save; the client should pull & merge."""
    result = await session.execute(
        select(CloudSave).where(CloudSave.player_id == player.id, CloudSave.slot_id == slot_id)
    )
    save = result.scalar_one_or_none()

    if save is None:
        save = CloudSave(
            player_id=player.id,
            slot_id=slot_id,
            version=1,
            payload=body.payload,
            device_clock=body.device_clock,
        )
        session.add(save)
        await session.flush()
    else:
        if body.version != save.version:
            raise HTTPException(
                status.HTTP_409_CONFLICT,
                detail={"message": "version conflict", "server_version": save.version},
            )
        save.version += 1
        save.payload = body.payload
        save.device_clock = body.device_clock
        session.add(save)
        await session.flush()

    return SaveOut(slot_id=save.slot_id, version=save.version, payload=save.payload, updated_at=save.updated_at)
