# 天路历程 · Pilgrim's Road (R3F)

A lightweight 3D web adaptation of *The Pilgrim's Progress* — 16 chapters,
spiritual stats, choices, temptation, repentance, chapels with crosses.

**Stack:** Vite · React · TypeScript · React Three Fiber · Zustand · TailwindCSS · JSON-driven content.

This is the React/Three.js rebuild (the new main line, replacing the Godot version).

## Run

```bash
cd web-r3f
npm install
npm run dev      # open the printed localhost URL
# npm run build  # production build  ·  npm run typecheck  ·  npm run preview
```

## Batch 1 — implemented & verified ✅

- Full project scaffold (configs, Tailwind, entry).
- `GameState` / `SpiritualStats` (14 stats) / `Chapter` / `Chapel` / NPC / dialogue types.
- `src/data/chapters.json` — all **16 chapters**; `chapels.json` — chapels for most chapters (7 types).
- Zustand store with **save / load / reset** (localStorage) + autosave on key actions.
- **FaithHUD** (faith/hope/vigilance/humility/burden/doubt/fear bars).
- **ChapterObjectivePanel** (quest objectives), **DialoguePanel** (multi-line + choices), **ChapelPanel** (pray / repent / read inscription).
- **ChapterSelect** (16-chapter menu, lock/complete states) + New Game / Continue.
- Playable **Chapter 1 · City of Destruction** R3F scene: low-poly city + wall + distant light, **ruined chapel with cross**, **Evangelist / Obstinate / Pliable** NPCs, **burden on the player's back** (shrinks with the burden stat), WASD movement, OrbitControls.
- First **spiritual choice** (leave / delay / argue) changes faith / burden / humility / doubt; accepting the call unlocks the city gate → Chapter 2.

Verified: `npm install` ✓ · `tsc --noEmit` ✓ (no errors) · `vite build` ✓ (636 modules).

## Batch 2 — implemented & verified ✅

Additive systems + data layered on Batch 1 (all pure `GameState → GameState`, wired through `store.mutate`).

- **Player identity stages** (`identitySystem`) — 10 stages (awakened → glorified) derived from flags + stats; drives the avatar's **visual state** (robe colour, glow, armour, burden) and a top-left **StatusStrip**.
- **NPC + dialogue system** — `npcs.json` (11 NPCs) + `dialogues.ts` extended with later-chapter dialogues + `getDialogueById`.
- **Spiritual-choice engine** (`spiritualChoiceSystem` + `choices.json`) — flag-gated, repeatable-aware; `SpiritualChoiceModal` shows prompt → option → consequence.
- **Temptation system** (`temptationSystem` + `temptations.json`) — Face → Resist/Yield; resistance via stats, counter-items, flags, or armour; `TemptationBanner`.
- **Repentance / restoration** (`repentanceSystem` + `repentanceEvents.json`) — grace-first; confession → grace outcome; `RepentanceModal`.
- **Inventory / items** (`inventorySystem` + `items.json`, 14 items) — use/consume, positive+negative effects; `InventoryPanel`.
- **Sacred armor (Eph. 6)** (`sacredArmorSystem` + `sacredArmor.json`) — six pieces, equip / full-set detection / temptation resistances / `grantFullArmor`.
- **Companions** (`companionSystem` + `companionAbilities.json`) — add/leave, abilities, and **Faithful martyred → Hopeful raised** helper.

Verified: `tsc --noEmit` ✓ (no errors) · `vite build` ✓ (**656 modules**, full output written).

## Batch 3 — implemented & verified ✅

In-game chapter progression + bespoke scenes for **Chapters 1–4** (no more bouncing to the menu between chapters).

- **SceneRouter** maps `sceneId → scene` (unbuilt chapters fall back to a `ComingSoonScene` placeholder, so nothing crashes).
- **`chapterFlow.ts`** drives per-chapter objectives + the advance condition/label; finishing a chapter calls `completeChapter` + `goTo` and continues in-game.
- **Chapter 2 · Slough of Despond + Wicket Gate** — sunken mire with stepping stones + sunken-cross chapel, **Help** pulls you out, **Pliable** turns back, **Goodwill** opens the narrow gate; slough-despair temptation + a perseverance choice.
- **Chapter 3 · Interpreter's House** — interior with the **fire secretly fed with oil** (grace), wall pictures, the **Interpreter** teaches before you go on.
- **Chapter 4 · Calvary Hill** — click the **great cross** to kneel → repentance event lifts the burden (rolls into the **empty tomb**), grants **New Garment + Scroll of Assurance**; cross + hill brighten once `burden_lifted`.
- **App menu** now launches any unlocked chapter at its main scene.

