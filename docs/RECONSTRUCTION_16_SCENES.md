# 16-Scene Reconstruction from《合并重构天路历程》

Reconstruction of the game's 16 scenes guided by the attachment design doc
*合并重构天路历程* (Batches 1-6, Skills 1-48). The attachment is written for a
React/TypeScript/Three.js rewrite; this game is the existing Godot 4 project. So
the attachment was used as a **design source**, mapped onto the existing engine —
**not** a rewrite. Where the current implementation was already as good or better,
it was left unchanged (per the brief: 如果原来的实现更好，则不需要改动).

中文摘要：附件是一份 React 版重构方案，而本项目是已上线的 Godot 工程。我们把附件的
**设计内容**（7 步叙事节奏、小教堂十字架系统、试探/悔改系统、每章属灵数值弧线）映射到
现有引擎，保留所有更好的原有实现，只做两类增量：补两座缺失的小教堂几何，和为 16 章
数据各加一个 schema 安全的 `design` 设计块。场景数量、顺序、存档、章节链全部不变。

---

## 1. Guiding finding

The current Godot game already implements almost everything the attachment
designs, using its own (well-integrated) vocabulary:

| Attachment system | Already in the engine as |
|---|---|
| 7-step rhythm (Arrival→…→Grace) | Implicit per scene: spawn → chapel/landmark → NPCs → COL_ hazard zones + dialogue temptation gates → dialogue choices → effects → chapel worship + `TRIGGER_Exit_*` |
| Chapel-cross hub | `PROP_Chapel` worship interactable in 13/16 scenes (now 15/16) |
| Spiritual stats | `SpiritualStateManager` — faith/hope/humility/discernment/perseverance/watchfulness + despair/shame/fear/pride/deception/weariness |
| Temptation engine | Code resistance types + `COL_*` hazard zones + dialogue `conditions.temptation` |
| Repentance | humility-gated + chapel worship + `data/spiritual_events/*` |
| Armor of God | `PROP_ArmorStand`/`PROP_Sword`/`PROP_Shield` + `has_armor/has_sword/has_shield` |
| Apollyon / Giant Despair | `ApollyonBoss.gd` / `GiantDespair.gd` (phases, accusation, promise-key escape) |
| River depth, sleep, vanity pressure, journey review | `RiverDepthSystem`, `SleepinessSystem`, `VanityPressureSystem`, `JourneyReviewScreen` |

So the reconstruction is **surgical enrichment**, not replacement.

---

## 2. Stat / flag / temptation mapping (attachment → engine)

The attachment's stat names differ from the engine's. They were mapped, never
renamed in code. Engine numeric stats are the **only** legal effect keys:
`faith hope humility discernment perseverance watchfulness` /
`despair shame fear pride deception weariness`.

| Attachment | Engine | Note |
|---|---|---|
| vigilance | **watchfulness** | direct synonym |
| courage / witness | **perseverance** | steadfastness under fear / persecution |
| love | **humility** | other-centredness |
| doubt | **despair** | unbelief / loss of trust |
| worldliness | **deception** | the world's false shine |
| accusation | **shame** | Apollyon / Giant Despair |
| sleepiness | **weariness** | Enchanted Ground |
| burden (numeric) | *(not a stat)* | the `has_burden` bool token + `remove_burden` special at the cross |

