#!/usr/bin/env python3
"""Local static server for the Godot Web export, WITH cross-origin isolation
headers (COOP/COEP).

The threaded WASM build (Thread Support = on) needs SharedArrayBuffer, which the
browser only enables when the page is served with:
    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp
Plain `python3 -m http.server` does NOT send these, so a threaded build fails to
start there. This server adds them, mirroring the repo's vercel.json.

Usage:
    python3 tools/serve_web.py [port]      # serves build/web on :8060 by default
"""
from __future__ import annotations

import http.server
import os
import sys

ROOT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "build", "web")
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8060


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


if not os.path.isfile(os.path.join(ROOT, "index.html")):
    sys.exit(f"No export at {ROOT}/index.html — export the Web build from Godot first.")

print(f"Serving {ROOT}\n  with COOP/COEP at http://localhost:{PORT}  (Ctrl+C to stop)")
http.server.test(HandlerClass=Handler, port=PORT, bind="127.0.0.1")
