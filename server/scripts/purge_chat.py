#!/usr/bin/env python3
"""Delete chat messages and uploaded images older than the retention window.

Run daily from cron:
    python scripts/purge_chat.py
    docker compose exec app python scripts/purge_chat.py

Retention is PP_CHAT_RETENTION_DAYS (default 7). Idempotent.
"""
from __future__ import annotations

import asyncio
import time
from pathlib import Path

from app.config import get_settings
from app.db import SessionLocal
from app import chat_store

settings = get_settings()


def _purge_images() -> int:
    media = Path(settings.media_dir)
    if not media.is_dir():
        return 0
    cutoff = time.time() - settings.chat_retention_days * 86400
    removed = 0
    for f in media.iterdir():
        try:
            if f.is_file() and f.stat().st_mtime < cutoff:
                f.unlink()
                removed += 1
        except OSError:
            pass
    return removed


async def _purge_messages() -> int:
    async with SessionLocal() as session:
        n = await chat_store.purge_expired(session)
        await session.commit()
        return n


def main() -> None:
    msgs = asyncio.run(_purge_messages())
    imgs = _purge_images()
    print(f"purged {msgs} chat messages and {imgs} image files "
          f"older than {settings.chat_retention_days} days")


if __name__ == "__main__":
    main()
