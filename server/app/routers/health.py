"""Liveness / readiness / metrics."""
from __future__ import annotations

from fastapi import APIRouter
from sqlalchemy import text

from .. import cache
from ..db import engine

router = APIRouter(tags=["health"])


@router.get("/healthz")
async def healthz() -> dict:
    return {"status": "ok"}


@router.get("/readyz")
async def readyz() -> dict:
    db_ok = False
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
            db_ok = True
    except Exception:
        db_ok = False
    redis_ok = await cache.ping()
    ready = db_ok and redis_ok
    return {"ready": ready, "db": db_ok, "redis": redis_ok}
