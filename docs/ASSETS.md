# Asset Pack — music, ambience, SFX, art, portraits & animation

This document describes the original asset pack that now ships with *Pilgrim's
Road — Burden Fallen*, how it is wired into the engine, and how to regenerate or
replace it.

All assets are **100% original** and generated procedurally by the scripts in
`tools/`. No samples, stock imagery, fonts, or third‑party art are used. Themes
and characters derive only from John Bunyan's *The Pilgrim's Progress* (1678),
which is in the public domain.

## What ships

| Category | Count | Location | Format |
|---|---|---|---|
| Chapter music loops | 16 (+`title`) | `assets/audio/music/` | `.ogg` (Vorbis, stereo, seamless loop) |
| Chapter ambience beds | 16 | `assets/audio/ambient/` | `.ogg` (seamless loop) |
| Sound effects | 19 | `assets/audio/sfx/` | `.ogg` (9 core + 8 gameplay + 2 chat: message_in, mention) |
| Ground textures | 16 | `assets/textures/ground/` | `.png` (512², tileable) |
| Particle sprites | 4 | `assets/textures/particles/` | `.png` |
| Chapter splash / backdrops | 16 | `assets/scenes/` | `.png` (1280×720) |
| Character portraits | 12 | `assets/characters/` | `.png` (512×640) |
| UI key art + token icons | 6 | `assets/ui/` | `.png` |
| Animation flipbook sheets | 5 | `assets/anim/` | `.png` (8 frames each) |
| CJK UI font | 1 | `assets/fonts/` | `.otf` (Noto Sans CJK SC subset, OFL 1.1) |
| Chat sticker packs | 3 packs | `assets/ui/stickers/` | `.png` + `manifest.json` |

A machine-readable inventory (file names, durations, dimensions, frame counts)
is in [`assets/manifest.json`](../assets/manifest.json).

## How it is wired (all fail‑safe)

Every asset is **existence‑checked** before use. If a file is missing or fails
to load, the code falls back to the original procedural greybox / silence — the
project still runs with an empty `assets/` folder. This mirrors the original
`AudioManager` contract.

| System | File | Behaviour |
|---|---|---|
| Music + ambience | `scripts/core/AudioManager.gd` | Plays `music`/`ambient` paths from each chapter's JSON on `chapter_started`. Unchanged — assets simply fill the paths it already referenced. |
| SFX | `scripts/core/AudioManager.gd` | Event‑driven (`ui_select`, `quest_complete`, `burden_fall`, `cross_grace`, `collapse`, `victory`, `save`, …). |
| Asset loader | `scripts/core/AssetLib.gd` *(new)* | Static, existence‑checked getters: `ground()`, `scene_art()`, `portrait()`, `particle()`, `ui()`, `sprite_frames()`. Returns `null` on a miss. |
| Ground textures | `scripts/chapters/ChapterBase.gd` → `make_ground()` | Applies `ground/<chapter_id>.png` as the terrain albedo (tiled), tinted white; falls back to flat colour. |
| Particle sprites | `scripts/chapters/ChapterBase.gd` → `make_light_burst()` | Uses `particles/mote.png` for grace/prayer shimmer. |
| Dialogue portraits | `scripts/ui/HUD.gd` → dialogue box | Shows `characters/<speaker>.png` beside the speaker name; hidden if absent. |
| Chapter backdrop | `scripts/ui/HUD.gd` → title card | Draws `scenes/<chapter_id>.png` behind the chapter title, dimmed, fading with the card. |
| Grace animation | `scripts/ui/HUD.gd` → `_on_cross_grace()` | Plays the `grace_glory` flipbook overlay on the Cross grace event. |
| Title key art + music | `scripts/core/Main.gd` → `_show_title()` | Draws `ui/title_key_art.png` behind the menu and plays `music/title.ogg`. |
| Options screen | `scripts/core/Main.gd` → `_build_options()` | Reachable from title + pause: Master/Music/Ambience/SFX sliders + fullscreen toggle. |
| Volume control | `scripts/core/AudioManager.gd` | Routes players to **Music / Ambient / SFX** buses; `set_volume()/get_volume()` adjust bus levels live; persisted to `user://settings.cfg`. |

## Options / settings screen

A settings screen is reachable from both the **title menu** and the **pause menu**
(Options button). It provides live volume sliders for **Master, Music, Ambience,
and Sound FX** (with audible preview), plus a **Fullscreen** toggle. Choices are
saved to `user://settings.cfg` and restored on launch. Volume is implemented with
dedicated audio buses, so it affects everything routed to each bus — including
sounds that play later.

It also has a **Controls** section: **Mouse Look** sensitivity, **Controller
Look** sensitivity, and an **Invert Look Y** toggle (saved under `[input]`).
`PlayerController` reads these and re-reads live on `EventBus.settings_changed`.

### Camera & controller

The third-person camera now supports an optional **orbit**: hold the **right
mouse button** and move the mouse, or push the **right stick**, to swing the view
(yaw + clamped pitch); movement becomes camera-relative so WASD still feels right
when rotated. At rest the view is identical to the original fixed follow-cam.
Full **gamepad** bindings are registered at startup (`Main._ensure_input_actions`):
left stick / d-pad move, **A** jump, **X** interact, right stick look, and **A/B**
for menu accept/cancel so the title, pause, options, and dialogue screens are all
navigable with a controller.

