"""Email verification codes: storage (Redis) + delivery (dev log / SMTP).

In dev (no SMTP_HOST), codes are logged and optionally echoed in the API
response (PP_EMAIL_DEV_ECHO) so you can test without a mail server. In prod,
set SMTP_* and PP_EMAIL_DEV_ECHO=false.
"""
from __future__ import annotations

import logging
import secrets
import smtplib
from email.mime.text import MIMEText

from . import cache
from .config import get_settings

logger = logging.getLogger("pilgrim.email")
settings = get_settings()

# In-memory fallback used when Redis is unreachable (dev/test). Not shared
# across replicas, so production should always have Redis up.
_LOCAL_CODES: dict[str, str] = {}
_LOCAL_COOLDOWN: set[str] = set()


def _code_key(purpose: str, email: str) -> str:
    return f"emailcode:{purpose}:{email.lower()}"


def _cooldown_key(purpose: str, email: str) -> str:
    return f"emailcooldown:{purpose}:{email.lower()}"


def generate_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


async def on_cooldown(purpose: str, email: str) -> bool:
    key = _cooldown_key(purpose, email)
    try:
        return bool(await cache.redis_client.exists(key))
    except Exception:
        return key in _LOCAL_COOLDOWN


async def store_code(purpose: str, email: str, code: str) -> None:
    key = _code_key(purpose, email)
    try:
        await cache.redis_client.set(key, code, ex=settings.email_code_ttl_sec)
        await cache.redis_client.set(
            _cooldown_key(purpose, email), "1", ex=settings.email_code_cooldown_sec
        )
    except Exception:
        logger.warning("Redis unavailable; storing email code in-process (dev fallback)")
        _LOCAL_CODES[key] = code
        _LOCAL_COOLDOWN.add(_cooldown_key(purpose, email))


async def verify_code(purpose: str, email: str, code: str) -> bool:
    key = _code_key(purpose, email)
    try:
        stored = await cache.redis_client.get(key)
        if stored is not None:
            if stored != code:
                return False
            await cache.redis_client.delete(key)  # one-time use
            return True
    except Exception:
        pass
    # Fallback store.
    if _LOCAL_CODES.get(key) == code:
        _LOCAL_CODES.pop(key, None)
        return True
    return False


def _send_smtp(to_email: str, subject: str, body: str) -> None:
    msg = MIMEText(body, _charset="utf-8")
    msg["Subject"] = subject
    msg["From"] = settings.smtp_from
    msg["To"] = to_email
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=10) as s:
        if settings.smtp_tls:
            s.starttls()
        if settings.smtp_user:
            s.login(settings.smtp_user, settings.smtp_password)
        s.sendmail(settings.smtp_from, [to_email], msg.as_string())


async def send_code(purpose: str, email: str, code: str) -> None:
    """Deliver the code. Dev (no SMTP_HOST) logs it; prod sends real mail."""
    subject = "天路历程 · 验证码"
    action = "绑定邮箱" if purpose == "bind" else "找回账号"
    body = f"你的{action}验证码是：{code}\n\n10 分钟内有效。若非本人操作请忽略。"
    if not settings.smtp_host:
        logger.info("[DEV EMAIL] to=%s purpose=%s code=%s", email, purpose, code)
        return
    try:
        _send_smtp(email, subject, body)
    except Exception as exc:  # pragma: no cover
        logger.error("SMTP send failed: %s", exc)
        raise
