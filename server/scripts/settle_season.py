#!/usr/bin/env python3
"""Settle a season (snapshot top-3, grant reward tokens), or roll over.

Run from cron. Examples:
    # Settle the previous quarter and ensure the new one is open:
    python scripts/settle_season.py --rollover
    # Settle a specific season explicitly:
    python scripts/settle_season.py --season 2026-S1

Inside Docker:
    docker compose exec app python scripts/settle_season.py --rollover

Idempotent: re-running a settled season is a no-op.
"""
from __future__ import annotations

import argparse
import asyncio
import json

from app.db import SessionLocal
from app import settlement


async def _run(args) -> None:
    async with SessionLocal() as session:
        if args.rollover:
            res = await settlement.rollover(session)
        else:
            res = {"settled": await settlement.settle_season(session, args.season)}
        await session.commit()
    print(json.dumps(res, ensure_ascii=False, indent=2, default=str))


def main() -> None:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--season", help="season id to settle, e.g. 2026-S1")
    g.add_argument("--rollover", action="store_true", help="settle the previous quarter")
    asyncio.run(_run(ap.parse_args()))


if __name__ == "__main__":
    main()
