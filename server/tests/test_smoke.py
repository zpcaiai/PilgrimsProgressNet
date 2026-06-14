"""Smoke test against an in-memory SQLite DB + fakeredis-free stubs.

Run: cd server && PYTHONPATH=. pytest -q
Verifies the app boots, tables create, and the auth->save->leaderboard flow
works end to end without Postgres/Redis (Redis calls fail open).
"""
from __future__ import annotations

import os

os.environ.setdefault("PP_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")  # unreachable -> fail open

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_auth_and_save_flow():
    transport = ASGITransport(app=app)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # health
            r = await client.get("/healthz")
            assert r.status_code == 200

            # prometheus metrics endpoint is exposed
            r = await client.get("/metrics")
            assert r.status_code == 200
            assert "pilgrim_http_requests_total" in r.text

            # anonymous device login
            r = await client.post("/api/v1/auth/device", json={"device_id": "device-abc-123"})
            assert r.status_code == 200, r.text
            token = r.json()["access_token"]
            headers = {"Authorization": f"Bearer {token}"}

            # upload a cloud save
            payload = {"game_state": {"current_chapter_id": "wicket_gate"}, "version": "0.1.0"}
            r = await client.put(
                "/api/v1/saves/slot_1", json={"payload": payload, "version": 0}, headers=headers
            )
            assert r.status_code == 200, r.text
            assert r.json()["version"] == 1

            # list saves
            r = await client.get("/api/v1/saves", headers=headers)
            assert r.status_code == 200
            assert r.json()[0]["chapter"] == "wicket_gate"

            # submit a score (Redis down -> still 200, PG record written)
            r = await client.post(
                "/api/v1/leaderboard/submit",
                json={"board": "devout_score", "difficulty": "standard", "score": 4200,
                      "meta": {"chapters_completed": 16}},
                headers=headers,
            )
            assert r.status_code == 200, r.text

            # ingest stat events
            r = await client.post(
                "/api/v1/stats/events",
                json={"events": [{"event": "chapter_completed", "chapter_id": "wicket_gate",
                                  "difficulty": "standard", "props": {}}]},
                headers=headers,
            )
            assert r.status_code == 202

            # current season is exposed
            r = await client.get("/api/v1/leaderboard/seasons/current", headers=headers)
            assert r.status_code == 200
            assert r.json()["season"]

            # board responds with a season field (Redis down -> empty top, still 200)
            r = await client.get("/api/v1/leaderboard/devout_score?season=all", headers=headers)
            assert r.status_code == 200, r.text
            assert r.json()["season"] == "all"


@pytest.mark.asyncio
async def test_email_bind_and_recover():
    transport = ASGITransport(app=app)
    async with app.router.lifespan_context(app):
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            # device A logs in and requests a bind code (dev echo returns it)
            r = await client.post("/api/v1/auth/device", json={"device_id": "device-A-00001"})
            tok_a = r.json()["access_token"]
            ha = {"Authorization": f"Bearer {tok_a}"}

            r = await client.post("/api/v1/auth/request-email-code",
                                  json={"email": "pilgrim@example.com", "purpose": "bind"})
            assert r.status_code == 200, r.text
            code = r.json()["dev_code"]
            assert code  # dev echo on

            # bind with a wrong code fails, correct code succeeds
            r = await client.post("/api/v1/auth/bind-email",
                                  json={"email": "pilgrim@example.com", "code": "000000"}, headers=ha)
            assert r.status_code == 400
            r = await client.post("/api/v1/auth/bind-email",
                                  json={"email": "pilgrim@example.com", "code": code}, headers=ha)
            assert r.status_code == 200, r.text
            player_a = r.json()["player_id"]

            # device B recovers the account via email code -> same player_id
            r = await client.post("/api/v1/auth/request-email-code",
                                  json={"email": "pilgrim@example.com", "purpose": "recover"})
            rcode = r.json()["dev_code"]
            r = await client.post("/api/v1/auth/recover",
                                  json={"email": "pilgrim@example.com", "code": rcode,
                                        "device_id": "device-B-99999"})
            assert r.status_code == 200, r.text
            assert r.json()["player_id"] == player_a
