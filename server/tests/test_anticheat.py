"""Anti-cheat (review queue) + season settlement tests.

Runs against in-memory SQLite; Redis calls fail open (so the live board is
empty, but the DB-backed review queue and settlement bookkeeping still work).
"""
from __future__ import annotations

import os

os.environ.setdefault("PP_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")

import pytest
from httpx import ASGITransport, AsyncClient

from app import scoring
from app.main import app

ADMIN = {"X-Admin-Token": "change-me-admin"}
LEGIT_META = {"elapsed_ms": 600000, "chapters_completed": 16}
LEGIT_SCORE = 36_000_000 - 600000  # exactly the derived fastest_run score


def test_scoring_pure_functions():
    # hard rejects
    assert scoring.hard_reject("fastest_run", -1, {})
    assert scoring.hard_reject("fewest_falls", 5, {"chapters_completed": 99})
    # a faithfully reported run is clean
    assert scoring.suspicion("fastest_run", LEGIT_SCORE, LEGIT_META) == ""
    # a tampered score is flagged
    assert scoring.suspicion("fastest_run", LEGIT_SCORE + 500, LEGIT_META) != ""
    # impossibly fast is flagged
    assert scoring.suspicion("fastest_run", 0, {"elapsed_ms": 1000, "chapters_completed": 16}) != ""
    # verdicts
    assert scoring.recompute_verdict("fastest_run", LEGIT_SCORE, LEGIT_META)[0] is True
    assert scoring.recompute_verdict("fastest_run", LEGIT_SCORE + 500, LEGIT_META)[0] is False


@pytest.mark.asyncio
async def test_review_queue_flow():
    transport = ASGITransport(app=app)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            r = await client.post("/api/v1/auth/device", json={"device_id": "cheater-0001"})
            h = {"Authorization": f"Bearer {r.json()['access_token']}"}

            # legit submission -> no review
            r = await client.post("/api/v1/leaderboard/submit", headers=h, json={
                "board": "fastest_run", "difficulty": "standard",
                "score": LEGIT_SCORE, "meta": LEGIT_META})
            assert r.status_code == 200

            # tampered submission -> queued for review
            r = await client.post("/api/v1/leaderboard/submit", headers=h, json={
                "board": "fastest_run", "difficulty": "standard",
                "score": LEGIT_SCORE + 9999, "meta": LEGIT_META})
            assert r.status_code == 200

            # admin sees exactly one pending review
            r = await client.get("/api/v1/admin/reviews?status=pending", headers=ADMIN)
            assert r.status_code == 200, r.text
            assert len(r.json()) == 1
            assert r.json()[0]["reason"]

            # admin without token is forbidden
            r = await client.get("/api/v1/admin/reviews")
            assert r.status_code == 403

            # recompute resolves it as rejected
            r = await client.post("/api/v1/admin/reviews/recompute", headers=ADMIN)
            assert r.status_code == 200, r.text
            body = r.json()
            assert body["processed"] == 1 and body["rejected"] == 1

            # queue is now empty
            r = await client.get("/api/v1/admin/reviews?status=pending", headers=ADMIN)
            assert r.json() == []

            # the player sees their rejected score and appeals it
            r = await client.get("/api/v1/reviews/mine", headers=h)
            assert r.status_code == 200
            rejected = [x for x in r.json() if x["status"] == "rejected"]
            assert len(rejected) == 1
            review_id = rejected[0]["id"]
            r = await client.post(f"/api/v1/reviews/{review_id}/appeal", headers=h,
                                  json={"note": "我确实是正常通关的"})
            assert r.status_code == 200, r.text
            assert r.json()["status"] == "appealed"

            # admin sees the appeal and manually approves it
            r = await client.get("/api/v1/admin/reviews?status=appealed", headers=ADMIN)
            assert len(r.json()) == 1
            r = await client.post(f"/api/v1/admin/reviews/{review_id}/resolve", headers=ADMIN,
                                  json={"decision": "approve", "note": "复核通过"})
            assert r.status_code == 200, r.text
            assert r.json()["status"] == "approved"


@pytest.mark.asyncio
async def test_settlement_endpoints():
    transport = ASGITransport(app=app)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            r = await client.post("/api/v1/auth/device", json={"device_id": "settle-0001"})
            h = {"Authorization": f"Bearer {r.json()['access_token']}"}

            # settle a named season (idempotent); structure is correct even with
            # no Redis board data (0 grants).
            r = await client.post("/api/v1/admin/seasons/2026-S1/settle", headers=ADMIN)
            assert r.status_code == 200, r.text
            assert r.json()["season"] == "2026-S1"
            assert r.json()["already_settled"] is False

            # re-settle -> idempotent
            r = await client.post("/api/v1/admin/seasons/2026-S1/settle", headers=ADMIN)
            assert r.json()["already_settled"] is True

            # rollover settles the previous quarter and keeps current open
            r = await client.post("/api/v1/admin/seasons/rollover", headers=ADMIN)
            assert r.status_code == 200, r.text

            # player rewards endpoint responds (empty list here)
            r = await client.get("/api/v1/rewards", headers=h)
            assert r.status_code == 200
            assert isinstance(r.json(), list)
