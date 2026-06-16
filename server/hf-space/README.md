---
title: Pilgrim's Progress API
emoji: 🛤️
colorFrom: indigo
colorTo: gray
sdk: docker
app_port: 8000
pinned: false
---

# Pilgrim's Progress — Backend API

FastAPI backend (auth, leaderboards, cloud saves, async/real-time companionship,
chat) for the Godot game *The Pilgrim's Progress — Burden Fallen*.

**This file's YAML header is what makes the Space work** — it tells Hugging Face to
build the `Dockerfile` (`sdk: docker`) and route traffic to port **8000**
(`app_port: 8000`, matching `entrypoint.sh` / gunicorn).

This Space runs **one container** (the app only). It needs **external Postgres and
Redis** — set them, plus secrets, in **Settings → Variables and secrets**:

| Secret | Example |
|---|---|
| `PP_ENV` | `prod` |
| `PP_DATABASE_URL` | `postgresql+asyncpg://USER:PASS@HOST/db?ssl=require` (Neon/Supabase, **direct** endpoint) |
| `PP_REDIS_URL` | `rediss://default:PASS@HOST:6379` (Upstash, TLS) |
| `PP_JWT_SECRET` | output of `openssl rand -hex 32` |
| `PP_CORS_ORIGINS` | `https://your-app.vercel.app` (your front-end origin) |
| `PP_ADMIN_TOKEN` / `PP_ADMIN_PASSWORD` | strong random values |

Full runbook: `docs/DEPLOY_HF_SPACE.md` in the main game repo.
