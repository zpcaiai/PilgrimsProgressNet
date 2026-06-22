# Web Optimization Checklist

The game already ships a working web export (`index.wasm` / `index.pck` at the
project root, deployed to Vercel). The new GLB scene pipeline is built to stay
web-friendly. Use this list when re-exporting or trimming the build.

## Targets

- Initial load: aim under ~30 MB.
- Full build: aim under ~150 MB.
- Each chapter GLB: well under 5 MB (the generated set is ~20–90 KB each, ~717 KB
  for all 16 — geometry is greybox, materials are flat colors).

## Geometry & materials

1. Keep scenes low-poly (the generator already emits flat-shaded triangle soup).
2. Prefer material **colors** over textures; the chapters use flat base colors.
3. Share materials across objects (the GLB writer de-duplicates identical materials).
4. Use collision **primitives** where possible. ImportedSceneBinder adds trimesh
   collision only to `ENV_*` meshes (ground / walls / paths), not to every prop.

## Lighting & effects

5. Disable expensive real-time shadows on web; the chapter art profile uses one
   shadow-casting key light — consider lowering its shadow quality for web.
6. Use simple fog sparingly; avoid many dynamic lights. The binder skips
   `LIGHT_*Main/*Dim` markers and only spawns small accent omnis.
7. Keep particle counts low.

## Loading

8. Load **one chapter at a time** — ChapterManager already frees the previous
   chapter scene before loading the next (`load_chapter_scene`).
9. The GLB-preferred chapter base falls back to the procedural build if a `.glb`
   has not been imported yet, so first load never hard-fails.

## Audio

10. Compress music/ambient to OGG; avoid huge background tracks.

## Build & test

11. Export: `tools/build/build_web.sh` (needs a Godot 4 binary + the "Web" preset).
12. Test locally: `cd build/web && python3 -m http.server 8080` → http://localhost:8080
13. Verify in Chrome, Edge, and Firefox.

## Single-threaded note

The project is configured single-threaded for web (see the deploy notes); this
avoids the COOP/COEP cross-origin-isolation requirement on static hosts.
