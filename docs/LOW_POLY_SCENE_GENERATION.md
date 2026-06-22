# Low-Poly Scene Generation

The sixteen chapter worlds are **generated**, not hand-modelled. A single set of
layout definitions describes every object and marker in each scene, and two
interchangeable backends turn those definitions into the same GLB files:

- **Blender backend** — runs inside Blender via `bpy`, builds real Blender
  objects, and exports with Blender's glTF exporter. Use this when you want to
  open, tweak, or art-pass the scenes in Blender.
- **Dependency-free backend** — a small pure-Python glTF writer (no Blender, no
  pip installs) that emits the identical GLBs. Use this in CI, on a headless
  box, or any time Blender is not available.

Both consume the same `tools/scene_gen/scene_defs.py`, so they stay in lockstep:
a box defined once is the same box in both outputs.

## Files

```
tools/scene_gen/
  glb_lib.py        Pure-Python glTF 2.0 / GLB writer + primitive math + Scene API
  scene_defs.py     The ten chapter layouts (shared by both backends)
  build_scenes.py   No-Blender generator -> assets/imported_scenes/*.glb
  verify_scenes.py  Coverage + structural validation (CI gate)
tools/blender/
  blender_scene.py                       bpy backend implementing the Scene API
  generate_pilgrim_mvp_scenes.py         Chapters 1-5
  generate_pilgrim_vslice_scenes.py      Chapters 6-10
  generate_pilgrim_endgame_scenes.py     Chapters 11-16
  export_all_glb.py                      All 16
docs/
  SCENE_NAMING_CONVENTIONS.md         Prefix legend + binder mapping
```

Output: `res://assets/imported_scenes/<chapter_id>.glb` for all sixteen chapters.

## Regenerate without Blender (recommended for a quick rebuild)

```bash
python3 tools/scene_gen/build_scenes.py     # writes all 10 GLBs
python3 tools/scene_gen/verify_scenes.py    # checks names + GLB structure
```

`build_scenes.py` uses only the Python standard library. `verify_scenes.py`
fails (non-zero exit) if any chapter is missing one of its spec "Technical
Objects" or if a GLB is malformed, so it is safe to run in CI.

## Regenerate with Blender (for art passes)

```bash
blender --background --python tools/blender/export_all_glb.py
# or just the MVP / vertical-slice halves:
blender --background --python tools/blender/generate_pilgrim_mvp_scenes.py
blender --background --python tools/blender/generate_pilgrim_vslice_scenes.py
```

The driver scripts set `scene_defs.Scene = BlenderScene`, so the same layout code
runs against Blender. To hand-edit a scene, run the generator, model in Blender,
then export the GLB over the generated file — keep node **names** intact so the
binder still wires gameplay (see `SCENE_NAMING_CONVENTIONS.md`).

## How it works

1. `scene_defs.py` describes each chapter by calling a tiny `Scene` API:
   `ground`, `box`, `cylinder`, `cone`, `pyramid`, `composite`, `zone`,
   `marker`. It imports only `glb_lib`, so it has no heavy dependencies.
2. The chosen backend implements that API:
   - `glb_lib.Scene` accumulates geometry into a glTF buffer and writes a `.glb`.
   - `blender_scene.BlenderScene` creates `bpy` meshes/empties and exports.
3. Geometry is **flat-shaded low-poly triangle soup** — each face carries its own
   normal — so the in-engine painterly/PBR lighting (`ChapterArtProfiles` +
   `PainterlyPostFX`) reads each facet as a clean painted plane. Materials are
   flat base colours; the engine supplies light, fog, and grade.
4. Godot imports each GLB as a tree of `Node3D` (markers) and `MeshInstance3D`
   (geometry) whose names are preserved exactly. `ImportedSceneBinder.gd` then
   attaches gameplay by name prefix at runtime.

## Design notes

- **Markers** (`NPC_/SPAWN_/CAM_/VFX_/LIGHT_/PATH_`) are empty nodes — position
  and orientation only.
- **Zones** (`TRIGGER_/COL_`) are transparent boxes whose size *is* the volume;
  the binder reads the box extent for its `CollisionShape3D` and hides the mesh.
- **Composite props** (e.g. a cottage = walls + pyramid roof) are an empty parent
  carrying the gameplay name, with child meshes named `VIS_*` that the binder
  always ignores.
- The pure-Python GLBs are small (≈20–70 KB each) and web-export friendly.

## Re-import in Godot

Godot auto-imports new/changed `.glb` files on focus. If a scene does not appear
to refresh, delete the matching `.godot/imported/<file>-*.scn` cache entry and
let Godot re-import, or re-open the project.