Verified: `tsc --noEmit` ✓ · `vite build` ✓ (**662 modules**, full output written).

## Batch 4 — implemented & verified ✅

Bespoke scenes for **Chapters 5–8** (Chapters 1–8 now play end-to-end).

- **Chapter 5 · Hill Difficulty** — steep narrow path up vs. the **Danger / Destruction** bypaths (signposts), the halfway **arbor** (sleep temptation that can lose your scroll); the climb choice unlocks the ascent.
- **Chapter 6 · House Beautiful** — columned hall, **couch of rest** (click to be restored), **Watchful / Piety / Charity**.
- **Chapter 7 · Armory** — six armor stands; the central pedestal **grants the full Armor of God** (`grantFullArmor`) — once received, the avatar shows armour and the StatusStrip reads 6/6.
- **Chapter 8 · Valley of Humiliation** — descending path between dark walls, a **bow-down spot** (humility), and a **distant bull-headed silhouette foreshadowing Apollyon** (full fight in Ch 9).

Verified: `tsc --noEmit` ✓ · `vite build` ✓ (full output written).

## Batch 5 — implemented & verified ✅

Bespoke scenes for **Chapters 9–12** (Chapters 1–12 now play end-to-end).

- **`bossSystem.ts`** — pure boss transforms: `canFightApollyon` (gates on the full armour) + `defeatApollyon` (sets `bosses.apollyonDefeated` + `defeated_apollyon`, lifts accusation/fear).
- **`components/three/CompanionParty`** — renders every active companion as a marker beside the pilgrim, so the party visibly grows (Faithful, then Hopeful).
- **Chapter 9 · Apollyon Arena** — fiery rift + drifting embers; **Apollyon as an armoured, winged, bull-headed demon** that recoils and dims as he's struck. **Raise the shield of faith → strike with the sword of the Spirit** (3 hits) to defeat him; the accusation temptation auto-surfaces and is resisted **only while armoured**. The pilgrim fights wearing the full armour.
- **Chapter 10 · Valley of the Shadow of Death** — near-black ravine, narrow path between open pits, a **Scripture-Lantern glow** that lights the next step (brighter if you carry the lantern), fear temptation; pressing on sets `crossed_shadow_valley`, then **Faithful** waits at the dawn-break and **joins the party**.
- **Chapter 11 · Vanity Fair** — gaudy market of booths (fame badge / title / silver / curios), **vanity masks**, gold lamps, a jeering crowd and a watching judge; **Faithful walks alongside**. "I only buy the truth" (or the booth choice) sets `refused_vanity_fame`. Hidden chapel off the street.
- **Chapter 12 · Trial & Martyrdom of Faithful** — court bench, the **dock** where Faithful stands trial, a **stake/pyre**, and a **chariot of fire**. Standing publicly with Faithful triggers the **martyrdom** (`faithful_martyred`, Witness Token, the chariot carries him up) → **Hopeful rises and joins** to take his place.
- Companion array stays in sync with the join-dialogue flags via idempotent scene effects; **flow chapters 9–12** wired (Ch 12 → Doubting Castle).

Verified: `tsc --noEmit` ✓ (no errors) · `vite build` ✓ (**672 modules**, full output written).

## Batch 6 — implemented & verified ✅ (all 16 chapters playable)

The final batch — bespoke scenes for **Chapters 13–16** + the ending + New Game+. **The whole journey now plays Ch 1 → 16 end-to-end.**

- **`bossSystem`** extended — `rememberKeyOfPromise` (grants the Key of Promise + lifts doubt/despair) and `escapeDoubtingCastle` (sets `escaped_doubting_castle` + `bosses.giantDespairDefeated`).
- **`endingSystem.ts`** — `buildEndingSummary` distils the run into milestones, virtue bars, companions, keepsakes, tallies (temptations resisted / chapel prayers / repentances), a score and a rank.
- **`gameStore.newGamePlus()`** — restart carrying a modest boon (faith/hope/vigilance) + the `new_game_plus` flag.
- **Chapter 13 · Doubting Castle** — grim keep, barred dungeon, **Giant Despair** with his club; the despair temptation auto-surfaces. **Remember the Key of Promise** → unlock the cell door (the door-bars swing open) and escape; Hopeful is imprisoned alongside.
- **Chapter 14 · Delectable Mountains + Enchanted Ground** — green peaks, **shepherds** who give the Shepherd-Map, a **spyglass** that glimpses the distant Celestial City, and the drowsy **Enchanted Ground** (sleep temptation); staying awake sets `resisted_enchanted_sleep`.
- **Chapter 15 · River of Death** — the river's **depth rises and falls live** with `(fear+doubt+despair) − (faith+hope)`; a depth gauge reads 脚踏实地 → 水将没顶, the river-step choice shifts it, and **Hopeful holds you up** as you cross (`crossed_river`).
- **Chapter 16 · Celestial City** — radiant gold gate, **shining ones** + gatekeeper; entering grants the **Crown of Life**, marks the chapter complete, and raises the **Ending Review** overlay (summary + **重走天路 New Game+** / return to menu).

