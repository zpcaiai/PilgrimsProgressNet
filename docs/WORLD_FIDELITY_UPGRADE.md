# World Fidelity & Living-Worlds Upgrade

Raising the scenes from greybox toward dense, alive, cinematic worlds — people,
shops, goods, flora, fauna, water — and a Celestial City you *walk into* (the
crowned Lord, angels, the saints, the marriage feast) instead of a hard cut to
credits. Flagship pass: **City of Destruction** (visual + narrative), then the
two most-detailed asks — **Vanity Fair** and the **Celestial City** — plus a
**Delectable Mountains** pasture as the nature exemplar, on reusable helpers so
the rest roll out the same way.

## The honest ceiling (set expectations)

True "infinitely real, cinematic real-time" is **not** reachable in this build:
Godot web export runs the **Compatibility (WebGL2)** renderer only — Forward+/
Mobile (and anything Nanite/Lumen/path-traced) can't run in the browser; WebGPU
is early beta (2026) and even then is Forward+, not photoreal. Photoreal also
fights the allegory's tone. So the target is **rich, stylized, cinematic** —
dense low-poly geometry + real PBR materials + atmosphere + population. Within
that, the jump is large and real.

## The biggest lever: use the PBR library that already existed

`tools/gen_pbr.py` ships a photoreal-leaning PBR set (albedo/normal/rough/AO) for
~17 surfaces, and `MaterialKit.gd` maps names → full materials — but the scenes
were flat-coloured boxes (`"tex"` used 3 times). Fixes:
- `glb_lib.PBR_TEX` broadened from 5 → 16 surfaces (brick, stone, cobble, wood,
  rooftile + mossy_stone, marble, ash, dry_earth, mud, sand, grass, foliage,
  bark, gold, cloth) so any primitive can bake real albedo+normal.
- Boxes already bevel by default; `_road` gained a `tex` arg.

## City of Destruction (flagship: visual + narrative)

- **PBR + detail**: cobbled streets/square, mossy-stone walls, a stone city gate
  (keystone, iron-banded posts, gate lantern — opening kept clear), plus new
  textured props: a proclamation board, market stall, dry well, broken cart,
  rubble heaps, street lanterns, a dead tree, dry-earth cracks. 46 → 83 nodes.
- **Cinematic atmosphere**: a layered burning skyline + fire-wall glow behind,
  ember fields, smoke/ash fall, ground fog, god-ray shafts, lantern glows.
- **Narrative**: deepened `wife_concern` (the children/home pressure, an
  invitation to come along) and a new **Proclamation Board** beat
  (`city_proclamation` — the city's official denial), wired through a new
  `TRIGGER_ProclamationRead`. The Evangelist beat was already 9-node deep — kept.
- Every original gameplay marker preserved (NPCs, book, chapel, triggers, exit).

## Reusable life & population helpers (`scene_defs.py`)

Deterministic (name-seeded, no imports) so rebuilds are identical:
`_crowd` (dense figures — non-solid "Crowd" so you walk through the throng),
`_person_parts`, `_market_goods`, `_shop` (booth + counter + awning + wares +
keeper), `_flora` (flowers/grass/fern), `_fauna` (sheep/dog/bird),
`_feast_table` (the marriage supper), `_angel` (winged, radiant), and
`_enthroned_lord` (the crowned Lord in glory — reverent and symbolic: a radiant
white-and-gold figure, gold crown, halo, hand of welcome, on a gilded throne
under a shaft of glory, with the Lamb at its foot; face left to light, no literal
features).

## Celestial City — walked, not cut to "剧终"

The gate used to fire the credits instantly. Now the gate **opens into a real
walkable interior** and the finale is reached by walking the City:
- Interior: marble floor + aisle, the **crowned Lord enthroned** in a shaft of
  glory + the Lamb, **6 ranks of angels**, **8 crowds of white-robed saints**
  (~96 figures) rejoicing, **4 long feast tables** (the marriage supper), the
  **river of life** (wade-through) and the **tree of life**.
- Flow (binder): `TRIGGER_EnterCelestialCity` = welcome only (sets `entered_city`,
  no credits) → `TRIGGER_FeastWelcome` = the saints' greeting at the supper
  (`celestial_feast_welcome` dialogue, pointing on to the throne) →
  `TRIGGER_ThroneWorship` = the true finale (sets `journey_completed` +
  `show_journey_review` + `show_credits`). Chapter still completes on
  `entered_city`; the route's `journey_completed` now lands at the throne.

## Vanity Fair — a teeming fair

75 → 117 nodes: 6 merchant **shops** lining the street (silks, goldsmith, wines,
relics, trinkets, masks — each with wares + a keeper), **goods heaped** on every
stall, hawkers' **wares-carts**, and **10 more crowd clusters** (~120+ extra
fairgoers, non-solid). All original markers (merchants, trial, Faithful/Hopeful,
zones, exit) preserved.

