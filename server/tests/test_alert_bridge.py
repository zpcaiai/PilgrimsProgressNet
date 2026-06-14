"""Unit tests for the Alertmanager -> Feishu/DingTalk bridge (pure functions)."""
from __future__ import annotations

import base64
import hashlib
import hmac
import importlib.util
import os
from pathlib import Path

# Load the standalone bridge module by path (it lives outside the app package).
_bridge_path = Path(__file__).resolve().parent.parent / "observability" / "alert_bridge" / "bridge.py"
_spec = importlib.util.spec_from_file_location("alert_bridge", _bridge_path)
bridge = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bridge)


SAMPLE = {
    "status": "firing",
    "alerts": [
        {
            "status": "firing",
            "labels": {"alertname": "HighErrorRate", "severity": "critical", "instance": "app:8000"},
            "annotations": {"summary": "5xx error rate above 5%", "description": "5 分钟内超 5%"},
        },
        {
            "status": "firing",
            "labels": {"alertname": "HighLatencyP95", "severity": "warning"},
            "annotations": {"summary": "p95 latency above 1s"},
        },
    ],
}


def test_format_alerts_readable():
    text = bridge.format_alerts(SAMPLE)
    assert "FIRING" in text
    assert "HighErrorRate" in text and "critical" in text
    assert "app:8000" in text
    assert "5xx error rate above 5%" in text
    assert "p95 latency above 1s" in text
    # one header + alert lines
    assert text.splitlines()[0].startswith("【天路监控】FIRING")


def test_dingtalk_signing(monkeypatch):
    monkeypatch.setattr(bridge, "DINGTALK_WEBHOOK", "https://oapi.dingtalk.com/robot/send?access_token=abc")
    monkeypatch.setattr(bridge, "DINGTALK_SECRET", "SECfakethesecret")
    url = bridge._dingtalk_signed_url()
    assert "timestamp=" in url and "sign=" in url
    # the URL keeps the original access_token and appends signing params
    assert "access_token=abc" in url


def test_dingtalk_unsigned_when_no_secret(monkeypatch):
    monkeypatch.setattr(bridge, "DINGTALK_WEBHOOK", "https://example.com/hook")
    monkeypatch.setattr(bridge, "DINGTALK_SECRET", "")
    assert bridge._dingtalk_signed_url() == "https://example.com/hook"


def test_dispatch_noop_without_webhooks(monkeypatch):
    monkeypatch.setattr(bridge, "FEISHU_WEBHOOK", "")
    monkeypatch.setattr(bridge, "DINGTALK_WEBHOOK", "")
    out = bridge.dispatch(SAMPLE)
    assert "noop" in out
