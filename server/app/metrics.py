"""Prometheus metrics: request counter + latency histogram + /metrics endpoint."""
from __future__ import annotations

import time

from fastapi import Request, Response
from prometheus_client import (
    CONTENT_TYPE_LATEST,
    Counter,
    Histogram,
    generate_latest,
)

REQUESTS = Counter(
    "pilgrim_http_requests_total",
    "Total HTTP requests",
    ["method", "path", "status"],
)
LATENCY = Histogram(
    "pilgrim_http_request_duration_seconds",
    "HTTP request latency (seconds)",
    ["method", "path"],
)


def _label_path(request: Request) -> str:
    """Use the matched route template (low cardinality), e.g. /api/v1/saves/{slot_id}."""
    route = request.scope.get("route")
    if route is not None and getattr(route, "path", None):
        return route.path
    return "other"


async def metrics_middleware(request: Request, call_next):
    start = time.perf_counter()
    response = await call_next(request)
    path = _label_path(request)
    if path != "/metrics":  # don't measure the scrape itself
        elapsed = time.perf_counter() - start
        LATENCY.labels(request.method, path).observe(elapsed)
        REQUESTS.labels(request.method, path, str(response.status_code)).inc()
    return response


async def metrics_endpoint() -> Response:
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)
