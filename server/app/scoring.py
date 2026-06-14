"""Server-side score validation and recompute (anti-cheat).

Two layers:
  - hard_reject(): impossible submissions are refused at the API (400).
  - suspicion(): plausible-but-doubtful submissions are queued for review and
    kept OFF the live board until recompute() confirms them.

Where a score is deterministically derivable from meta (fastest_run,
fewest_falls), recompute() reproduces it exactly and compares within tolerance.
For composite scores (devout_score) we bound-check instead.
"""
from __future__ import annotations

from .config import get_settings

settings = get_settings()

# Mirrors the client formulas in LeaderboardService.gd.
FASTEST_BASE = 36_000_000
FEWEST_BASE = 1000


def _int(meta: dict, key: str, default: int = 0) -> int:
    try:
        return int(meta.get(key, default))
    except (TypeError, ValueError):
        return default


def derive_score(board: str, meta: dict) -> int | None:
    """Return the score we expect from meta, or None if not derivable."""
    if board == "fastest_run":
        return max(0, FASTEST_BASE - _int(meta, "elapsed_ms"))
    if board == "fewest_falls":
        return max(0, FEWEST_BASE - _int(meta, "falls"))
    return None  # devout_score is composite -> bound-check only


def hard_reject(board: str, score: int, meta: dict) -> str:
    """Return a non-empty reason if the submission is outright impossible."""
    if score < 0:
        return "score is negative"
    if _int(meta, "chapters_completed") > settings.max_chapters:
        return "chapters_completed exceeds max"
    if _int(meta, "elapsed_ms") < 0 or _int(meta, "falls") < 0:
        return "negative meta fields"
    return ""


def suspicion(board: str, score: int, meta: dict) -> str:
    """Return a non-empty reason if the submission is doubtful (-> review queue)."""
    chapters = _int(meta, "chapters_completed")
    elapsed = _int(meta, "elapsed_ms")

    # Impossibly fast for the number of chapters cleared.
    if chapters > 0 and elapsed > 0 and elapsed < chapters * settings.min_ms_per_chapter:
        return f"too fast: {elapsed}ms for {chapters} chapters"

    derived = derive_score(board, meta)
    if derived is not None and abs(score - derived) > settings.score_tolerance:
        return f"score {score} != derived {derived}"

    if board == "devout_score" and score > settings.devout_score_max:
        return f"devout_score {score} above plausible max {settings.devout_score_max}"

    return ""


def recompute_verdict(board: str, score: int, meta: dict) -> tuple[bool, str]:
    """Decide a queued review. Returns (approved, reason).
    Approves when the score is reproducible/within bounds and timing is sane."""
    if hard_reject(board, score, meta):
        return False, hard_reject(board, score, meta)
    reason = suspicion(board, score, meta)
    if reason:
        return False, reason
    return True, "ok"
