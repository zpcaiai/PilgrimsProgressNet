"""Async SQLAlchemy engine, session factory, and connection-pool config."""
from __future__ import annotations

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase

from .config import get_settings

settings = get_settings()


class Base(DeclarativeBase):
    """Declarative base for all ORM models."""


# Engine-level connection pool. With multiple app replicas, ensure
# replicas * db_pool_size stays under PostgreSQL max_connections (or front
# with PgBouncer). pool_pre_ping guards against stale connections.
# SQLite (tests/dev) uses StaticPool and rejects queue-pool sizing args, so we
# only pass them for real pooled backends like PostgreSQL. StaticPool keeps a
# single shared connection so an in-memory database isn't recreated empty per
# pooled connection.
_engine_kwargs: dict = {"echo": settings.db_echo, "pool_pre_ping": True}
if settings.database_url.startswith("sqlite"):
    _engine_kwargs["connect_args"] = {"check_same_thread": False}
    if ":memory:" in settings.database_url:
        # In-memory must share one connection or the DB is recreated empty.
        from sqlalchemy.pool import StaticPool

        _engine_kwargs["poolclass"] = StaticPool
    # File-based SQLite uses the default pool: many connections, one shared file.
else:
    _engine_kwargs.update(
        pool_size=settings.db_pool_size,
        max_overflow=settings.db_max_overflow,
        pool_timeout=settings.db_pool_timeout,
    )

engine = create_async_engine(settings.database_url, **_engine_kwargs)

SessionLocal = async_sessionmaker(
    bind=engine,
    expire_on_commit=False,
    autoflush=False,
)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    """FastAPI dependency: yields a session, commits on success, rolls back on error."""
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