## Delectable Mountains — a living pasture (nature exemplar)

A grazing **flock of sheep**, a **shepherd's dog**, scattered **wildflowers**,
**grass tufts**, and **birds** — all non-solid (Sheep/Foliage/Flower/Grass/Crow
skip-tokens). This is the pattern for populating the other nature scenes.

## Living-worlds rollout — COMPLETE (all 16 scenes)

The "populated world" pass is now applied to every chapter, not just the four
flagships. New reusable life helpers in `scene_defs.py` — `_bird` (heron, duck,
swan, dove, peacock, owl, raptor, songbird/lark/kingfisher), `_critter` (frog,
toad, dragonfly, butterfly/moth, fish, deer, fox, hare, midge-cloud, bat) and
`_household_figure` — plus six new non-solid binder skip-tokens (`Fauna`,
`Critter`, `Household`, `Dove`, `Butterfly`, `Firefly`) so **all 144 ambient-life
nodes are walk-through** (verified: 0 of them resolve to solid). Per scene:

- **river_of_death**: herons in the shallows, ducks + gliding swans, kingfisher,
  larks, dragonflies, fish ripples, riverbank marsh `_flora`, doves rising to the
  far celestial shore.
- **slough_of_despond**: stalking herons, frogs/toads on the logs, dragonflies,
  midge clouds, lapwings, a gliding crow, marsh ferns; `mud` tex on the basin.
- **palace_beautiful**: servants at the feast, family/guest clusters, a praising
  choir, the porter's lad, peacocks + court doves, the house-dog; `marble` hall/
  court floors, `wood` dining table.
- **interpreter_house**: two listening pupils, a hearth servant, perched robins,
  the dozing house-dog; `wood` hall floor.
- **hill_difficulty**: larks in the pines, a wheeling hawk, hares in the scree,
  deer on the summit, alpine `_flora`.
- **cross_and_tomb**: butterflies over the blossoms, returning songbirds, a white
  lamb by the empty tomb, a meadow hare.
- **wicket_gate** (restrained): two birds on the ravine rocks, a waiting dove, a
  hare, tufts in the cracks.
- **enchanted_ground**: a half-asleep deer, an owl on the dream-arbor, pale moths,
  extra fireflies, a folded hare — the drowsy hush kept.
- **doubting_castle**: vultures over the bailey + moat toads (grim) vs. larks,
  bright butterflies and a hare in the deceptive By-Path meadow.
- **valleys** (austere by design): only carrion birds over Apollyon's field; bats
  and faint watching eyes in the Shadow — nothing on the path.
- **wilderness_road** (new light dresser; City stays the undressed flagship): a
  lone fox, carrion crows, hares, dry verge tussocks.

Convention held throughout: central path + every gameplay marker kept clear,
clutter to the verges, skip-token names on anything that must not block.

## Verification & performance

`build_scenes.py` (16 GLBs) ✓, `verify_scenes.py` 16/16 ✓, `validate_data.py` ✓,
`gdparse` all `.gd` ✓, and a `_is_solid` audit confirming all 144 ambient-life
nodes are non-solid ✓. Heaviest GLBs are still Celestial City ~2.7 MB and Vanity
Fair ~2.8 MB (the untouched flagships); every newly-populated scene stays ≤1.3 MB (more geometry + crowds + baked textures) — within the <5 MB single-GLB
target but worth watching; the low-graphics path (`RenderConfig` / crowd density)
can trim them for weak GPUs. Visual quality is iterative and best judged in the
Godot editor — this pass builds correct, regenerated, marker-safe scenes; the
final art polish wants your eyes on screen.
