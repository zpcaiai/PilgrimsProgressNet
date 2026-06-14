# Pilgrim's Progress — Online Backend

B/S backend for the networked version: **anonymous accounts, cloud saves,
leaderboards, 多人同行 (async ghosts), and data statistics**.

Stack: **FastAPI (async) · PostgreSQL · Redis · Nginx · Docker Compose**.
Full design rationale: [`../docs/ARCHITECTURE_BACKEND.md`](../docs/ARCHITECTURE_BACKEND.md).

## Quick start (Docker)

```bash
cd server
cp .env.example .env          # then edit PP_JWT_SECRET
docker compose up --build
# API:        http://localhost:8080/api/v1
# OpenAPI UI: http://localhost:8080/docs
# Health:     http://localhost:8080/healthz
```

Scale the app tier horizontally (stateless, Nginx load-balances):

```bash
docker compose up --build --scale app=3
```

## Run locally without Docker

```bash
cd server
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# point PP_DATABASE_URL / PP_REDIS_URL at local services, then:
uvicorn app.main:app --reload
```

In `PP_ENV=dev` the app auto-creates tables on startup. For production, use
Alembic:

```bash
alembic revision --autogenerate -m "init"
alembic upgrade head
```

## Test

```bash
cd server
pip install -r requirements.txt
pytest -q          # runs against in-memory SQLite; Redis calls fail open
```

## API surface (prefix `/api/v1`)

| Method & path | Purpose |
|---|---|
| `POST /auth/device` | Anonymous login/create by device_id → JWT |
| `POST /auth/refresh` · `POST /auth/bind-email` | Refresh token · bind email |
| `GET/PUT /saves` · `/saves/{slot}` | Cloud saves (optimistic lock; 409 = pull & merge) |
| `POST /leaderboard/submit` · `GET /leaderboard/{board}` | Submit score · Top-N + my rank |
| `POST /ghosts/trail` · `GET /ghosts/{chapter}` · `GET /ghosts/presence/{chapter}` | 多人同行 |
| `POST /stats/events` · `GET /stats/overview` | Telemetry ingest · chapter funnel |
| `GET /healthz` · `/readyz` | Probes |

Boards: `fastest_run`, `fewest_falls`, `devout_score`. Difficulties: `standard`, `child`.

## Admin dashboard & monitoring

- **Web admin** (same-origin, no CORS): open `http://localhost:8080/admin-ui/`,
  enter the API base (`/api/v1`) and your `PP_ADMIN_TOKEN`. Review/recompute the
  anti-cheat queue, approve/reject appeals, settle seasons, view the chapter funnel.
- **Metrics**: `GET /metrics` (Prometheus format). Bring up Prometheus + Grafana:

  ```bash
  docker compose -f docker-compose.yml -f docker-compose.observability.yml up
  # Grafana: http://localhost:3000  (admin/admin) — "Pilgrim API" dashboard auto-loads
  # Prometheus: http://localhost:9090
  ```

## Production checklist

- Set a strong `PP_JWT_SECRET`; restrict `PP_CORS_ORIGINS` to the game domain.
- Terminate TLS at Nginx; gate `GET /stats/overview` behind admin auth.
- Run Alembic migrations instead of dev `create_all`.
- Keep `replicas × PP_DB_POOL_SIZE` under Postgres `max_connections`, or add PgBouncer.
- Add Prometheus scraping + backups (see architecture doc §6–8).
