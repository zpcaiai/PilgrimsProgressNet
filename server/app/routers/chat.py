"""Chat image upload + history fetch (HTTP side of the chat feature)."""
from __future__ import annotations

import base64
import binascii
import time
import uuid
from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from ..config import get_settings
from ..deps import current_player
from ..models import Player
from ..realtime import dm_key, manager
from .. import chat_store, images

router = APIRouter(prefix="/chat", tags=["chat"])
settings = get_settings()

ALLOWED_EXT = {"png", "jpg", "jpeg", "webp", "gif"}


class ImageUploadIn(BaseModel):
    data: str = Field(description="base64-encoded image bytes")
    ext: str = Field(default="png", max_length=8)


class ImageUploadOut(BaseModel):
    url: str
    thumb_url: str


class ReadIn(BaseModel):
    peer_id: str


class PinIn(BaseModel):
    peer_id: str
    pinned: bool = True


def _media_dir() -> Path:
    p = Path(settings.media_dir)
    p.mkdir(parents=True, exist_ok=True)
    return p


@router.post("/image", response_model=ImageUploadOut)
async def upload_image(
    body: ImageUploadIn,
    player: Player = Depends(current_player),
) -> ImageUploadOut:
    ext = body.ext.lower().lstrip(".")
    if ext not in ALLOWED_EXT:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "不支持的图片格式")
    try:
        raw = base64.b64decode(body.data, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "图片数据无效")
    if len(raw) > settings.max_image_bytes:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "图片过大")
    # Server-side compress + thumbnail (falls back to the raw bytes on failure).
    full_bytes, thumb_bytes, out_ext = images.process_image(raw, ext)
    stem = uuid.uuid4().hex
    media = _media_dir()
    (media / f"{stem}.{out_ext}").write_bytes(full_bytes)
    (media / f"{stem}_thumb.{out_ext}").write_bytes(thumb_bytes)
    return ImageUploadOut(url=f"/media/{stem}.{out_ext}", thumb_url=f"/media/{stem}_thumb.{out_ext}")


@router.get("/unread")
async def unread(player: Player = Depends(current_player)) -> dict:
    return await chat_store.unread_threads(player.id)


@router.post("/read")
async def read(body: ReadIn, player: Player = Depends(current_player)) -> dict:
    await chat_store.mark_read(player.id, body.peer_id)
    # Tell the other party (if online) that we've read their DMs.
    try:
        await manager.publish(dm_key(body.peer_id),
                              {"type": "read", "reader": player.id, "ts": int(time.time() * 1000)})
    except Exception:
        pass
    return {"ok": True}


@router.get("/read-state")
async def read_state(peer: str, player: Player = Depends(current_player)) -> dict:
    """When the peer last read this player's DMs (ms; 0 if unread)."""
    return {"read_ts": await chat_store.peer_read_ts(player.id, peer)}


@router.get("/threads")
async def threads(player: Player = Depends(current_player)) -> list[dict]:
    """The player's DM conversations (for the conversation-list panel)."""
    return await chat_store.dm_threads(player.id)


@router.post("/pin")
async def pin(body: PinIn, player: Player = Depends(current_player)) -> dict:
    await chat_store.set_pin(player.id, body.peer_id, body.pinned)
    return {"peer_id": body.peer_id, "pinned": body.pinned}


@router.get("/mentions")
async def mentions(player: Player = Depends(current_player)) -> list[dict]:
    """Unseen @mentions for the player (shown on login)."""
    return await chat_store.unseen_mentions(player.id)


@router.post("/mentions/seen")
async def mentions_seen(player: Player = Depends(current_player)) -> dict:
    await chat_store.mark_mentions_seen(player.id)
    return {"ok": True}


@router.get("/history")
async def history(
    scope: str = Query(default="world", description="'world', 'chapter:<id>', or 'dm' with ?to="),
    to: str = Query(default=""),
    chapter_id: str = Query(default=""),
    player: Player = Depends(current_player),
) -> list[dict]:
    if scope == "world":
        key = chat_store.world_scope()
    elif scope == "dm" and to:
        key = chat_store.dm_scope(player.id, to)
    elif scope == "chapter" and chapter_id:
        key = chat_store.chapter_scope(chapter_id)
    else:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "无效的会话范围")
    return await chat_store.recent(key)
