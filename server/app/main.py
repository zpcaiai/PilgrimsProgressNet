"""FastAPI application entrypoint."""
from __future__ import annotations

import logging
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import Depends, FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from . import cache, metrics
from .config import get_settings
from .db import Base, engine
from .deps import rate_limit
from .routers import admin, auth, chat, ghosts, health, leaderboard, reviews, rewards, saves, stats, ws

settings = get_settings()
logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
logger = logging.getLogger("pilgrim")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Dev convenience: auto-create tables. In production use Alembic migrations.
    if settings.env == "dev":
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
    logger.info("Pilgrim backend started (env=%s)", settings.env)
    yield
    # For SQLite (dev/tests) the StaticPool holds the single in-memory DB; keep
    # it so repeated app contexts don't race teardown. Real pools (Postgres)
    # should be disposed cleanly.
    if not settings.database_url.startswith("sqlite"):
        await engine.dispose()
    await cache.close()


app = FastAPI(title="Pilgrim's Progress Online API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def request_id_mw(request: Request, call_next):
    rid = request.headers.get("X-Request-Id") or uuid.uuid4().hex[:12]
    response = await call_next(request)
    response.headers["X-Request-Id"] = rid
    return response


# Prometheus metrics middleware + scrape endpoint.
app.middleware("http")(metrics.metrics_middleware)
app.add_api_route("/metrics", metrics.metrics_endpoint, include_in_schema=False)


# Health (no prefix, no rate limit) for probes.
app.include_router(health.router)

# Versioned API, rate-limited.
api_deps = [Depends(rate_limit)]
app.include_router(auth.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(saves.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(leaderboard.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(ghosts.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(stats.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(rewards.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(reviews.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(chat.router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(admin.login_router, prefix=settings.api_prefix, dependencies=api_deps)
app.include_router(admin.router, prefix=settings.api_prefix, dependencies=api_deps)
# WebSocket router: no HTTP rate-limit dependency (those use Request).
app.include_router(ws.router, prefix=settings.api_prefix)


@app.get("/")
async def root() -> dict:
    return {"service": "pilgrim-online", "version": app.version, "docs": "/docs", "admin_ui": "/admin-ui/"}


# Same-origin static admin dashboard (no CORS needed). Served at /admin-ui/.
_admin_dir = Path(__file__).resolve().parent.parent / "admin_web"
if _admin_dir.is_dir():
    app.mount("/admin-ui", StaticFiles(directory=str(_admin_dir), html=True), name="admin-ui")

# Uploaded chat images, served at /media/.
_media_dir = Path(settings.media_dir)
_media_dir.mkdir(parents=True, exist_ok=True)
app.mount("/media", StaticFiles(directory=str(_media_dir)), name="media")
