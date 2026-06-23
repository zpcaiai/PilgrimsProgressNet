# Pilgrim's Road — "Burden Fallen"

An original Christian allegorical adventure RPG inspired by the **public-domain**
novel *The Pilgrim's Progress* by John Bunyan. Built in **Godot 4.x / GDScript**.

This is a clean-room, original implementation. No code, art, music, level layouts,
UI, or text from any existing game is used — only public-domain story themes and
high-level genre patterns (chapter-based pilgrimage, light platforming, symbolic
"enemies", spiritual choices, and an inner-state progression system).

## Status — content-complete

All **16 chapters** are playable end to end (City of Destruction → Celestial City)
with full gate-flag continuity and **no soft-locks**. The latest pass is a full
narrative-quality sweep across the complete pilgrimage:

- **Every chapter intro** now follows a clearer repentance-and-grace arc, from
  awakening under the burden to final welcome at the Celestial City.
- **Quest text and route data** now reflect the full 16-chapter journey rather than
  the earlier demo route.
- **Key dialogues** were rewritten for stronger moral conflict: Evangelist's call,
  Help in the Slough, the Wicket Gate, Apollyon's accusation, Hopeful's joining,
  Shepherds' counsel, and the collapse/repentance flow.
- **In-level prompts and toasts** now reinforce the chapter theme without changing
  the existing flags, quest flow, or mechanics.

An **original asset pack now ships** (music, ambience, SFX, ground textures,
chapter backdrops, character portraits, key art, and animation flipbooks — all
procedurally generated and wired in fail-safe; see [`docs/ASSETS.md`](docs/ASSETS.md)).
What remains is polish — replacing the painterly-placeholder art with hand-made
work and optional balancing — see *Suggested next tasks* at the end.

---

## How to run

1. Install **Godot 4.2+** (standard, not .NET) from https://godotengine.org/download
2. Open Godot → **Import** → select this folder's `project.godot`.
3. Press **F5** (Play). The title screen appears → **Begin the Journey**.

Everything is built **procedurally in GDScript** — there is no fragile editor
wiring to set up. Scenes are thin wrappers around self-building scripts, so the
project runs as soon as it is imported.

**Want a public web link?** A ready-to-use Web export preset is included. See
[`docs/DEPLOY_WEB.md`](docs/DEPLOY_WEB.md) — export from Godot, then upload the
`build/web/` folder to itch.io / GitHub Pages / Netlify / Vercel.

### Controls

| Action | Keys |
|---|---|
| Move | `W A S D` / Arrow keys |
| Jump | `Space` |
| Interact / talk | `E` |
| Dialogue choices | `1` `2` `3` `4` (or click) |
| Character / inventory | `C` |
| Route map | `Tab` |
| Pause menu | `Esc` |
| Combat (Valley / test arena) | `J` strike · `K` dodge · `L` stand firm · `U` promise · `P` pray |

---

## Two versions (chosen at the title screen)

- **Devout Journey (敬虔版)** — the standard difficulty described below.
- **Children's Journey** — a gentle mode aimed at ~10-year-olds, easy to finish.
  It keeps the whole story and all 16 chapters, but: negative feelings (despair,
  fear, weariness…) build at **half rate**, the burden/despair slow you only half
  as much, enemies and Apollyon are **weaker, slower, and hit softer**, the
  Enchanted Ground gives **twice as long** before sleep takes you, the Wicket-Gate
  arrows are rarer and slower, and the River of Death stays calm. The choice is
  saved, so **Continue** keeps your version.

## The journey (the full pilgrimage — 16 chapters)

The shipped route runs the whole allegory, **City of Destruction → … →
Celestial City**:

1. City of Destruction · 2. Wilderness Road · 3. Slough of Despond ·
4. Wicket Gate · 5. Cross and Tomb · 6. Interpreter's House · 7. Hill Difficulty ·
8. Palace Beautiful · 9. Valley of Humiliation · 10. Valley of the Shadow of Death ·
11. Vanity Fair · 12. Doubting Castle · 13. Delectable Mountains ·
14. Enchanted Ground · 15. River of Death · 16. The Celestial City.

The Cross (where the burden falls) is the emotional midpoint, not the end. Press
**Tab** any time for the route map, and **C** to see the pilgrim's heart
(every grace and burden, tokens, and companions).

