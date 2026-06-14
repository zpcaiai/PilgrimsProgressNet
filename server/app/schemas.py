"""Pydantic request/response schemas."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field

Difficulty = Literal["standard", "child"]
BoardName = Literal["fastest_run", "fewest_falls", "devout_score"]


# --- Auth ---
class DeviceAuthIn(BaseModel):
    device_id: str = Field(min_length=8, max_length=128)
    display_name: str | None = Field(default=None, max_length=64)


class TokenOut(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    player_id: str
    display_name: str


class RefreshIn(BaseModel):
    refresh_token: str


class RequestEmailCodeIn(BaseModel):
    email: str = Field(max_length=255)
    purpose: Literal["bind", "recover"] = "bind"


class RequestEmailCodeOut(BaseModel):
    sent: bool
    cooldown_sec: int
    dev_code: str | None = None  # only populated in dev (PP_EMAIL_DEV_ECHO)


class BindEmailIn(BaseModel):
    email: str = Field(max_length=255)
    code: str = Field(min_length=4, max_length=8)


class RecoverIn(BaseModel):
    email: str = Field(max_length=255)
    code: str = Field(min_length=4, max_length=8)
    device_id: str = Field(min_length=8, max_length=128)


# --- Cloud saves ---
class SaveIn(BaseModel):
    payload: dict[str, Any]
    version: int = Field(default=0, ge=0)            # client's last known version (optimistic lock)
    device_clock: datetime | None = None


class SaveOut(BaseModel):
    slot_id: str
    version: int
    payload: dict[str, Any]
    updated_at: datetime


class SaveSummary(BaseModel):
    slot_id: str
    version: int
    chapter: str
    updated_at: datetime


# --- Leaderboard ---
class ScoreSubmitIn(BaseModel):
    board: BoardName
    difficulty: Difficulty
    score: int
    meta: dict[str, Any] = Field(default_factory=dict)


class LeaderboardRow(BaseModel):
    rank: int
    player_id: str
    display_name: str
    score: int


class LeaderboardOut(BaseModel):
    board: BoardName
    difficulty: Difficulty
    season: str
    top: list[LeaderboardRow]
    my_rank: int | None = None
    my_score: int | None = None


class SeasonOut(BaseModel):
    season: str
    start: str | None = None
    end: str | None = None


# --- Ghosts / multiplayer presence ---
class TrailIn(BaseModel):
    chapter_id: str = Field(max_length=64)
    kind: Literal["trail", "marker"] = "trail"
    points: list[list[float]] = Field(default_factory=list)
    message: str | None = Field(default=None, max_length=140)


class GhostOut(BaseModel):
    player_id: str
    display_name: str
    chapter_id: str
    kind: str
    points: list[list[float]]
    message: str | None
    created_at: datetime


class PresenceOut(BaseModel):
    chapter_id: str
    online: int


# --- Stats ---
class StatEventIn(BaseModel):
    event: str = Field(max_length=64)
    chapter_id: str | None = Field(default=None, max_length=64)
    difficulty: Difficulty | None = None
    props: dict[str, Any] = Field(default_factory=dict)


class StatBatchIn(BaseModel):
    events: list[StatEventIn]


class ChapterFunnelRow(BaseModel):
    chapter_id: str
    started: int
    completed: int
    completion_rate: float


# --- Rewards / settlement / reviews ---
class RewardOut(BaseModel):
    season: str
    board: str
    difficulty: str
    rank: int
    token: str
    created_at: datetime


class ReviewOut(BaseModel):
    id: str
    player_id: str
    season: str
    board: str
    difficulty: str
    score: int
    status: str
    reason: str
    created_at: datetime


class ProcessReviewsOut(BaseModel):
    processed: int
    approved: int
    rejected: int


class MyReviewOut(BaseModel):
    id: str
    board: str
    difficulty: str
    season: str
    score: int
    status: str
    reason: str
    appeal_note: str
    created_at: datetime


class AppealIn(BaseModel):
    note: str = Field(default="", max_length=280)


class ResolveIn(BaseModel):
    decision: Literal["approve", "reject"]
    note: str = Field(default="", max_length=280)


class AdminLoginIn(BaseModel):
    username: str = Field(max_length=64)
    password: str = Field(max_length=128)


class AdminLoginOut(BaseModel):
    token: str
    expires_in_min: int


class SettleOut(BaseModel):
    season: str
    already_settled: bool
    granted: int
    winners: list[dict] = Field(default_factory=list)
