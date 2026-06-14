"""Chat: moderation, world/DM channels, image upload, history, mute endpoint."""
from __future__ import annotations

import base64
import os

os.environ.setdefault("PP_DATABASE_URL", "sqlite+aiosqlite:///:memory:")
os.environ.setdefault("PP_ENV", "dev")
os.environ.setdefault("PP_REDIS_URL", "redis://localhost:6390/0")

from starlette.testclient import TestClient

from app import moderation
from app.main import app

ADMIN = {"X-Admin-Token": "change-me-admin"}


def test_moderation_masks_banned_words():
    out = moderation.filter_text("this is a badword, 垃圾广告 indeed")
    assert "badword" not in out
    assert "垃圾广告" not in out
    assert "*" in out


def test_world_channel_reaches_other_chapter():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "world-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "world-player-B"}).json()
        wa = client.websocket_connect(f"/api/v1/ws/ghosts/cityA?token={a['access_token']}")
        wb = client.websocket_connect(f"/api/v1/ws/ghosts/cityB?token={b['access_token']}")
        with wa as wsa, wb as wsb:
            wsa.send_json({"type": "chat", "channel": "world", "text": "大家平安"})
            ok = False
            for _ in range(8):
                m = wsb.receive_json()
                if m.get("type") == "chat" and m.get("channel") == "world":
                    assert m["text"] == "大家平安"
                    ok = True
                    break
            assert ok, "world message did not reach a player in another chapter"


def test_dm_is_private():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "dm-player-AA"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "dm-player-BB"}).json()
        c = client.post("/api/v1/auth/device", json={"device_id": "dm-player-CC"}).json()
        wa = client.websocket_connect(f"/api/v1/ws/ghosts/town?token={a['access_token']}")
        wb = client.websocket_connect(f"/api/v1/ws/ghosts/town?token={b['access_token']}")
        wc = client.websocket_connect(f"/api/v1/ws/ghosts/town?token={c['access_token']}")
        with wa as wsa, wb as wsb, wc as wsc:
            wsa.send_json({"type": "chat", "channel": "dm", "to": b["player_id"], "text": "只给你"})
            wsa.send_json({"type": "chat", "channel": "world", "text": "广播"})
            # B receives the DM
            got_dm = False
            for _ in range(8):
                m = wsb.receive_json()
                if m.get("type") == "chat" and m.get("channel") == "dm":
                    assert m["text"] == "只给你"
                    got_dm = True
                    break
            assert got_dm
            # C should get the world broadcast but never the DM
            saw_world = False
            for _ in range(8):
                m = wsc.receive_json()
                assert not (m.get("type") == "chat" and m.get("channel") == "dm"), "C leaked a DM"
                if m.get("type") == "chat" and m.get("channel") == "world":
                    saw_world = True
                    break
            assert saw_world


def test_image_upload_and_limit():
    with TestClient(app) as client:
        tok = client.post("/api/v1/auth/device", json={"device_id": "img-player-A"}).json()["access_token"]
        h = {"Authorization": f"Bearer {tok}"}
        small = base64.b64encode(b"\x89PNG\r\n\x1a\n" + b"0" * 64).decode()
        r = client.post("/api/v1/chat/image", json={"data": small, "ext": "png"}, headers=h)
        assert r.status_code == 200, r.text
        assert r.json()["url"].startswith("/media/")
        big = base64.b64encode(b"0" * (3 * 1024 * 1024)).decode()
        r = client.post("/api/v1/chat/image", json={"data": big, "ext": "png"}, headers=h)
        assert r.status_code == 413


