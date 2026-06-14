"""Test configuration: use a temp file-based SQLite DB.

A file (not :memory:) lets the many short-lived connections opened across
WebSocket handlers and HTTP requests all see the same data, which mirrors how
PostgreSQL behaves in production and avoids single-connection contention.
"""
import os
import pathlib
import tempfile

_db = pathlib.Path(tempfile.gettempdir()) / "pilgrim_test.db"
try:
    _db.unlink()
except OSError:
    pass

# Force (not setdefault) so this wins over any per-module setdefault.
os.environ["PP_DATABASE_URL"] = f"sqlite+aiosqlite:///{_db}"
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")

import pytest_asyncio


@pytest_asyncio.fixture(autouse=True)
async def _clean_db():
    """Reset all tables before each test so global-count assertions stay isolated."""
    from app.db import Base, engine
    import app.models  # noqa: F401  (register tables)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield
