#!/usr/bin/env sh
# Container entrypoint: run DB migrations, then start the API server.
#
# Used by both docker-compose (local) and Hugging Face Spaces (Docker SDK).
# - Migrations: `alembic upgrade head` (alembic/env.py is async/asyncpg-aware).
#   Skip with PP_RUN_MIGRATIONS=0 (e.g. if you migrate out-of-band).
# - Port: $PORT if the host injects one (Render/Railway); otherwise 8000, which
#   matches docker-compose/nginx and the HF Space README `app_port: 8000`.
# - Workers: $WEB_CONCURRENCY (default 4). Tune to ~ (2*CPU)+1.
set -e

PORT="${PORT:-8000}"
WORKERS="${WEB_CONCURRENCY:-4}"

if [ "${PP_RUN_MIGRATIONS:-1}" = "1" ]; then
  echo "[entrypoint] alembic upgrade head ..."
  alembic upgrade head
else
  echo "[entrypoint] PP_RUN_MIGRATIONS=0 -> skipping migrations"
fi

echo "[entrypoint] starting gunicorn on 0.0.0.0:${PORT} (${WORKERS} workers)"
exec gunicorn app.main:app \
  -k uvicorn.workers.UvicornWorker \
  -w "${WORKERS}" \
  -b "0.0.0.0:${PORT}" \
  --access-logfile - \
  --timeout 60