No scene (`.tscn`) rewiring is required: the game builds everything in
GDScript, so the assets attach themselves the next time the project is opened in
Godot (which imports the new `.png`/`.ogg` files automatically).

## Per‑chapter music moods

The 16 tracks follow the mood plan for the pilgrimage (a blend of sacred/hymnal,
cinematic ambient, and minimal drones):

| Chapter | Mood |
|---|---|
| City of Destruction | Gloomy cinematic ambient — low strings, distant bell tolls |
| Wilderness Road | Oppressive road — slow pulse, low bass |
| Slough of Despond | Heavy, despairing — Phrygian, low drone, slow pulse |
| Wicket Gate | Mysterious, gentle, revelatory — suspended chords |
| Cross and Tomb | Sacred/hymnal — warm choir, bright major melody (the emotional high) |
| Interpreter's House | Curious, gentle, instructive |
| Hill Difficulty | Restrained cinematic tension, rising |
| Palace Beautiful | Warm sacred ambient, peaceful |
| Valley of Humiliation | Dark cinematic ambient + drone (Apollyon) |
| Valley of the Shadow of Death | Minimal drones, low, wind, faint hymn motif |
| Vanity Fair | Tempting, bustling but uneasy, odd rhythm |
| Doubting Castle | Minimal drones + dark ambient, oppressive, claustrophobic |
| Delectable Mountains | Open cinematic ambient — hope, morning |
| Enchanted Ground | Drowsy, hazy, unstable |
| River of Death | Deep, slow, solemn, hymn shadow |
| The Celestial City | Sacred cinematic — choir, golden, victorious yet solemn |

## CJK UI font

Chinese UI text (chat, player names, localized strings) needs a CJK‑capable font
or it renders as tofu (□□□). `scripts/ui/ThemeManager.gd` (autoloaded) applies the
first font found in `assets/fonts/` to the project‑wide theme via
`AssetLib.font()`, fully existence‑checked.

Shipped: `assets/fonts/NotoSansCJKsc-Subset.otf` — a **subset of Noto Sans CJK SC**
(SIL OFL 1.1, © Google; the font declares **no** Reserved Font Name, so subsetting
+ redistribution is permitted). It is trimmed to ASCII + Latin‑1 + CJK/fullwidth
punctuation + the full **GB2312** common‑Hanzi set (~6.7k chars, so arbitrary
everyday Chinese chat renders) + every non‑ASCII glyph used in the repo — ~7.9k
glyphs, ~3.4 MB. The OFL license ships alongside it as `LICENSE-NotoSansCJK.txt`.
To use a different font, drop any `.ttf`/`.otf` into `assets/fonts/` (it is picked
up automatically) or rebuild the subset with `tools/gen_font.py`.

## Chat sticker packs

The chat window (`scripts/ui/ChatPanel.gd`) shows built‑in sticker packs read from
`assets/ui/stickers/manifest.json` via `AssetLib.sticker_manifest()` /
`AssetLib.sticker(pack, name)`. Stickers are sent as lightweight
`sticker://<pack>/<name>` tokens — no upload, each client renders from its bundled
copy. Manifest schema:

```json
{ "packs": { "<pack_id>": { "label": "天路", "names": ["cross", "lantern", …] } } }
```

Shipped packs: **天路** (`pilgrim` — emblems: cross, lantern, scroll, key, crown,
dove, candle, shield, footprints, mountain, gate, heart — plus caption stickers),
**表情** (`faces`), and **心情** (`emote` — Chinese‑word reactions). `manifest.json`
is generated by **scanning the folders on disk**, so any pack/PNG you add by hand
is included automatically — `tools/gen_art.py stickers` regenerates the built‑in
art and rebuilds the manifest without dropping hand‑added packs.

## Regenerating the assets

The generators are deterministic (fixed seeds) and require only `numpy`,
`Pillow`, and `ffmpeg` (with `libvorbis`).

```bash
# Audio (groups can be run separately to keep each run short)
python3 tools/gen_audio.py music
python3 tools/gen_audio.py ambient
python3 tools/gen_audio.py sfx

# Art
python3 tools/gen_art.py ground      # ground textures + particles
python3 tools/gen_art.py scenes      # chapter backdrops
python3 tools/gen_art.py portraits   # cast portraits
python3 tools/gen_art.py ui          # title key art + icons
python3 tools/gen_art.py anim        # flipbook sheets
python3 tools/gen_art.py stickers    # built-in sticker art + manifest (scans disk)
# (or `all` for everything in one pass)

# CJK font subset (requires fontTools + a system Noto Sans CJK)
python3 tools/gen_font.py
```

Tweak the `MUSIC` / `PAL` / `CHARS` dictionaries at the top of each generator to
change moods, palettes, or characters.

## Replacing with your own art / audio

Because everything is path‑based and existence‑checked, you can drop in your own
files at any time with **no code changes** — just match the file name and
location (e.g. paint over `assets/scenes/cross_and_tomb.png`, or replace
`assets/audio/music/celestial_city.ogg` with a real recording). Keep the same
sprite‑sheet frame count (8, laid out horizontally) for the animation sheets, or
adjust the `hframes` argument where `AssetLib.sprite_frames(...)` is called.
