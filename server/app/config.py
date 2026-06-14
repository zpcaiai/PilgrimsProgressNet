"""Application settings, loaded from environment / .env."""
from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="PP_", extra="ignore")

    # --- Core ---
    env: str = Field(default="dev")  # dev | prod
    debug: bool = Field(default=True)
    api_prefix: str = Field(default="/api/v1")

    # --- Database (async SQLAlchemy + asyncpg) ---
    database_url: str = Field(
        default="postgresql+asyncpg://pilgrim:pilgrim@localhost:5432/pilgrim"
    )
    db_pool_size: int = Field(default=10)
    db_max_overflow: int = Field(default=20)
    db_pool_timeout: int = Field(default=30)
    db_echo: bool = Field(default=False)

    # --- Redis ---
    redis_url: str = Field(default="redis://localhost:6379/0")

    # --- Auth / JWT ---
    jwt_secret: str = Field(default="change-me-in-prod")
    jwt_algorithm: str = Field(default="HS256")
    access_token_ttl_min: int = Field(default=60 * 24)       # 1 day
    refresh_token_ttl_min: int = Field(default=60 * 24 * 30)  # 30 days

    # --- CORS ---
    cors_origins: str = Field(default="*")  # comma-separated; "*" for dev

    # --- Gameplay / anti-cheat bounds ---
    max_chapters: int = Field(default=16)
    presence_ttl_sec: int = Field(default=60)
    ghosts_per_chapter: int = Field(default=20)
    max_trail_points: int = Field(default=400)
    stats_batch_max: int = Field(default=100)

    # --- Rate limiting (fixed window) ---
    rate_limit_per_min: int = Field(default=120)

    # --- Email verification (bind / recover) ---
    email_code_ttl_sec: int = Field(default=600)      # code valid 10 min
    email_code_cooldown_sec: int = Field(default=60)  # min gap between sends
    email_dev_echo: bool = Field(default=True)        # dev: return code in response (NEVER in prod)
    smtp_host: str = Field(default="")                # empty -> log-only (dev)
    smtp_port: int = Field(default=587)
    smtp_user: str = Field(default="")
    smtp_password: str = Field(default="")
    smtp_from: str = Field(default="no-reply@pilgrim.example.com")
    smtp_tls: bool = Field(default=True)

    # --- Chat: moderation, retention, images ---
    banned_words: str = Field(default="badword,辱骂,垃圾广告")  # comma-separated seed list
    banned_words_file: str = Field(default="")                  # optional path, one word/line
    chat_retention_days: int = Field(default=7)
    chat_history_limit: int = Field(default=50)
    chat_recall_seconds: int = Field(default=120)   # window to recall your own message
    media_dir: str = Field(default="media")
    max_image_bytes: int = Field(default=2 * 1024 * 1024)       # 2 MB

    # --- Seasons (leaderboards) ---
    # Empty -> compute quarterly season id from the current date (e.g. "2026-S2").
    # Set to pin a season, e.g. "2026-LAUNCH".
    season_override: str = Field(default="")

    # --- Admin / anti-cheat ---
    admin_token: str = Field(default="change-me-admin")     # X-Admin-Token (cron/scripts)
    admin_user: str = Field(default="admin")                # web login username
    admin_password: str = Field(default="change-me-admin-pw")  # web login password
    admin_session_ttl_min: int = Field(default=480)         # admin JWT lifetime (8h)
    score_tolerance: int = Field(default=2)              # allowed |submitted - recomputed|
    min_ms_per_chapter: int = Field(default=3000)        # faster than this per chapter = suspect
    devout_score_max: int = Field(default=2200)          # plausible ceiling for devout_score

    @property
    def cors_list(self) -> list[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
