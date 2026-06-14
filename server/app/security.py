"""JWT issue/verify helpers."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

import jwt

from .config import get_settings

settings = get_settings()


def _encode(sub: str, ttl_min: int, scope: str) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": sub,
        "scope": scope,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=ttl_min)).timestamp()),
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def make_access_token(player_id: str) -> str:
    return _encode(player_id, settings.access_token_ttl_min, "access")


def make_refresh_token(player_id: str) -> str:
    return _encode(player_id, settings.refresh_token_ttl_min, "refresh")


def make_admin_token() -> str:
    return _encode("admin", settings.admin_session_ttl_min, "admin")


def decode_token(token: str, expected_scope: str) -> str:
    """Return the player_id (sub). Raises jwt exceptions on failure."""
    data = jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    if data.get("scope") != expected_scope:
        raise jwt.InvalidTokenError("wrong token scope")
    return str(data["sub"])
