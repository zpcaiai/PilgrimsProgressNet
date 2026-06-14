"""Server-side image processing: compress the full image and make a thumbnail.

Falls back to storing the raw bytes if Pillow is missing or decoding fails, so
uploads never hard-fail on an odd input.
"""
from __future__ import annotations

import logging
from io import BytesIO

logger = logging.getLogger("pilgrim.images")

MAX_DIM = 1280     # cap the longest side of the full image
THUMB_DIM = 256    # thumbnail longest side
QUALITY = 85

try:
    from PIL import Image
    _PIL = True
except Exception:  # pragma: no cover
    _PIL = False


def _normalize_ext(fmt: str | None, fallback: str) -> str:
    f = (fmt or fallback or "").lower()
    if f in ("jpeg", "jpg"):
        return "jpg"
    if f == "webp":
        return "webp"
    return "png"


def _encode(img, save_ext: str) -> bytes:
    if save_ext == "jpg" and img.mode in ("RGBA", "P", "LA"):
        img = img.convert("RGB")
    buf = BytesIO()
    if save_ext == "jpg":
        img.save(buf, "JPEG", quality=QUALITY, optimize=True)
    elif save_ext == "webp":
        img.save(buf, "WEBP", quality=QUALITY)
    else:
        img.save(buf, "PNG", optimize=True)
    return buf.getvalue()


def _resized(img, max_dim: int):
    out = img.copy()
    out.thumbnail((max_dim, max_dim))  # in-place, keeps aspect, only shrinks
    return out


def process_image(raw: bytes, ext: str) -> tuple[bytes, bytes, str]:
    """Return (full_bytes, thumb_bytes, out_ext). Best-effort; raw on failure."""
    if not _PIL:
        return raw, raw, ext.lower().lstrip(".") or "png"
    try:
        img = Image.open(BytesIO(raw))
        img.load()
        save_ext = _normalize_ext(img.format, ext)
        full = _encode(_resized(img, MAX_DIM), save_ext)
        thumb = _encode(_resized(img, THUMB_DIM), save_ext)
        return full, thumb, save_ext
    except Exception as exc:
        logger.warning("image processing failed, storing raw: %s", exc)
        clean = ext.lower().lstrip(".") or "png"
        return raw, raw, clean