Flags/items use the engine's `has_*` tokens (`has_scroll`, `has_armor`,
`has_sword`, `has_shield`, `has_promise_key`, `has_shepherd_map`,
`has_new_garment`, `has_final_seal`, `has_burden`). Temptation `type` values use
the engine's recognized set: `return_to_city, despair, comfort_shortcut, vanity,
shame, doubt, sleep, false_teaching, self_reliance, fear`.

---

## 3. What changed

### 3a. Geometry — two missing chapel-crosses added (`tools/scene_gen/scene_defs.py`)

The attachment explicitly designs a chapel-cross for the Slough and the Wicket
Gate; the engine left both barren. Both were added and all 16 GLBs regenerated
(`python3 tools/scene_gen/build_scenes.py`).

- **Slough of Despond** — `PROP_SunkenChapel_Silhouette` at `(-9.5, -4.1, -19)`:
  a half-submerged chapel whose nave is swallowed by the bog, only the weathered
  roof and the **cross** standing above the muck ("Out of the depths I cry" Ps 130).
  Named with the `Silhouette` skip-token so it is **non-solid** and off the safe
  stone path — a landmark of hope you cannot quite reach while struggling, *not* a
  save point (the Slough's mercy comes through `NPC_Help`, kept as-is). +`VFX`/`LIGHT`
  glow on the cross.
- **Wicket Gate** — a real `PROP_Chapel` at `(-4.2, 0, -11)` just inside the narrow
  way ("Enter through the narrow gate" Mt 7:13): a genuine worship/restore point at
  the threshold of the true road, set clear of the central road, the exit portal and
  the arrow-pressure zone. +`LIGHT` glow.

Node counts: Slough 98→101, Wicket 47→49. `verify_scenes.py` passes all 16; binder
behaviour confirmed (skip-token list line ~200; `PROP_Chapel` exact-match worship
binding line ~490). The other 14 scenes already met the attachment's chapel-cross
and landmark requirements and were left untouched.

### 3b. Data — a `design` block on every chapter (`data/chapters/*.json`)

Each chapter JSON gained one new top-level `design` key (added by the reproducible
`tools/data_gen/enrich_chapter_design.py`; re-runnable, idempotent). It encodes the
attachment's reconstruction of that scene, mapped to the engine vocabulary:

```
design:
  provenance         which attachment chapter/skill it comes from
  spiritual_layer    which of the 5 layers the scene exercises
  seven_beats        Arrival / Orientation / Encounter / Temptation / Choice / Consequence / Grace
  chapel             verse_zh, verse_en, hint_zh, restore_faith, type   (null where the scene has no chapel)
  primary_temptation type (engine key), hook, resisted_by
  repentance         where, restores {engine stat keys}, special[]
  key_choices        representative choices with effects mapped to engine stat keys
  stat_arc_note      the designed spiritual arc, in engine terms
  kept_original      (where applicable) why the current implementation is kept as-is
```

The chapter loader and `tools/validation/validate_data.py` both ignore unknown
keys, so this is **non-breaking**: all existing fields, ordering, completion
conditions, flag chains, routes and saves are untouched. The block documents and
grounds each scene's reconstruction and is available to any future objective/HUD
panel. All effect keys are validated against the legal stat set by the script
(`--check`).

---

## 4. The 16 scenes (attachment ↔ engine)

| # (route) | Engine scene | Attachment ch. | Chapel | Action |
|--:|---|---|:--:|---|
| 1 | city_of_destruction | Ch1 灭亡城 | ✅ ruined | design block |
| 2 | wilderness_road | *(original bridge)* | — | design block; barren kept |
| 3 | slough_of_despond | Ch2a 沮丧泥潭 | ✅ **new** sunken cross | + geometry, design block |
| 4 | wicket_gate | Ch2b 窄门 | ✅ **new** gate chapel | + geometry, design block |
| 5 | cross_and_tomb | Ch4 十架山 | ✅ calvary | design block (release via existing event) |
| 6 | interpreter_house | Ch3 讲解者之家 | ✅ gate | design block; order kept (see §5) |
| 7 | hill_difficulty | Ch5 艰难山 | ✅ pilgrim | design block |
| 8 | palace_beautiful | Ch6 美宫 + Ch7 军装厅 | ✅ pilgrim | design block (armory folded in) |
| 9 | valley_humiliation | Ch8 降卑谷 + Ch9 亚玻伦 | ✅ pilgrim | design block (boss kept) |
| 10 | valley_shadow_death | Ch10 死荫谷 | ✅ ruined | design block |
| 11 | vanity_fair | Ch11 虚华市 + Ch12 殉道 | ✅ trial | design block (trial/martyrdom folded in) |
| 12 | doubting_castle | Ch13 疑惑堡 | ❌ (crosses only) | design block; no-chapel kept |
| 13 | delectable_mountains | Ch14a 可喜山 | ✅ pilgrim | design block |
| 14 | enchanted_ground | Ch14b 魔睡地 | ✅ pilgrim | design block |
| 15 | river_of_death | Ch15 死河/美地 | ✅ river | design block |
| 16 | celestial_city | Ch16 天城 | ✅ celestial | design block |

---

## 5. Deliberate deviations kept (original judged better / structurally required)

- **Scene list & order unchanged.** The attachment merges Slough+Wicket and
  Delectable+Enchanted and adds standalone Armory / Martyrdom / Apollyon chapters.
  The engine keeps them as distinct scenes; reordering/merging would break the
  `required_flags` chain and saves. Per the brief, the existing structure is kept.
- **Interpreter after the Cross.** Bunyan and the attachment place Interpreter's
  House (Ch3) *before* the cross (Ch4); the engine wires it after (its
  `required_flags: [burden_fallen]` gate). Kept, to preserve the flag chain; noted
  in that chapter's `design.kept_original`.
- **Wilderness Road stays barren** (not one of the attachment's 16; austere by design).
- **Doubting Castle keeps no chapel** — matching the attachment: despair is answered
  by the remembered Promise (`has_promise_key`), not a save room. Only faint crosses.
- **Slough's mercy stays the `NPC_Help` rescue;** the new sunken cross is a hope
  landmark, not a competing save point.

---

## 6. Regenerate & verify

```bash
python3 tools/scene_gen/build_scenes.py            # rebuild all 16 GLBs
python3 tools/scene_gen/verify_scenes.py           # 16/16 technical-object coverage
python3 tools/data_gen/enrich_chapter_design.py    # (re)write the design blocks
python3 tools/data_gen/enrich_chapter_design.py --check   # stat-key legality only
python3 tools/validation/validate_data.py          # routes→chapters→quests→dialogues
```

All pass. `tools/validate_assets.py` still reports 16 pre-existing `assets/scenes/*.png`
"missing" entries — unrelated to this work (scene art ships as `.jpg`; the validator
looks for `.png`). No `.gd` was modified.