Signature beats and mechanics:

Opening conversion arc (through the Cross):

1. **City of Destruction** — you start carrying a *burden* that slows you. Talk to
   your **Family**, then **Evangelist** (this unlocks the gate), weather
   **Obstinate** and **Pliable**, and leave through the eastern gate.
2. **Wilderness Road** — Obstinate makes a last appeal to turn back; press on.
3. **Slough of Despond** — mud raises **Despair** and slows you. **Promise stones**
   and **safe stones** relieve it; **Pliable** abandons you; **Help** can pull you
   out. Reach solid ground on the far side. If Despair hits 100 you collapse into a
   **repentance** prompt rather than a game-over.
4. **The Wicket Gate** — arrows of accusation chase you from behind, so keep moving.
   **Knock** at the gate; **Goodwill** receives you.
5. **The Cross and the Tomb** — climb the hill. The burden loosens, rolls into the
   tomb, and grace is given (Scroll, Seal, New Garment).

Then the road continues:

6. **Interpreter's House** — a safe hall of symbolic rooms; each lesson sharpens
   discernment and watchfulness.
7. **Hill Difficulty** — two easy paths (Danger, Destruction) mislead; the steep
   middle way is true and slow. A rest arbor tempts you to grow drowsy.
8. **Palace Beautiful** — rest, and take up the armour of faith from Watchful.
9. **Valley of Humiliation** — **Apollyon** blocks the way. Combat is live here:
   stand firm (`L`), pray (`P`), answer with promises (`U`) across his three phases.
10. **Valley of the Shadow of Death** — pitch dark. Your lantern of faith lights
    only a small circle; fear shrinks it, faith and lanterns of the Word restore
    it. Whispers raise fear. Keep to the narrow path.
11. **Vanity Fair** — a glittering market. Refuse its wares to build discernment;
    **Hopeful** joins you here and walks the rest of the road at your side.
12. **Doubting Castle** — imprisoned by Giant Despair. The key called *Promise*
    opens any door — find it, or remember you carried it all along.
13. **Delectable Mountains** — the Shepherds give counsel and show you the
    Celestial City through their glass.
14. **Enchanted Ground** — a heavy drowse drains watchfulness. Keep moving; let
    Hopeful's voice rouse you. Lie down and you wake further back.
15. **River of Death** — no bridge. The deeper your fear, the harder the water
    pulls; faith carries you across.
16. **The Celestial City** — walk the shining road to the gate. Journey's end.

A companion (**Hopeful**) follows from Vanity Fair on, easing despair and fear and
rousing you on the Enchanted Ground. State, flags, spiritual stats, the burden,
tokens, and companions all persist across chapters and through save/load.

**Storytelling.** Every chapter opens with crafted reflective narration (an inner
voice that sets the scene and draws the heart toward repentance), shown as fading
lines after the title card. The pivotal conversations are written as honest moral
crises rather than lectures: confession names the truth, repentance receives help,
and grace always does the lifting. The text stays a clean-room adaptation of
public-domain Bunyan themes; it does not copy dialogue or scenes from later films.

---

## Systems overview

| System | File | Role |
|---|---|---|
| EventBus | `scripts/core/EventBus.gd` | Global signal hub (autoload) |
| GameState | `scripts/core/GameState.gd` | Flags, inventory, companions, progress |
| SpiritualStateManager | `scripts/spiritual/SpiritualStateManager.gd` | The inner-formation model: faith/hope/humility/… vs despair/shame/fear/pride; derived movement penalty, visual darkness, temptation resistance, the Cross grace event |
| DialogueManager | `scripts/dialogue/DialogueManager.gd` | JSON branching dialogue with conditions, effects, flags |
| QuestManager | `scripts/quest/QuestManager.gd` | Flag-driven quest steps and rewards |
| ChapterManager | `scripts/chapters/ChapterManager.gd` | Linear route, chapter data, scene swapping |
| SaveManager | `scripts/save/SaveManager.gd` | `user://saves/slot_1.json` |
| PlayerController | `scripts/player/PlayerController.gd` | Self-building third-person pilgrim; burden/despair slow movement |
| ChapterBase | `scripts/chapters/ChapterBase.gd` | Procedural builders used by every chapter |

