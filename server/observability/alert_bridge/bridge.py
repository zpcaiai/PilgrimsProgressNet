#!/usr/bin/env python3
"""Alertmanager -> Feishu / DingTalk webhook bridge (standard library only).

Alertmanager POSTs its webhook JSON here; this service formats a readable
message and forwards it to a Feishu and/or DingTalk custom-bot webhook.

Env:
  PORT             listen port (default 8080)
  FEISHU_WEBHOOK   Feishu custom-bot webhook URL (optional)
  DINGTALK_WEBHOOK DingTalk custom-bot webhook URL (optional)
  DINGTALK_SECRET  DingTalk signing secret (optional; enables signed requests)

Run: python bridge.py   (or via the alert-bridge compose service)
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

FEISHU_WEBHOOK = os.environ.get("FEISHU_WEBHOOK", "")
DINGTALK_WEBHOOK = os.environ.get("DINGTALK_WEBHOOK", "")
DINGTALK_SECRET = os.environ.get("DINGTALK_SECRET", "")
PORT = int(os.environ.get("PORT", "8080"))


def format_alerts(payload: dict) -> str:
    """Turn an Alertmanager webhook payload into a readable text block."""
    status = str(payload.get("status", "")).upper()
    alerts = payload.get("alerts", []) or []
    head = f"【天路监控】{status}（{len(alerts)} 条）"
    lines = [head]
    for a in alerts:
        labels = a.get("labels", {}) or {}
        ann = a.get("annotations", {}) or {}
        st = str(a.get("status", "")).upper()
        sev = labels.get("severity", "")
        name = labels.get("alertname", "alert")
        summary = ann.get("summary", "")
        desc = ann.get("description", "")
        inst = labels.get("instance", "")
        lines.append(f"• [{st}] {name}（{sev}）{('@' + inst) if inst else ''}")
        if summary:
            lines.append(f"    {summary}")
        if desc:
            lines.append(f"    {desc}")
    return "\n".join(lines)


def _post_json(url: str, body: dict) -> tuple[int, str]:
    data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status, resp.read().decode("utf-8", "ignore")
    except Exception as exc:  # pragma: no cover - network
        return 0, str(exc)


def send_feishu(text: str) -> tuple[int, str]:
    return _post_json(FEISHU_WEBHOOK, {"msg_type": "text", "content": {"text": text}})


def _dingtalk_signed_url() -> str:
    if not DINGTALK_SECRET:
        return DINGTALK_WEBHOOK
    ts = str(round(time.time() * 1000))
    string_to_sign = f"{ts}\n{DINGTALK_SECRET}"
    sign = base64.b64encode(
        hmac.new(DINGTALK_SECRET.encode("utf-8"), string_to_sign.encode("utf-8"), hashlib.sha256).digest()
    ).decode("utf-8")
    sep = "&" if "?" in DINGTALK_WEBHOOK else "?"
    return f"{DINGTALK_WEBHOOK}{sep}timestamp={ts}&sign={urllib.parse.quote_plus(sign)}"


def send_dingtalk(text: str) -> tuple[int, str]:
    return _post_json(_dingtalk_signed_url(), {"msgtype": "text", "text": {"content": text}})


def dispatch(payload: dict) -> dict:
    text = format_alerts(payload)
    results: dict[str, object] = {}
    if FEISHU_WEBHOOK:
        results["feishu"] = send_feishu(text)
    if DINGTALK_WEBHOOK:
        results["dingtalk"] = send_dingtalk(text)
    if not results:
        results["noop"] = "no webhook configured (set FEISHU_WEBHOOK / DINGTALK_WEBHOOK)"
    return results


class Handler(BaseHTTPRequestHandler):
    def _send(self, code: int, body: dict) -> None:
        data = json.dumps(body).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self) -> None:  # health check
        self._send(200, {"status": "ok"})

    def do_POST(self) -> None:
        length = int(self.headers.get("Content-Length", "0") or "0")
        raw = self.rfile.read(length) if length else b"{}"
        try:
            payload = json.loads(raw or b"{}")
        except json.JSONDecodeError:
            self._send(400, {"error": "invalid json"})
            return
        results = dispatch(payload)
        self._send(200, {"forwarded": results})

    def log_message(self, *args) -> None:  # quieter logs
        pass


def main() -> None:
    print(f"alert-bridge listening on :{PORT} "
          f"(feishu={'on' if FEISHU_WEBHOOK else 'off'}, dingtalk={'on' if DINGTALK_WEBHOOK else 'off'})")
    ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()


if __name__ == "__main__":
    main()
