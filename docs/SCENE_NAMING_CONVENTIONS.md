# Scene Naming Conventions

Every chapter scene ships as a single low-poly **GLB** under
`res://assets/imported_scenes/<chapter_id>.glb`. Gameplay is wired up entirely
from **node names**: `ImportedSceneBinder.gd` walks the imported tree and, for
each node, looks at its name **prefix** to decide which gameplay script (if any)
to attach. Nothing in a scene needs to be hand-wired in the Godot editor.

Because of this, the prefix of an object's name is load-bearing. Renaming a node
changes its behaviour; misspelling a prefix makes the binder ignore it.

## Coordinate convention

- 1 unit = 1 metre.
- Forward / goal direction is **-Z**; the pilgrim spawns toward **+Z**.
- +Y is up.

## Prefix legend

| Prefix | Node type in GLB | Binder action |
|---|---|---|
| `ENV_` | mesh | Static environment. Collision added (`StaticBody3D` + trimesh/box) so the pilgrim walks on it. |
| `PROP_` | mesh or empty-group | Visual prop. Special names get behaviour (see below); everything else is decoration. |
| `NPC_` | empty | `NPCInteractable.gd`, dialogue resolved from the name. |
| `ENEMY_` | empty | Boss/enemy controller (e.g. `ENEMY_ApollyonBoss` → `ApollyonBoss.gd`). |
| `SPAWN_` | empty | `SPAWN_Player_Start` registers the player spawn point. |
| `TRIGGER_` | sized transparent box | An `Area3D`; behaviour from the name (exit / dialogue / story event / boss). The box size is the trigger volume. |
| `COL_` | sized transparent box | A hazard/zone volume: mud, fear, false ground, arrow pressure, arena bounds, etc. The box size is the zone extent. |
| `VFX_` | empty | Particle / shader effect marker; the binder spawns the matching effect. |
| `LIGHT_` | empty | The binder creates a Godot light (warm/cold/energy inferred from the name). |
| `CAM_` | empty | Cinematic camera marker, registered for scripted shots. |
| `PATH_` | empty | Ordered path point (e.g. the rolling-burden track at the Cross). |
| `VIS_` | mesh | **Reserved.** Child visual of a composite prop. The binder always ignores it. |

`TRIGGER_` and `COL_` nodes are emitted as transparent boxes precisely so their
**size carries the volume** — the binder reads the mesh AABB to size the
`CollisionShape3D`, then hides the visible box. Markers (`NPC_/SPAWN_/CAM_/VFX_/
LIGHT_/PATH_`) are empties (Node3D), positioned and oriented only.

## Special `PROP_`, `TRIGGER_`, `COL_`, `NPC_` names

The binder recognises these exact names (Batch 1 + Batch 2):

### Interactables / props
- `PROP_Book` → reads the warning book (fires the `receive_burden` event).
- `PROP_PromiseStone_*` → `PromiseStone.gd` (single-use relief stone).
- `PROP_Cross` → `CrossInteractable.gd` (grace event, burden falls).
- `PROP_RollingBurden` → registered with `CrossEventController` to roll along the `PATH_BurdenRoll_*` points.
- `PROP_ArmorStand` → `ArmorInteractable.gd`; `PROP_Sword` / `PROP_Shield` → `EquipmentPickup.gd`.

### Triggers
- `TRIGGER_Exit_<ChapterName>` → `ChapterExitTrigger.gd`, advances to that chapter.
- `TRIGGER_ReadBook` → `StoryEventTrigger.gd` (`receive_burden`).
- `TRIGGER_GateKnock` → `DialogueTrigger.gd` (`wicket_gate_knock`).
- `TRIGGER_CrossEvent` → `CrossEventTrigger.gd` (`cross_grace`).
- `TRIGGER_PliableLeaves`, `TRIGGER_ApollyonIntro`, … → `DialogueTrigger.gd` with the matching dialogue id.
- `TRIGGER_BossStart` → `BossStartTrigger.gd` (`apollyon`).
- `TRIGGER_ReceiveArmor` → `ArmorGrantTrigger.gd`.
- `TRIGGER_PrayerPrompt` → `PrayerPromptTrigger.gd`.

### Hazard / zone volumes
- `COL_MudZone_Shallow_*` / `COL_MudZone_Deep_*` → `MudZone.gd`.
- `COL_FalseGround_*` → `FalseGround.gd`.
- `COL_ArrowPressureZone` → `ArrowPressureZone.gd`.
- `COL_FearZone_*` → `FearZone.gd`; `COL_FalseVoiceZone_*` → `FalseVoiceZone.gd`.
- `COL_ShameFieldZone` → `ShameFieldZone.gd`; `COL_DespairFlameZone` → `DespairFlameZone.gd`.
- `COL_ArborSleepZone` → reuses `SleepField.gd`.
- `COL_FalsePath_*`, `COL_SteepSlopeZone_*`, `COL_BossArenaBounds`, `COL_DarknessDeepZone`, `COL_NarrowCliffEdge` → generic zone (`HazardZone.gd`) configured from the name.

The authoritative mapping lives in `scripts/import_pipeline/ImportedSceneBinder.gd`.
The full per-chapter object list (and a coverage check) lives in
`tools/scene_gen/verify_scenes.py`.

## Adding or moving an object

1. Edit the chapter's builder in `tools/scene_gen/scene_defs.py`.
2. If it is a new gameplay object, add its name to `EXPECTED` in
   `tools/scene_gen/verify_scenes.py` and add a prefix rule to
   `ImportedSceneBinder.gd` if it needs behaviour.
3. Regenerate (see `LOW_POLY_SCENE_GENERATION.md`) and run `verify_scenes.py`.