All content is **data-driven** under `data/` (chapters, dialogues, quests,
enemies, route). Spiritual effects flow through `SpiritualStateManager.apply_effects()`.

### Level mechanics (`scripts/level/`)
`MudZone`, `SafeStone`, `PromiseStone`, `FalseGround` (revealed by Discernment ≥ 30),
`ArrowEmitter`, `PlayerLight` (faith-driven lantern for the dark valleys),
`SleepField` (the Enchanted Ground drowse), and `Companion` (Hopeful, who follows
and encourages).

### Combat slice (`scripts/combat/`)
Symbolic, not damage-trading: enemies attack your inner state and **Resolve**; you
overcome them by **standing firm**, **praying**, and answering lies with **promises**.
Includes `SymbolicEnemy` (Fear/Shame/Despair), `PlayerCombat`, `BossController`, and
the three-phase `ApollyonBoss`.

---

## Testing

- **Full game:** F5 → Begin the Journey → play all 16 chapters to the Celestial
  City. Use **F7** to skip chapters quickly if you just want to reach a later beat,
  and **F8** to trigger the Cross grace early.
- **Combat:** play to the Valley, or open `scenes/core/CombatTestArena.tscn` and
  press F6 (Run Current Scene). Fight Fear/Shame/Despair; pick up a promise;
  **Summon Apollyon**.
- **Data validation:** press **F9** in-game. The output panel prints
  `Data validation passed.` or a list of issues.

### Debug shortcuts (in-game)

| Key | Effect |
|---|---|
| `F2` / `F3` | Despair +20 / Hope +20 |
| `F4` | Toggle burden |
| `F5` / `F6` | Save / Load |
| `F7` | Skip to next chapter |
| `F8` | Trigger Cross grace |
| `F9` | Validate all data |
| `Esc` | Return to title |

---

## Known limitations

- An **original asset pack now ships** under `assets/` — 16 chapter music loops
  + 16 ambience beds + 17 SFX (`.ogg`), 16 tileable ground textures, 16 painterly
  chapter backdrops, 12 character portraits, title key art, token icons, and 5
  animation flipbooks. All are procedurally generated (see `tools/gen_audio.py`,
  `tools/gen_art.py`) and **100% original / public-domain-safe**. They are wired
  in **fail-safe**: every asset is existence-checked, so the project still runs
  if `assets/` is emptied, falling back to the greybox look and silence. See
  [`docs/ASSETS.md`](docs/ASSETS.md). The art is stylized "painterly placeholder"
  quality — a big step up from bare greybox, and trivially swappable for hand-made
  art by overwriting the matching file names.
- Visuals remain otherwise procedural: capsules and boxes with stylized
  lighting/fog, textured ground, particle VFX (cross/prayer/promise), portraits in
  dialogue, and per-chapter backdrops on the title card.
- Combat is a working, unbalanced slice. It is wired into the **Valley of
  Humiliation** chapter and the standalone test arena.
- GPU particles may appear faint or absent under the OpenGL compatibility
  renderer; the cross/celestial light pulses also use dynamic lighting so they
  always read.
- Flag design is kept deliberately simple so the route can always be completed
  (no soft-locks). `F7` skips chapters for testing.

## Suggested next tasks

1. Upgrade the shipped procedural asset pack (`assets/`, see `docs/ASSETS.md`)
   with hand-made low-poly props and recorded/composed audio — just overwrite the
   matching file names; all paths are wired and existence-checked.
2. Balance and expand combat: more enemy behaviours, add fights to the dark
   valleys, and add the retreat/repentance loop inside the boss fight.
3. An **Options screen** now ships (title + pause): Master/Music/Ambience/SFX
   volume sliders, **mouse-look + controller-look sensitivity**, invert-Y, and a
   fullscreen toggle, persisted to `user://settings.cfg`. **Gamepad support** is
   wired (stick/d-pad move, A jump, X interact, right-stick camera orbit, A/B menu
   nav), and the camera now supports optional right-mouse / right-stick orbit.
4. Localization pass — all player-facing text already lives in JSON dialogue and
   chapter data, ready to be translated.

---

*Themes and characters are drawn from John Bunyan's* The Pilgrim's Progress *(1678),
which is in the public domain.*
