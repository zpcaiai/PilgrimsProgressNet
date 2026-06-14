"""Shared FastAPI dependencies: auth + rate limiting."""
from __future__ import annotations

import jwt
from fastapi import Depends, Header, HTTPException, Request, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from . import cache
from .config import get_settings
from .db import get_session
from .models import Player
from .security import decode_token

settings = get_settings()


async def current_player(
    authorization: str | None = Header(default=None),
    session: AsyncSession = Depends(get_session),
) -> Player:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "missing bearer token")
    token = authorization.split(" ", 1)[1].strip()
    try:
        player_id = decode_token(token, "access")
    except jwt.PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"invalid token: {exc}") from exc

    player = await session.get(Player, player_id)
    if player is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "unknown player")
    return player


async def require_admin(
    x_admin_token: str | None = Header(default=None),
    authorization: str | None = Header(default=None),
) -> None:
    """Gate /admin/* behind EITHER a static X-Admin-Token (cron/scripts) OR a
    Bearer admin-session JWT (web login)."""
    if x_admin_token and x_admin_token == settings.admin_token:
        return
    if authorization and authorization.lower().startswith("bearer "):
        token = authorization.split(" ", 1)[1].strip()
        try:
            decode_token(token, "admin")
            return
        except jwt.PyJWTError:
            pass
    raise HTTPException(status.HTTP_403_FORBIDDEN, "admin auth required")


async def rate_limit(request: Request) -> None:
    """Fixed-window rate limit per client IP. Fails open if Redis is down."""
    client_ip = request.client.host if request.client else "unknown"
    window = int(__import__("time").time()) // 60
    key = f"ratelimit:{client_ip}:{window}"
    try:
        count = await cache.redis_client.incr(key)
        if count == 1:
            await cache.redis_client.expire(key, 60)
        if count > settings.rate_limit_per_min:
            raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, "rate limit exceeded")
    except HTTPException:
        raise
    except Exception:
        return  # fail open
