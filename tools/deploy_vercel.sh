#!/usr/bin/env bash
# Deploy the exported Godot Web build (build/web/) to Vercel.
#
# Vercel hosts only the static front-end. The Python backend (FastAPI + Postgres
# + Redis) must run elsewhere — see docs/DEPLOY_HF_SPACE.md / DEPLOY_VERCEL.md.
#
# This script ALWAYS installs the COOP/COEP headers required by the THREADED
# Godot Web export (SharedArrayBuffer / cross-origin isolation) by copying the
# repo-root vercel.json into build/web before deploying. It survives re-exports
# because the copy happens fresh on every deploy.
#
# Usage:
#   tools/deploy_vercel.sh                 # offline (mode A) or cross-origin online (B1)
#   PP_API_PROXY=https://api.example.com tools/deploy_vercel.sh
#                                          # same-origin (B2): also proxy /api + /media
#
# Prereq: export the Web build from Godot first, e.g.
#   godot --headless --export-release "Web" build/web/index.html
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT/build/web"

# 1) Verify the export exists.
if [[ ! -f "$WEB_DIR/index.html" ]]; then
  echo "✗ No export found at build/web/index.html" >&2
  echo "  Export the Web build from Godot first:" >&2
  echo "    godot --headless --export-release \"Web\" build/web/index.html" >&2
  echo "  (or Project → Export… → Web in the editor). See docs/DEPLOY_VERCEL.md §0." >&2
  exit 1
fi
for f in index.wasm index.pck index.js; do
  [[ -f "$WEB_DIR/$f" ]] || echo "⚠ build/web/$f missing — export may be incomplete." >&2
done

# 2) Ensure the Vercel CLI is available.
if ! command -v vercel >/dev/null 2>&1; then
  echo "→ Vercel CLI not found; installing globally (npm i -g vercel)…"
  npm i -g vercel
fi

# 3) Install vercel.json (COOP/COEP headers) into the build so the threaded WASM
#    build is cross-origin isolated on Vercel.
if [[ -f "$ROOT/vercel.json" ]]; then
  cp "$ROOT/vercel.json" "$WEB_DIR/vercel.json"
  echo "→ Installed COOP/COEP headers (vercel.json) into build/web"
else
  echo "⚠ $ROOT/vercel.json not found — a threaded build will fail without COOP/COEP headers." >&2
fi

# 3b) Same-origin mode (B2): merge /api + /media rewrites into build/web/vercel.json.
#     NOTE: Vercel rewrites do NOT proxy WebSocket, so realtime needs NetConfig.realtime=false.
if [[ -n "${PP_API_PROXY:-}" ]]; then
  proxy="${PP_API_PROXY%/}"   # strip trailing slash
  echo "→ Adding same-origin rewrites: /api/* and /media/* → $proxy"
  python3 - "$WEB_DIR/vercel.json" "$proxy" <<'PY'
import json, os, sys
path, proxy = sys.argv[1], sys.argv[2]
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault("rewrites", [])
data["rewrites"] += [
    {"source": "/api/:path*",   "destination": f"{proxy}/api/:path*"},
    {"source": "/media/:path*", "destination": f"{proxy}/media/:path*"},
]
json.dump(data, open(path, "w"), indent=2)
print("  rewrites merged into", os.path.basename(path))
PY
  echo "  (reminder: set NetConfig.base_url = \"/api/v1\" and realtime = false, then re-export.)"
fi

# 4) Deploy the static folder to production.
echo "→ Deploying build/web → Vercel (production)…"
cd "$WEB_DIR"
vercel deploy --prod

echo "✓ Done. Threaded build served cross-origin isolated (COOP/COEP). If online"
echo "  (mode B), confirm the backend is HTTPS-reachable and PP_CORS_ORIGINS includes"
echo "  your Vercel domain."
