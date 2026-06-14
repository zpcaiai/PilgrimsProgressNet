#!/usr/bin/env python3
"""Process the anti-cheat review queue: approve legit scores onto the live
board, reject the rest. Run frequently from cron.

    python scripts/recompute_reviews.py --limit 200

Inside Docker:
    docker compose exec app python scripts/recompute_reviews.py
"""
from __future__ import annotations

import argparse
import asyncio
import json

from app.db import SessionLocal
from app import settlement


async def _run(limit: int) -> None:
    async with SessionLocal() as session:
        res = await settlement.process_reviews(session, limit)
        await session.commit()
    print(json.dumps(res, ensure_ascii=False))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=200)
    asyncio.run(_run(ap.parse_args().limit))


if __name__ == "__main__":
    main()