Verified: `tsc --noEmit` ✓ (no errors) · `vite build` ✓ (**678 modules**, full output written).

## Batch 7 — polish pass ✅ (audio · art · mobile · bundle · combat · crosses)

Cross-cutting upgrades that lift every chapter at once, plus targeted combat reworks.

- **Procedural audio** (`systems/audio/AudioEngine.ts`, `store/audioStore.ts`, `systems/audio/sceneAudio.ts`) — a tiny Web Audio engine (no asset files): one-shot SFX (bell, sword, shield, fire, water, gate, victory, chime…) + a breathing **per-chapter ambient pad** tuned to each scene's mood. Unlocks on first gesture; 🔊 mute toggle (persisted). Toast/click/advance/combat all cue sound.
- **Atmosphere layer** (`components/three/Atmosphere.tsx` + `SceneFx.tsx`) — a registry keyed by sceneId renders a **gradient sky, drifting particles (embers / dust / fireflies / petals / mist / motes), light-shafts and accent lights** for all 16 scenes, from one place inside the Canvas.
- **Mobile / touch** (`store/inputStore.ts`, `components/TouchControls.tsx`) — an on-screen **virtual joystick** (shown on coarse-pointer / small screens) drives the Player alongside WASD; `touch-action: none`, responsive HUD. OrbitControls already handles touch rotate/zoom.
- **Bundle split** (`vite.config.ts` + lazy `SceneRouter`) — each chapter is a **code-split chunk** (~3–8 kB) and `three` / `react` are separate vendor chunks; the old 1.1 MB monolith is gone and the >500 kB warning is resolved.
- **Richer combat** (`systems/combatSystem.ts`, `store/combatStore.ts`, `components/CombatOverlay.tsx`, `components/three/FireDart.tsx`) — the **Apollyon fight** is now a volley duel: the boss telegraphs **fire-darts** you block with the shield of faith (timing) then **riposte** with the sword of the Spirit; boss HP + the pilgrim's resolve, 3 escalating phases, a mobile-friendly combat HUD (grace-first — resolve never drops to a lethal zero). **Giant Despair** (Ch 13) gains a pray-with-Hopeful **resolve struggle** that breaks his grip before the Key of Promise.
- **Crosses everywhere** (`components/three/WaysideCross.tsx`) — the **pilgrim's home** in Ch 1 now stands with a cross on its gable, and a **wayside cross** accompanies every other chapter (via the SceneFx registry).

Verified: `tsc --noEmit` ✓ (no errors) · `vite build` ✓ (**690 modules**; chunks split — `three-vendor` 737 kB, `react-vendor` 241 kB, app 91 kB, 16 per-chapter chunks; no size warning).

## Status — **complete**

All **16 chapters** are bespoke, playable scenes with a single continuous flow, an ending review, and New Game+, now with audio, per-chapter atmosphere, mobile controls, a code-split bundle, reworked combat, and the cross motif throughout.

## Structure

```
src/
  types/index.ts          # all shared types (forward-compatible with later batches)
  data/                   # chapters, chapels, npcs, items, sacredArmor, choices,
                          #   temptations, repentanceEvents, companionAbilities (+ dialogues.ts)
  store/                  # gameStore (zustand + mutate), state (initial + stat clamp), uiStore (3D↔DOM bridge)
  systems/                # pure GameState→GameState: identity, inventory, sacredArmor,
                          #   temptation, repentance, spiritualChoice, companion, boss, ending (+ _apply)
  lib/content.ts          # all data lookups + chapel effect constants
  components/             # FaithHUD, StatusStrip, Dialogue/Chapel panels, InventoryPanel,
                          #   SpiritualChoiceModal, RepentanceModal, TemptationBanner, EndingReview, ChapterSelect
  components/three/       # Chapel, Player (identity-driven robe/armour/burden), NPCMarker, CompanionParty
  scenes/                 # Chapter01…Chapter16 bespoke scenes + SceneRouter + ComingSoonScene
  game/Game.tsx           # Canvas + scene + HUD overlays + modals + Ending Review
  App.tsx                 # menu ↔ game
```
