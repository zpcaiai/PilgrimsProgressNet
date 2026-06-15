"""Shared helper: validate + compress a base64 image and write full + thumb."""
from __future__ import annotations

import base64
import binascii
import uuid
from pathlib import Path

from fastapi import HTTPException, status

from . import images
from .config import get_settings

settings = get_settings()
ALLOWED_EXT = {"png", "jpg", "jpeg", "webp", "gif"}


def media_dir() -> Path:
    p = Path(settings.media_dir)
    p.mkdir(parents=True, exist_ok=True)
    return p


def save_image_b64(data_b64: str, ext: str) -> tuple[str, str]:
    """Decode/validate/compress; returns (full_url, thumb_url) under /media/."""
    ext = ext.lower().lstrip(".")
    if ext not in ALLOWED_EXT:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "不支持的图片格式")
    try:
        raw = base64.b64decode(data_b64, validate=True)
    except (binascii.Error, ValueError):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "图片数据无效")
    if len(raw) > settings.max_image_bytes:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "图片过大")
    full_bytes, thumb_bytes, out_ext = images.process_image(raw, ext)
    stem = uuid.uuid4().hex
    d = media_dir()
    (d / f"{stem}.{out_ext}").write_bytes(full_bytes)
    (d / f"{stem}_thumb.{out_ext}").write_bytes(thumb_bytes)
    return f"/media/{stem}.{out_ext}", f"/media/{stem}_thumb.{out_ext}"
