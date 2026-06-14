# Deploying the Web build

This project is set up for a one-click Web export. You still run the export from
the Godot editor on your own machine (that's where the export templates live), then
upload the result anywhere that serves static files.

A **Web** export preset is already included (`export_presets.cfg`), configured for
single-threaded WebAssembly so it runs on simple static hosts **without needing
special cross-origin headers**.

---

## 1. One-time setup in Godot

1. Install **Godot 4.2+** (standard build) from https://godotengine.org/download
2. Open this project (`project.godot`).
3. Install the matching **export templates**: menu **Editor → Manage Export
   Templates → Download and Install**. (One time per Godot version.)

## 2. Export the build

1. Menu **Project → Export…**
2. Select the **Web** preset (already listed).
3. Click **Export Project**, keep the path `build/web/index.html`, and confirm.

Godot writes these files into `build/web/`:

```
index.html  index.js  index.wasm  index.pck  index.audio.worklet.js  index.icon.png ...
```

That whole `build/web/` folder **is** the game.

### Quick local test

From a terminal in `build/web/`:

```
python3 -m http.server 8080
```

Then open `http://localhost:8080`. (A plain server works because threading is off.
Do **not** just double-click `index.html` — browsers block `file://` WASM loads.)

---

## 3. Put it online — pick one

### itch.io (easiest for a game)
1. Zip the **contents** of `build/web/` (so `index.html` is at the zip root).
2. On itch.io: create a new project → **Kind of project: HTML**.
3. Upload the zip, tick **"This file will be played in the browser"**.
4. Set a viewport size (e.g. 1280×720) and save. Done — you get a public page.

### GitHub Pages (free static hosting)
1. Commit `build/web/` to a repo (the included `.gitignore` ignores `build/` — for
   Pages, either remove that line or copy the files into a `docs/` folder or a
   `gh-pages` branch).
2. Repo **Settings → Pages** → serve from that branch/folder.
3. Your URL: `https://<user>.github.io/<repo>/`.

### Netlify / Vercel (drag-and-drop)
- **Netlify:** drag the `build/web/` folder onto the Netlify "Sites" drop area.
- **Vercel:** `vercel deploy build/web` (or import the repo and set the output dir).

Both serve static files with correct MIME types out of the box.

---

## Notes & troubleshooting

- **Renderer:** the project uses `gl_compatibility` (OpenGL/WebGL2), which is the
  right choice for the web. GPU particles (the cross / celestial light bursts) may
  look faint in WebGL — the dynamic lights still read fine.
- **Blank page or "Failed to start":** open the browser dev console (F12). The
  usual causes are wrong MIME types for `.wasm`/`.pck` on a custom server, or
  trying to run from `file://`. Use a real static host or the local server above.
- **If you ever enable threads** (`Thread Support` in the preset), the host must
  send `Cross-Origin-Opener-Policy: same-origin` and
  `Cross-Origin-Embedder-Policy: require-corp` headers. itch.io has a checkbox for
  this; for GitHub Pages you'd need a different host. The current preset keeps
  threads **off** precisely to avoid this.
- **Controls reminder for players:** WASD move · Space jump · E interact · 1-4
  choose · C heart · Tab map · Esc pause.

---

## Desktop builds (optional)

The same Export dialog can produce Windows / macOS / Linux builds — add the
matching preset, install its export templates, and export to an `.exe` / `.app` /
binary. No code changes are needed.
