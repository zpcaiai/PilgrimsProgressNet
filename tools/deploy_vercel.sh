#!/usr/bin/env bash
# Deploy the exported Godot Web build (build/web/) to Vercel.
#
# Vercel hosts only the static front-end. The Python backend (FastAPI + Postgres
# + Redis) must run elsewhere — see docs/DEPLOY_VERCEL.md.
#
# Usage:
#   tools/deploy_vercel.sh                 # deploy build/web as-is (offline mode A, or cross-origin B1)
#   PP_API_PROXY=https://api.example.com tools/deploy_vercel.sh
#                                          # same-origin mode B2: inject /api + /media rewrites first
#
# Prereqs: you must have already exported the Web build from Godot, e.g.
#   godot --headless --export-release "Web" build/web/index.html
set -euo pipefail

# Repo root = parent of this script's dir (works regardless of where you call it from).
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

# 3) Same-origin mode (B2): inject /api + /media rewrites into the build before deploying.
#    NOTE: Vercel rewrites do NOT proxy WebSocket, so realtime needs NetConfig.realtime=false.
if [[ -n "${PP_API_PROXY:-}" ]]; then
  proxy="${PP_API_PROXY%/}"   # strip trailing slash
  echo "→ Injecting same-origin rewrites: /api/* and /media/* → $proxy"
  cat > "$WEB_DIR/vercel.json" <<JSON
{
  "\$schema": "https://openapi.vercel.sh/vercel.json",
  "rewrites": [
    { "source": "/api/:path*",   "destination": "$proxy/api/:path*" },
    { "source": "/media/:path*", "destination": "$proxy/media/:path*" }
  ]
}
JSON
  echo "  (reminder: set NetConfig.base_url = \"/api/v1\" and realtime = false, then re-export.)"
fi

# 4) Deploy the static folder to production.
echo "→ Deploying build/web → Vercel (production)…"
cd "$WEB_DIR"
vercel deploy --prod

echo "✓ Done. If this is mode B (online), confirm the backend is HTTPS-reachable"
echo "  and (B1) PP_CORS_ORIGINS includes your Vercel domain. See docs/DEPLOY_VERCEL.md."
