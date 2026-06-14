"""Season identity for leaderboards.

A "season" is a competitive window. By default seasons are quarterly and the id
is derived from the current date (e.g. "2026-S2" for Apr-Jun). Override via
PP_SEASON_OVERRIDE to pin a custom season. The special id "all" is the
all-time board (every submission also lands there).
"""
from __future__ import annotations

from datetime import date, datetime, timezone

from .config import get_settings

ALL_TIME = "all"
settings = get_settings()


def quarter_of(d: date) -> int:
    return (d.month - 1) // 3 + 1


def season_id_for(d: date) -> str:
    return f"{d.year}-S{quarter_of(d)}"


def current_season() -> str:
    if settings.season_override.strip():
        return settings.season_override.strip()
    return season_id_for(datetime.now(timezone.utc).date())


def season_window(season: str) -> dict:
    """Return {season, start, end} for a quarterly id like '2026-S2'.
    For overrides / 'all', returns nulls for the window."""
    try:
        year_str, q_str = season.split("-S")
        year = int(year_str)
        q = int(q_str)
        start_month = (q - 1) * 3 + 1
        end_month = start_month + 3
        start = date(year, start_month, 1)
        end = date(year + (1 if end_month > 12 else 0), (end_month - 1) % 12 + 1, 1)
        return {"season": season, "start": start.isoformat(), "end": end.isoformat()}
    except Exception:
        return {"season": season, "start": None, "end": None}
