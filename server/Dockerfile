FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .
RUN chmod +x entrypoint.sh

# Default 8000 (matches docker-compose/nginx and the HF Space README app_port: 8000).
EXPOSE 8000

# entrypoint.sh: runs `alembic upgrade head` (skip with PP_RUN_MIGRATIONS=0), then
# launches gunicorn with N uvicorn workers (WEB_CONCURRENCY, default 4) on $PORT
# (default 8000). Identical behavior for docker-compose and Hugging Face Spaces.
# Scale further with container replicas behind Nginx; -w ~ (2*CPU)+1, tune per host.
CMD ["./entrypoint.sh"]