def test_chapter_history_on_join():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "hist-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "hist-player-B"}).json()
        with client.websocket_connect(f"/api/v1/ws/ghosts/relic?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "先到一步"})
            # wait until A sees its own echo (means the message is persisted)
            for _ in range(8):
                if wsa.receive_json().get("type") == "chat":
                    break
            with client.websocket_connect(f"/api/v1/ws/ghosts/relic?token={b['access_token']}") as wsb:
                got_history = False
                for _ in range(5):
                    m = wsb.receive_json()
                    if m.get("type") == "chat_history":
                        texts = [it.get("text") for it in m.get("items", [])]
                        assert "先到一步" in texts
                        got_history = True
                        break
                assert got_history


def _png_bytes(w: int, h: int) -> bytes:
    from io import BytesIO
    from PIL import Image
    buf = BytesIO()
    Image.new("RGB", (w, h), (120, 80, 200)).save(buf, "PNG")
    return buf.getvalue()


def test_image_compress_and_thumbnail():
    import base64 as b64
    with TestClient(app) as client:
        tok = client.post("/api/v1/auth/device", json={"device_id": "imgproc-player"}).json()["access_token"]
        h = {"Authorization": f"Bearer {tok}"}
        big = b64.b64encode(_png_bytes(2000, 1500)).decode()  # larger than MAX_DIM
        r = client.post("/api/v1/chat/image", json={"data": big, "ext": "png"}, headers=h)
        assert r.status_code == 200, r.text
        body = r.json()
        assert body["url"].startswith("/media/") and body["thumb_url"].endswith(("_thumb.png", "_thumb.jpg", "_thumb.webp"))
        # both files are fetchable and the thumbnail is smaller on disk
        full = client.get(body["url"])
        thumb = client.get(body["thumb_url"])
        assert full.status_code == 200 and thumb.status_code == 200
        assert len(thumb.content) < len(full.content)
        # the full image was downsized to <= 1280 on its longest side
        from io import BytesIO
        from PIL import Image
        assert max(Image.open(BytesIO(full.content)).size) <= 1280


def test_dm_unread_counter():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "unread-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "unread-player-B"}).json()
        hb = {"Authorization": f"Bearer {b['access_token']}"}

        # A DMs B while B isn't watching -> B has unread
        with client.websocket_connect(f"/api/v1/ws/ghosts/cave?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "dm", "to": b["player_id"], "text": "在吗"})
            for _ in range(8):  # wait for A's echo => persisted + counted
                if wsa.receive_json().get("type") == "chat":
                    break

        r = client.get("/api/v1/chat/unread", headers=hb)
        assert r.status_code == 200
        data = r.json()
        assert data["total"] >= 1
        assert any(t["peer_id"] == a["player_id"] for t in data["threads"])

        # B reads the thread -> cleared
        client.post("/api/v1/chat/read", json={"peer_id": a["player_id"]}, headers=hb)
        r = client.get("/api/v1/chat/unread", headers=hb)
        assert r.json()["total"] == 0


def test_dm_threads_list():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "threads-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "threads-player-B"}).json()
        ha = {"Authorization": f"Bearer {a['access_token']}"}
        with client.websocket_connect(f"/api/v1/ws/ghosts/grove?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "dm", "to": b["player_id"], "text": "晚上好"})
            for _ in range(8):
                if wsa.receive_json().get("type") == "chat":
                    break
        # A's conversation list shows the thread with B and the last message
        r = client.get("/api/v1/chat/threads", headers=ha)
        assert r.status_code == 200
        rows = r.json()
        assert any(t["peer_id"] == b["player_id"] and t["last_text"] == "晚上好" for t in rows)


def test_pin_sorts_thread_to_top():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "pin-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "pin-player-B"}).json()
        c = client.post("/api/v1/auth/device", json={"device_id": "pin-player-C"}).json()
        ha = {"Authorization": f"Bearer {a['access_token']}"}
        with client.websocket_connect(f"/api/v1/ws/ghosts/keep?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "dm", "to": b["player_id"], "text": "给B"})
            wsa.send_json({"type": "chat", "channel": "dm", "to": c["player_id"], "text": "给C"})
            seen = 0
            while seen < 2:
                if wsa.receive_json().get("type") == "chat":
                    seen += 1
        # C is most recent, so without pins C is first; pin B -> B floats to top
        client.post("/api/v1/chat/pin", json={"peer_id": b["player_id"], "pinned": True}, headers=ha)
        rows = client.get("/api/v1/chat/threads", headers=ha).json()
        assert rows[0]["peer_id"] == b["player_id"] and rows[0]["pinned"] is True


def test_mention_notifies_offline_target():
    with TestClient(app) as client:
        # B exists (its display_name is the default 无名的朝圣者#<last4>)
        b = client.post("/api/v1/auth/device", json={"device_id": "mention-target-B"}).json()
        a = client.post("/api/v1/auth/device", json={"device_id": "mention-sender-A"}).json()
        hb = {"Authorization": f"Bearer {b['access_token']}"}
        b_name = b["display_name"]
        # A mentions B by name in the world channel while B is not connected
        with client.websocket_connect(f"/api/v1/ws/ghosts/court?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "world", "text": f"@{b_name} 等你"})
            # Ping barrier: the handler finishes the chat (incl. mention insert)
            # before processing the next message, so a pong means it's persisted.
            wsa.send_json({"type": "ping", "t": 7})
            for _ in range(10):
                if wsa.receive_json().get("type") == "pong":
                    break
        # B logs in later and sees the unseen mention
        r = client.get("/api/v1/chat/mentions", headers=hb)
        assert r.status_code == 200
        assert any("等你" in m["text"] for m in r.json())
        # marking seen clears it
        client.post("/api/v1/chat/mentions/seen", headers=hb)
        assert client.get("/api/v1/chat/mentions", headers=hb).json() == []


def test_recall_removes_message_from_history():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "recall-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "recall-player-B"}).json()
        with client.websocket_connect(f"/api/v1/ws/ghosts/tomb?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "待撤回"})
            mid = None
            for _ in range(8):
                m = wsa.receive_json()
                if m.get("type") == "chat" and m.get("text") == "待撤回":
                    mid = m.get("mid")
                    break
            assert mid
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "保留"})
            for _ in range(8):
                if wsa.receive_json().get("text") == "保留":
                    break
            wsa.send_json({"type": "chat_delete", "mid": mid})
            wsa.send_json({"type": "ping", "t": 9})   # barrier: delete done before pong
            for _ in range(10):
                if wsa.receive_json().get("type") == "pong":
                    break
        # B joins: history keeps a tombstone (deleted=True, empty text) for the
        # recalled message plus the kept one.
        with client.websocket_connect(f"/api/v1/ws/ghosts/tomb?token={b['access_token']}") as wsb:
            items = []
            for _ in range(5):
                m = wsb.receive_json()
                if m.get("type") == "chat_history":
                    items = m.get("items", [])
                    break
            texts = [it.get("text") for it in items]
            assert "保留" in texts
            assert "待撤回" not in texts
            assert any(it.get("deleted") for it in items), "expected a recalled tombstone"


def test_read_receipt_pushed_to_sender():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "receipt-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "receipt-player-B"}).json()
        hb = {"Authorization": f"Bearer {b['access_token']}"}
        # A sends B a DM, then stays connected.
        with client.websocket_connect(f"/api/v1/ws/ghosts/well?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "dm", "to": b["player_id"], "text": "看到了吗"})
            for _ in range(8):
                if wsa.receive_json().get("type") == "chat":
                    break
            # B reads the thread -> A should receive a read receipt naming B.
            client.post("/api/v1/chat/read", json={"peer_id": a["player_id"]}, headers=hb)
            got = False
            for _ in range(8):
                m = wsa.receive_json()
                if m.get("type") == "read" and m.get("reader") == b["player_id"]:
                    got = True
                    break
            assert got
        # And A can query the persisted read-state.
        ha = {"Authorization": f"Bearer {a['access_token']}"}
        r = client.get(f"/api/v1/chat/read-state?peer={b['player_id']}", headers=ha)
        assert r.status_code == 200 and r.json()["read_ts"] > 0


def test_recall_rejects_others_message():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "recall2-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "recall2-player-B"}).json()
        with client.websocket_connect(f"/api/v1/ws/ghosts/yard?token={a['access_token']}") as wsa, \
             client.websocket_connect(f"/api/v1/ws/ghosts/yard?token={b['access_token']}") as wsb:
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "A的消息"})
            mid = None
            for _ in range(8):
                m = wsa.receive_json()
                if m.get("type") == "chat":
                    mid = m.get("mid")
                    break
            # B tries to recall A's message -> rejected with a system notice
            wsb.send_json({"type": "chat_delete", "mid": mid})
            got_sys = False
            for _ in range(8):
                m = wsb.receive_json()
                if m.get("type") == "system":
                    got_sys = True
                    break
            assert got_sys


def test_group_room_broadcast():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "room-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "room-player-B"}).json()
        ha = {"Authorization": f"Bearer {a['access_token']}"}
        # A creates a room code (B could be told out of band).
        room = client.post("/api/v1/chat/room/create", headers=ha).json()["room"]
        # A and B are in different chapters but both join the same room.
        with client.websocket_connect(f"/api/v1/ws/ghosts/north?token={a['access_token']}") as wsa, \
             client.websocket_connect(f"/api/v1/ws/ghosts/south?token={b['access_token']}") as wsb:
            wsa.send_json({"type": "room_join", "room": room})
            wsb.send_json({"type": "room_join", "room": room})

            def _await_system(ws):
                for _ in range(8):
                    if ws.receive_json().get("type") == "system":
                        return True
                return False
            assert _await_system(wsa) and _await_system(wsb)
            wsa.send_json({"type": "chat", "channel": "room", "room": room, "text": "群里好"})
            got = False
            for _ in range(8):
                m = wsb.receive_json()
                if m.get("type") == "chat" and m.get("channel") == "room":
                    assert m["text"] == "群里好" and m.get("room") == room
                    got = True
                    break
            assert got, "room member B did not receive the group message"


def test_quote_reply_roundtrip():
    with TestClient(app) as client:
        a = client.post("/api/v1/auth/device", json={"device_id": "reply-player-A"}).json()
        b = client.post("/api/v1/auth/device", json={"device_id": "reply-player-B"}).json()
        with client.websocket_connect(f"/api/v1/ws/ghosts/field?token={a['access_token']}") as wsa:
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "原始消息"})
            mid = None
            for _ in range(8):
                m = wsa.receive_json()
                if m.get("type") == "chat":
                    mid = m.get("mid")
                    break
            wsa.send_json({"type": "chat", "channel": "chapter", "text": "回应",
                           "reply_to": mid, "reply_preview": "原始消息"})
            got = False
            for _ in range(8):
                m = wsa.receive_json()
                if m.get("type") == "chat" and m.get("reply_to") == mid:
                    assert m.get("reply_preview") == "原始消息"
                    got = True
                    break
            assert got
        # history carries the reply linkage
        with client.websocket_connect(f"/api/v1/ws/ghosts/field?token={b['access_token']}") as wsb:
            for _ in range(5):
                m = wsb.receive_json()
                if m.get("type") == "chat_history":
                    assert any(it.get("reply_to") == mid for it in m.get("items", []))
                    break


def test_admin_mute_endpoint():
    with TestClient(app) as client:
        r = client.post("/api/v1/admin/mute/some-player-id?minutes=5", headers=ADMIN)
        assert r.status_code == 200
        assert r.json()["muted"] == "some-player-id"
        r = client.delete("/api/v1/admin/mute/some-player-id", headers=ADMIN)
        assert r.status_code == 200
