"""Self-uploaded player avatars."""
from __future__ import annotations

import base64
import os
from io import BytesIO

os.environ.setdefault("PP_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")

from starlette.testclient import TestClient
from PIL import Image

from app.main import app


def _png(w=300, h=300) -> str:
    buf = BytesIO()
    Image.new("RGB", (w, h), (40, 120, 90)).save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def test_avatar_upload_and_lookup():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "avatar-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "avatar-player-B"}).json()
        ha = {"Authorization": f"Bearer {a['access_token']}"}

        # new accounts have no avatar
        assert a["avatar_url"] is None

        # upload an avatar
        r = client.post("/api/v1/players/avatar", json={"data": _png(), "ext": "png"}, headers=ha)
        assert r.status_code == 200, r.text
        url = r.json()["avatar_url"]
        assert url.startswith("/media/") and url.endswith(("_thumb.png", "_thumb.jpg", "_thumb.webp"))
        # the avatar image is served
        assert client.get(url).status_code == 200

        # re-login reflects the saved avatar
        again = client.post("/api/v1/auth/device", json={"device_id": "avatar-player-A"}).json()
        assert again["avatar_url"] == url

        # batch lookup returns A's avatar, and skips B (no avatar)
        r = client.get(f"/api/v1/players/avatars?ids={a['player_id']},{b['player_id']}", headers=ha)
        assert r.status_code == 200
        data = r.json()
        assert data.get(a["player_id"]) == url
        assert b["player_id"] not in data


def test_avatar_shows_in_chat_payload():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "avatar-chat-A"}).json()
        ha = {"Authorization": f"Bearer {a['access_token']}"}
        url = client.post("/api/v1/players/avatar", json={"data": _png(), "ext": "png"}, headers=ha).json()["avatar_url"]
        # reconnect so the WS picks up the new avatar, then chat carries it
        a2 = client.post("/api/v1/auth/device", json={"device_id": "avatar-chat-A"}).json()
        with client.websocket_connect(f"/api/v1/ws/ghosts/garden?token={a2['access_token']}") as ws:
            ws.send_json({"type": "chat", "channel": "chapter", "text": "看我的头像"})
            for _ in range(8):
                m = ws.receive_json()
                if m.get("type") == "chat":
                    assert m.get("avatar") == url
                    break
