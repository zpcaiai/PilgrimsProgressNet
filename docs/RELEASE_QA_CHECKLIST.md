# Performance, Build, Release & Final QA

Batch 7 · Skill 56, adapted to the **Godot 4 web export** (not Vite/React). The
game already ships as a Godot HTML5 build (`index.html` + `index.wasm` +
`index.pck`) deployed via Vercel, with the backend on a Hugging Face Space.

## Performance targets (web)

| Target | Goal |
|---|---|
| First playable | < ~6 s on a mid-range laptop browser |
| Per-scene tris | keep low-poly; scenes are generated low-poly by `tools/scene_gen` |
| Desktop browser | 60 FPS; **low-graphics** mode 30 FPS on weak GPUs |
| Single GLB | the 16 scene GLBs are ~0.3–1.2 MB each (well under 5 MB) |
| Build size | `index.pck` ~30 MB; keep total reasonable for web |

## Performance strategy (Godot specifics)

- **One scene at a time.** Chapters load their own GLB on entry (`GlbChapter` /
  `ChapterManager`), never all 16 at once.
- **Low-graphics mode.** Drive `scripts/render/RenderConfig.gd` /
  `PainterlyPostFX` from `Settings.graphics_quality`: on low, drop glow/bloom,
  reduce particles, shadows, and draw distance. Web export already chooses the
  `gl_compatibility` renderer (see the web-export notes); `forward_plus` is for
  desktop.
- **Audio streams.** Music/ambient `.ogg` are streamed loops (`AudioManager`);
  SFX are short one-shots. Volumes via `Settings` / `[audio]`.
- **Distant set-pieces** (Celestial City, far hills, city walls) stay low-poly /
  billboard-style; decorative scatter uses binder skip-tokens so it is non-solid
  and cheap.
- **Particle caps.** Vanity Fair, the Cross light shafts, fire/fog, and Celestial
  glory all keep bounded emitter counts.
- **Data is JSON, loaded per need.** `data/` (chapters, dialogues, teaching guides,
  audio plan, palettes) is small text; fine to load at runtime.

## Build & release

```bash
# 1. regenerate generated content (pure Python, no Godot needed)
python3 tools/scene_gen/build_scenes.py          # 16 scene GLBs
python3 tools/data_gen/enrich_chapter_design.py  # chapter design blocks
python3 tools/data_gen/build_teaching_guides.py  # teaching guides
# 2. static checks (sandbox / CI; no Godot binary required)
~/.local/bin/gdparse <each scripts/**/*.gd>      # GDScript parse
python3 tools/scene_gen/verify_scenes.py         # scene marker coverage
python3 tools/validation/validate_data.py        # routes→chapters→quests→dialogues
python3 tools/validate_assets.py                 # asset presence (see note below)
# 3. export (needs the Godot 4 editor/headless on a real machine)
godot --headless --export-release "Web" build/web/index.html
# 4. deploy: push the web build to Vercel (see docs / vercel.json)
```

Note: `tools/validate_assets.py` currently reports 16 `assets/scenes/*.png`
"missing" — pre-existing; the scene art ships as `.jpg`, so this is a validator
naming mismatch, not a release blocker.

## Settings (the production options surface)

`scripts/core/Settings.gd` persists to `user://settings.cfg`. Today:
`reduce_motion`, `colorblind`, `seen_controls`, and **`teaching_mode`** (Batch 7).
Recommended additions for the Options screen (P1): `language` (zh/en — already
switchable via `LocaleManager`), `graphics_quality` (low/medium/high →
`RenderConfig`), `music_volume`, `sfx_volume`, `subtitles`.

## Final QA matrix

**Systems**
- [ ] New game / continue / multi-slot save & load (`SaveManager`)
- [ ] Chapter select (story unlock; teaching/debug jump)
- [ ] Dialogue, spiritual choices, temptation gates, repentance
- [ ] Chapel worship (all kinds), items, armour (`has_armor/sword/shield`)
- [ ] Apollyon boss; Giant Despair capture + promise-key escape
- [ ] Companions (Faithful martyrdom → Hopeful joins)
- [ ] Journey review at the Celestial City
- [ ] Teaching Mode: F1 opens the guide; auto-show on chapter complete; Esc closes
- [ ] Bilingual zh/en throughout

**Chapters** — each of the 16 completable and exits to the next:
- [ ] city_of_destruction [ ] wilderness_road [ ] slough_of_despond [ ] wicket_gate
- [ ] cross_and_tomb [ ] interpreter_house [ ] hill_difficulty [ ] palace_beautiful
- [ ] valley_humiliation [ ] valley_shadow_death [ ] vanity_fair [ ] doubting_castle
- [ ] delectable_mountains [ ] enchanted_ground [ ] river_of_death [ ] celestial_city

**Performance**
- [ ] Low-graphics mode runs on a weak GPU
- [ ] Scene transitions don't hitch/lock
- [ ] Music crossfades without pops
- [ ] Saves never lost across reload

**Teaching Edition**
- [ ] Any chapter's guide opens (F1) and shows summary/theme/scripture/Q&A/notes/prayer
- [ ] Audience-tiered questions display correctly
- [ ] (When wired) a reflection exports to Markdown
- [ ] Teaching mode never corrupts story-mode saves
