"""Anonymous device-token auth + optional email binding."""
from __future__ import annotations

import jwt
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .. import email as email_svc
from ..config import get_settings
from ..db import get_session
from ..deps import current_player
from ..models import Player
from ..schemas import (
    BindEmailIn,
    DeviceAuthIn,
    RecoverIn,
    RefreshIn,
    RequestEmailCodeIn,
    RequestEmailCodeOut,
    TokenOut,
)
from ..security import decode_token, make_access_token, make_refresh_token

router = APIRouter(prefix="/auth", tags=["auth"])
settings = get_settings()


def _default_name(device_id: str) -> str:
    return f"无名的朝圣者#{device_id[-4:]}"


@router.post("/device", response_model=TokenOut)
async def device_login(body: DeviceAuthIn, session: AsyncSession = Depends(get_session)) -> TokenOut:
    """Log in (or create) a player by device_id. No registration required."""
    result = await session.execute(select(Player).where(Player.device_id == body.device_id))
    player = result.scalar_one_or_none()
    if player is None:
        player = Player(
            device_id=body.device_id,
            display_name=body.display_name or _default_name(body.device_id),
        )
        session.add(player)
        await session.flush()
    elif body.display_name:
        player.display_name = body.display_name

    return TokenOut(
        access_token=make_access_token(player.id),
        refresh_token=make_refresh_token(player.id),
        player_id=player.id,
        display_name=player.display_name,
        avatar_url=player.avatar_url,
    )


@router.post("/refresh", response_model=TokenOut)
async def refresh(body: RefreshIn, session: AsyncSession = Depends(get_session)) -> TokenOut:
    try:
        player_id = decode_token(body.refresh_token, "refresh")
    except jwt.PyJWTError as exc:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"invalid refresh token: {exc}") from exc
    player = await session.get(Player, player_id)
    if player is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "unknown player")
    return TokenOut(
        access_token=make_access_token(player.id),
        refresh_token=make_refresh_token(player.id),
        player_id=player.id,
        display_name=player.display_name,
        avatar_url=player.avatar_url,
    )


@router.post("/request-email-code", response_model=RequestEmailCodeOut)
async def request_email_code(body: RequestEmailCodeIn) -> RequestEmailCodeOut:
    """Send a 6-digit verification code for binding or recovery.
    Rate-limited per email via a Redis cooldown. In dev the code is logged
    (and echoed in the response if PP_EMAIL_DEV_ECHO is on)."""
    if await email_svc.on_cooldown(body.purpose, body.email):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            f"请稍后再试（{settings.email_code_cooldown_sec}s 内只能发送一次）",
        )
    code = email_svc.generate_code()
    await email_svc.store_code(body.purpose, body.email, code)
    await email_svc.send_code(body.purpose, body.email, code)
    return RequestEmailCodeOut(
        sent=True,
        cooldown_sec=settings.email_code_cooldown_sec,
        dev_code=code if settings.email_dev_echo else None,
    )


@router.post("/bind-email", response_model=TokenOut)
async def bind_email(
    body: BindEmailIn,
    player: Player = Depends(current_player),
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    """Bind an email (verified by code) so the account can be recovered later."""
    if not await email_svc.verify_code("bind", body.email, body.code):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "验证码无效或已过期")
    existing = await session.execute(select(Player).where(Player.email == body.email))
    other = existing.scalar_one_or_none()
    if other is not None and other.id != player.id:
        raise HTTPException(status.HTTP_409_CONFLICT, "该邮箱已被其他账号绑定")
    player.email = body.email
    session.add(player)
    return TokenOut(
        access_token=make_access_token(player.id),
        refresh_token=make_refresh_token(player.id),
        player_id=player.id,
        display_name=player.display_name,
        avatar_url=player.avatar_url,
    )


@router.post("/recover", response_model=TokenOut)
async def recover(body: RecoverIn, session: AsyncSession = Depends(get_session)) -> TokenOut:
    """Recover an account on a new device: verify the email code, then re-link
    the account to this device's device_id and return fresh tokens."""
    if not await email_svc.verify_code("recover", body.email, body.code):
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "验证码无效或已过期")
    result = await session.execute(select(Player).where(Player.email == body.email))
    player = result.scalar_one_or_none()
    if player is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "该邮箱未绑定任何账号")

    # If this device already maps to a different (anonymous) player, free it so
    # the unique device_id can be re-pointed to the recovered account.
    clash = await session.execute(select(Player).where(Player.device_id == body.device_id))
    other = clash.scalar_one_or_none()
    if other is not None and other.id != player.id:
        other.device_id = f"retired-{other.id}"
        session.add(other)
        await session.flush()

    player.device_id = body.device_id
    session.add(player)
    return TokenOut(
        access_token=make_access_token(player.id),
        refresh_token=make_refresh_token(player.id),
        player_id=player.id,
        display_name=player.display_name,
        avatar_url=player.avatar_url,
    )
