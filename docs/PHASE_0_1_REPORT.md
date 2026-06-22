# Phase 0–1 Report — Data Foundation (+ Phase 4 asset head-start)

Per the guidance to take the stable route — **file tree + JSON + DataValidator first,
not scenes-and-gameplay at once** — this pass delivers the data foundation for the
full 16-chapter route, with the Blender→GLB asset pipeline completed alongside it
(it is asset generation, not gameplay wiring).

## Validation status

```
python3 tools/validation/validate_data.py   ->  PASS (0 errors, 113 data files)
python3 tools/scene_gen/verify_scenes.py     ->  PASS (16/16 scenes, names + GLB OK)
```

- `full_route.json` references 16 valid chapters.
- All 16 chapter JSONs reference valid quest ids and now carry `imported_scene_path`.
- All 16 referenced `.glb` files exist, so the in-engine `DataValidator` file check passes too.
- All new/changed GDScript parses clean (gdtoolkit `gdparse`).

## Data foundation (Phase 1)

- **Routes** — `data/route/full_route.json` (rewritten to Batch 4), plus new
  `mvp_route.json` and `vertical_slice_route.json`.
- **Chapters** — existing 16 preserved; only the missing `imported_scene_path`
  field was added (existing `intro` / `on_*_flags` / effects untouched).
- **Quests** — existing 16 left as-is (already coherent: every chapter → a real quest).
- **New placeholder categories** — `items/` (11), `companions/` (hopeful, faithful,
  pliable), `hazards/` (16), `spiritual_events/` (14), `interactables/` (8), plus a
  `shadow_whisper` enemy and four endgame dialogues
  (`final_gate_entry`, `hopeful_cell_encouragement`, `hopeful_keep_awake`,
  `river_memory_recall`). Nothing existing was overwritten.

### Validators / tools

- `scripts/core/DataLoader.gd` — static JSON category loader.
- `scripts/core/DataValidator.gd` — **extended in place** (kept its static API);
  now also validates `imported_scene_path`, interactables, hazards, items,
  companions, dialogue `special` actions and companion interventions.
- `tools/validation/build_data_foundation.py` — reproducible, idempotent builder.
- `tools/validation/validate_data.py` — headless mirror of `DataValidator.gd`.

> Note: `DataValidator` stays the project's existing static utility (not an
> autoload), so call sites are unchanged. Wiring the *new* managers
> (SpiritualEventManager, RouteManager, CompanionManager, …) as autoloads is
> deferred to Phase 2 to keep the live project loading cleanly.

## Asset pipeline (Phase 4 — completed as a head-start)

- `tools/scene_gen/glb_lib.py` — dependency-free glTF 2.0 / GLB writer (stdlib only).
- `tools/scene_gen/scene_defs.py` — all **16** chapter layouts; every spec
  "Technical Objects" name is placed.
- `tools/scene_gen/build_scenes.py` / `verify_scenes.py` — generate + gate.
- `tools/blender/` — `blender_scene.py` (bpy backend) + mvp / vslice / endgame
  generators + `export_all_glb.py`. The Blender path reuses the same
  `scene_defs`, so its output matches the no-Blender output object-for-object.
- **Output:** 16 `.glb` in `assets/imported_scenes/` (~717 KB total — web-friendly).
- Docs: `LOW_POLY_SCENE_GENERATION.md`, `SCENE_NAMING_CONVENTIONS.md`.

## How to run / test

```bash
# Data foundation
python3 tools/validation/build_data_foundation.py   # (idempotent) author/refresh data
python3 tools/validation/validate_data.py           # gate: must print PASS

# Scenes (no Blender needed)
python3 tools/scene_gen/build_scenes.py             # writes 16 GLBs
python3 tools/scene_gen/verify_scenes.py            # gate: name coverage + GLB structure

# Scenes (in Blender, for art passes)
blender --background --python tools/blender/export_all_glb.py
```

In Godot, call `DataValidator.report()` (or `validate_all_data()`) to confirm in-engine.

## Phase 5 — GLB wiring (now done)

The greybox GLBs are now **driven as gameplay**:

- `scripts/import_pipeline/ImportedSceneBinder.gd` — walks each imported GLB and
  wires nodes by prefix (spawn, ENV collision, NPC dialogue, hazard zones, promise
  stones, cross grace, armor, prayer light, boss, exits, lights). Reuses the
  existing `MudZone/PromiseStone/FalseGround/ArrowEmitter/PlayerCombat/
  BossController/CombatHUD`; adds `BossEncounter.gd` to bridge the boss.
- `scripts/chapters/GlbChapter.gd` — chapter base that loads the GLB + binds, and
  **falls back to the original procedural build if the GLB is unavailable** (so the
  live game can never break). All 16 chapter scripts now `extends GlbChapter` with
  their old geometry preserved under `_build_procedural()`.
- **Closed-loop verified statically:** every scene has `SPAWN_Player_Start` + an
  exit/ending trigger; exit triggers set the chapter's existing completion flag from
  data and advance (cross/boss flags are required, not auto-set, so those beats still
  matter). All 646 GLB nodes use known prefixes the binder handles.
- **Runtime fixes:** `SpiritualStateManager` now handles every dialogue `special`
  (equipment, shepherd map, final seal, companions, prayer light, journey review,
  credits, generic `trigger_event`) and has `has_armor/sword/shield/shepherd_map/
  final_seal`; `GameState` gained temporary meters (vanity/sleep/river).

Static gates green: `gdparse` on all new/changed GDScript, data validation (0
errors), scene coverage (16/16), node-prefix coverage (16/16).

## Known limitations / honest gaps

- **Not playtested in-engine.** No Godot in this environment — correctness is by
  static parse + structural checks. First Godot open will import the 16 `.glb`
  (before that, chapters use the procedural fallback automatically).
- **Some bespoke mechanics are simplified.** Vanity-pressure / sleepiness / river-
  depth *meters* exist in `GameState` but aren't yet driven by per-frame systems;
  several minor flavor triggers bind as no-ops; a few minor NPCs are silent
  placeholders. The journey-review/credits screens are flagged, not yet built as UI.
- GLBs are intentional greybox; the painterly/PBR look is applied at runtime by the
  existing `ChapterArtProfiles` + `PainterlyPostFX`.

## Recommended next step

Open in Godot once to import the GLBs, then walk MVP (ch 1–5) to confirm the loop
end-to-end. After that: Phase 2 polish (dedicated meter systems + journey-review UI)
and filling the remaining placeholder dialogue/event content.
