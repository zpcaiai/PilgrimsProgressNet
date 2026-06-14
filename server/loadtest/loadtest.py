#!/usr/bin/env python3
"""Async load test for the Pilgrim backend.

Simulates many concurrent players, each running a realistic loop:
  device login -> upload save -> submit score -> post ghost trail
  -> fetch board -> fetch ghosts/presence -> batch stats

Reports per-endpoint throughput and latency percentiles (p50/p90/p99).
Designed to exercise a horizontally-scaled deployment, e.g.:

    docker compose up --build --scale app=3
    python loadtest/loadtest.py --base-url http://localhost:8080/api/v1 \
        --concurrency 50 --duration 20

Use --self-check to validate the script wiring without a server (dry run).
"""
from __future__ import annotations

import argparse
import asyncio
import random
import statistics
import time
import uuid
from collections import defaultdict

try:
    import httpx
except ImportError:  # pragma: no cover
    httpx = None

CHAPTERS = [
    "city_of_destruction", "wilderness_road", "slough_of_despond", "wicket_gate",
    "cross_and_tomb", "interpreter_house", "hill_difficulty", "palace_beautiful",
    "valley_humiliation", "valley_shadow_death", "vanity_fair", "doubting_castle",
    "delectable_mountains", "enchanted_ground", "river_of_death", "celestial_city",
]
BOARDS = ["fastest_run", "fewest_falls", "devout_score"]

# endpoint label -> list of latencies (ms)
LAT: dict[str, list[float]] = defaultdict(list)
ERRORS: dict[str, int] = defaultdict(int)


async def timed(label: str, coro):
    t0 = time.perf_counter()
    try:
        resp = await coro
        ok = resp.status_code < 400
    except Exception:
        ok = False
        resp = None
    dt = (time.perf_counter() - t0) * 1000.0
    LAT[label].append(dt)
    if not ok:
        ERRORS[label] += 1
    return resp


def _rand_trail(n: int = 60) -> list[list[float]]:
    pts = []
    x = y = z = 0.0
    for i in range(n):
        x += random.uniform(-1, 1)
        z += random.uniform(0, 2)
        pts.append([round(x, 2), round(y, 2), round(z, 2), i * 1000])
    return pts


async def player_loop(client: "httpx.AsyncClient", base: str, deadline: float) -> None:
    device_id = "load-" + uuid.uuid4().hex
    # login
    r = await timed("auth/device", client.post(f"{base}/auth/device", json={"device_id": device_id}))
    if r is None or r.status_code >= 400:
        return
    token = r.json().get("access_token", "")
    h = {"Authorization": f"Bearer {token}"}

    version = 0
    while time.perf_counter() < deadline:
        chapter = random.choice(CHAPTERS)

        # upload save (optimistic lock: send last known version)
        payload = {"game_state": {"current_chapter_id": chapter}, "version": "0.1.0"}
        r = await timed("saves PUT", client.put(
            f"{base}/saves/slot_1", json={"payload": payload, "version": version}, headers=h))
        if r is not None and r.status_code == 200:
            version = r.json().get("version", version)

        # submit score
        await timed("leaderboard/submit", client.post(
            f"{base}/leaderboard/submit",
            json={"board": random.choice(BOARDS), "difficulty": "standard",
                  "score": random.randint(0, 5000), "meta": {"chapters_completed": random.randint(1, 16)}},
            headers=h))

        # post ghost trail
        await timed("ghosts/trail", client.post(
            f"{base}/ghosts/trail",
            json={"chapter_id": chapter, "kind": "trail", "points": _rand_trail()}, headers=h))

        # reads
        await timed("leaderboard GET", client.get(
            f"{base}/leaderboard/devout_score?difficulty=standard&limit=20", headers=h))
        await timed("ghosts GET", client.get(f"{base}/ghosts/{chapter}", headers=h))
        await timed("presence GET", client.get(f"{base}/ghosts/presence/{chapter}", headers=h))

        # batch stats
        await timed("stats/events", client.post(
            f"{base}/stats/events",
            json={"events": [{"event": "chapter_completed", "chapter_id": chapter,
                              "difficulty": "standard", "props": {}}]}, headers=h))

        await asyncio.sleep(random.uniform(0.0, 0.05))


def _pct(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    s = sorted(values)
    k = min(len(s) - 1, int(round((p / 100.0) * (len(s) - 1))))
    return s[k]


def report(wall: float) -> None:
    total = sum(len(v) for v in LAT.values())
    print("\n=== Load test results ===")
    print(f"wall time: {wall:.1f}s   total requests: {total}   throughput: {total / wall:.0f} req/s\n")
    header = f"{'endpoint':<22}{'count':>8}{'err':>6}{'p50':>9}{'p90':>9}{'p99':>9}  (ms)"
    print(header)
    print("-" * len(header))
    for label in sorted(LAT.keys()):
        v = LAT[label]
        print(f"{label:<22}{len(v):>8}{ERRORS[label]:>6}"
              f"{_pct(v,50):>9.1f}{_pct(v,90):>9.1f}{_pct(v,99):>9.1f}")
    all_lat = [x for v in LAT.values() for x in v]
    if all_lat:
        print(f"\noverall  p50={_pct(all_lat,50):.1f}ms  p90={_pct(all_lat,90):.1f}ms  "
              f"p99={_pct(all_lat,99):.1f}ms  mean={statistics.mean(all_lat):.1f}ms")
    total_err = sum(ERRORS.values())
    print(f"errors: {total_err} ({(total_err / total * 100) if total else 0:.2f}%)")


async def main_async(args) -> None:
    deadline = time.perf_counter() + args.duration
    limits = httpx.Limits(max_connections=args.concurrency * 2, max_keepalive_connections=args.concurrency)
    async with httpx.AsyncClient(timeout=args.timeout, limits=limits) as client:
        t0 = time.perf_counter()
        await asyncio.gather(*[player_loop(client, args.base_url, deadline) for _ in range(args.concurrency)])
        report(time.perf_counter() - t0)


def self_check() -> None:
    """Dry-run the helpers without any network calls."""
    trail = _rand_trail(10)
    assert len(trail) == 10 and len(trail[0]) == 4
    assert _pct([1, 2, 3, 4], 50) in (2, 3)
    assert set(BOARDS) and len(CHAPTERS) == 16
    print("self-check OK: helpers, percentiles, and fixtures valid.")


def main() -> None:
    ap = argparse.ArgumentParser(description="Pilgrim backend load test")
    ap.add_argument("--base-url", default="http://localhost:8080/api/v1")
    ap.add_argument("--concurrency", type=int, default=50, help="simultaneous simulated players")
    ap.add_argument("--duration", type=float, default=20.0, help="seconds to run")
    ap.add_argument("--timeout", type=float, default=10.0)
    ap.add_argument("--self-check", action="store_true", help="validate script wiring, no server needed")
    args = ap.parse_args()

    if args.self_check:
        self_check()
        return
    if httpx is None:
        raise SystemExit("httpx not installed: pip install httpx")
    asyncio.run(main_async(args))


if __name__ == "__main__":
    main()
