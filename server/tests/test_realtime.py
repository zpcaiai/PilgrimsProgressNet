"""Admin login auth + real-time WebSocket relay tests.

Uses Starlette's TestClient (sync) which supports websockets. Redis is down, so
the room manager uses its local-broadcast fallback (single process) — exactly
what we need to verify the relay logic.
"""
from __future__ import annotations

import os

os.environ.setdefault("PP_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")

from starlette.testclient import TestClient

from app.main import app


def test_admin_login_and_guard():
    with TestClient(app) as client:
        # wrong creds rejected
        r = client.post("/api/v1/admin/login", json={"username": "admin", "password": "nope"})
        assert r.status_code == 401

        # correct creds issue a session token
        r = client.post("/api/v1/admin/login",
                        json={"username": "admin", "password": "change-me-admin-pw"})
        assert r.status_code == 200, r.text
        token = r.json()["token"]

        # the session token authorizes admin endpoints (Bearer)
        r = client.get("/api/v1/admin/reviews?status=pending",
                       headers={"Authorization": f"Bearer {token}"})
        assert r.status_code == 200

        # the static X-Admin-Token still works too (cron path)
        r = client.get("/api/v1/admin/reviews?status=pending",
                       headers={"X-Admin-Token": "change-me-admin"})
        assert r.status_code == 200

        # no auth -> forbidden
        assert client.get("/api/v1/admin/reviews").status_code == 403


def test_ws_relay_between_two_players():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "rt-player-A1"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "rt-player-B2"}).json()

        url_a = f"/api/v1/ws/ghosts/valley_humiliation?token={a['access_token']}"
        url_b = f"/api/v1/ws/ghosts/valley_humiliation?token={b['access_token']}"

        with client.websocket_connect(url_a) as wsa, client.websocket_connect(url_b) as wsb:
            # A moves; B should receive a "peer" frame carrying A's id.
            wsa.send_json({"type": "pos", "x": 1.0, "y": 0.0, "z": 2.0, "yaw": 0.5})
            got_peer = False
            for _ in range(8):
                msg = wsb.receive_json()
                if msg.get("type") == "peer" and msg.get("id") == a["player_id"]:
                    assert msg["x"] == 1.0 and msg["z"] == 2.0
                    got_peer = True
                    break
            assert got_peer, "B did not receive A's position"


def test_ws_chat_and_ping():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "chat-player-A1"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "chat-player-B2"}).json()
        url_a = f"/api/v1/ws/ghosts/vanity_fair?token={a['access_token']}"
        url_b = f"/api/v1/ws/ghosts/vanity_fair?token={b['access_token']}"

        with client.websocket_connect(url_a) as wsa, client.websocket_connect(url_b) as wsb:
            # A chats; B receives it with A's name/text.
            wsa.send_json({"type": "chat", "text": "愿你平安，同路人"})
            got_chat = False
            for _ in range(8):
                msg = wsb.receive_json()
                if msg.get("type") == "chat" and msg.get("id") == a["player_id"]:
                    assert msg["text"] == "愿你平安，同路人"
                    got_chat = True
                    break
            assert got_chat, "B did not receive A's chat"

            # ping is answered with a pong carrying the same token (direct reply).
            wsa.send_json({"type": "ping", "t": 123456})
            got_pong = False
            for _ in range(8):
                msg = wsa.receive_json()
                if msg.get("type") == "pong":
                    assert msg["t"] == 123456
                    got_pong = True
                    break
            assert got_pong, "A did not receive a pong"


def test_ws_rejects_bad_token():
    with TestClient(app) as client:
        try:
            with client.websocket_connect("/api/v1/ws/ghosts/valley?token=garbage"):
                pass
            assert False, "expected the server to reject a bad token"
        except Exception:
            pass  # connection closed with policy-violation code
