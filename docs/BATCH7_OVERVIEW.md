# Batch 7 — Global Polish & Production Readiness (mapped to Godot)

The attachment's Batch 7 (Skills 49–56) is written for a React/R3F rewrite. This
game is the existing **Godot 4** project, which already implements most of those
systems. So Batch 7 was applied as **design content mapped onto the engine**,
keeping everything already better, and adding only what was genuinely missing.
See also: `RECONSTRUCTION_16_SCENES.md` (the Batch 1–6 scene work).

## Already in the engine (kept — not rebuilt)

| Skill | Attachment proposes | Already present (Godot) |
|---|---|---|
| 49 Art direction | colorPalettes / characterVisuals / visual bible | `docs/ART_BIBLE.md`, `ChapterArtProfiles.gd` (per-chapter sky/fog/tonemap/glow), `CharacterPalette.gd` |
| 50 Blender asset gen | Blender Python → GLB | `tools/scene_gen/scene_defs.py` + `glb_lib.py` — pure-Python GLB generator, **no Blender dependency** (better) |
| 51 Scene asset packs | per-chapter model/particle/lighting packs | scenes *are* the per-chapter GLBs; lighting/particles via `ChapterArtProfiles` |
| 52 Audio system | AudioManager + chapterMusicPlan + sfx | `AudioManager.gd` + 16 music + 16 ambient `.ogg` + 20 SFX, auto-loaded from chapter JSON |
| 53 Save/cloud | multi-slot save + cloud-ready | `SaveManager.gd` + `CloudSaveService.gd` |
| 56 Settings/perf | settings + low-graphics + build | `Settings.gd`, `RenderConfig.gd`/`PainterlyPostFX`, Godot web export + Vercel deploy |

## New in this pass

**Data (additive, schema-safe, static-checked):**
- `data/teaching_guides/*.json` ×16 — Sunday-school guides (story, theme,
  Scripture, audience-tiered questions, teacher notes, reflection, prayer).
  Built by `tools/data_gen/build_teaching_guides.py`.
- `data/audio/chapter_music_plan.json` — 16-chapter mood/style/tempo/instruments,
  referencing the real music/ambient files.
- `data/audio/sfx_catalog.json` — catalogue of the 20 real SFX (mirrors
  `AudioManager.SFX`) + design aliases for the attachment's proposed cues.
- `data/art_direction/color_palettes.json` — per-chapter palette reference
  (runtime source of truth stays `ChapterArtProfiles.gd`).

**Geometry:**
- `tools/scene_gen/scene_defs.py` — `_chapel` gained a `kind` parameter and the
  seven chapel variants (ruined / gate / calvary / pilgrim / trial / river /
  celestial); each chapter's chapel now uses its type. All 16 GLBs regenerated.

**Minimal GDScript (gdparse-clean, additive):**
- `scripts/ui/TeachingGuidePanel.gd` — autoloaded bilingual teaching overlay;
  auto-shows on `EventBus.chapter_completed` when teaching mode is on; **F1**
  opens it for the current chapter, **Esc** closes.
- `scripts/core/Settings.gd` — added `teaching_mode` (persisted) + setter.
- `project.godot` — registered the `TeachingGuidePanel` autoload.

**Docs:** `TEACHING_MODE.md`, `COMMERCIAL_STRATEGY.md`, `RELEASE_QA_CHECKLIST.md`,
this overview.

## Regenerate & verify

```bash
python3 tools/data_gen/build_teaching_guides.py        # + --check
python3 tools/scene_gen/build_scenes.py                # 16 GLBs (chapel variants)
python3 tools/scene_gen/verify_scenes.py               # 16/16 PASS
python3 tools/validation/validate_data.py              # PASS
~/.local/bin/gdparse scripts/ui/TeachingGuidePanel.gd scripts/core/Settings.gd
```

## Notes

- Story, scene list, ordering, routes and saves are unchanged. Everything here is
  additive.
- `scripts/chapters/ChapterArtProfiles.gd` shows an unrelated concurrent edit in
  the live workspace (a city-lighting tune) — not part of this work; left as-is.
- A couple of follow-ups were intentionally left as documented hooks (reflection
  Markdown export; teacher chapter-jump via `ChapterManager`) to avoid touching
  core navigation — see `TEACHING_MODE.md`.
