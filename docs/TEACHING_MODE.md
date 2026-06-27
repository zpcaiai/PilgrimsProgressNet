# Teaching Mode (主日学 / 慕道班 / Sunday-school)

Batch 7 · Skill 54, implemented on the Godot game. Teaching Mode turns the 16
scenes into a usable curriculum for Sunday school, seeker classes, youth
fellowship, and small groups — **without changing the story**. It adds, after
each chapter, a bilingual guide: the original-story summary, the spiritual
theme, Scripture, audience-tiered discussion questions, teacher notes, and a
reflection + prayer prompt.

## How it works in-game

- **Data**: `data/teaching_guides/<chapter_id>.json` — one per engine scene
  (16 files). Built by `tools/data_gen/build_teaching_guides.py` (re-runnable;
  `--check` validates that every guide maps to a real chapter and that
  references/audiences are well-formed).
- **UI**: `scripts/ui/TeachingGuidePanel.gd`, autoloaded as `TeachingGuidePanel`
  (registered in `project.godot`). A code-built `CanvasLayer` overlay
  (`layer = 160`, bilingual via `TranslationServer.get_locale()`).
- **Triggers**:
  - Auto-shows after a chapter completes **when teaching mode is on** — it
    listens to `EventBus.chapter_completed(chapter_id)`.
  - **F1** opens/closes the guide for the current chapter at any time (handy for
    teachers and preview). **Esc** closes.
- **Setting**: `Settings.teaching_mode` (persisted to `user://settings.cfg`
  under `[accessibility]`). Toggle via `Settings.set_teaching_mode(true)` from
  the Options screen. Default off, so story mode is unaffected.

It is fully additive and safe: if a guide file is missing the panel simply does
nothing, and nothing in the story/save path is touched.

## Guide JSON schema (`data/teaching_guides/<id>.json`)

```
chapter_id, order, title_zh, title_en,
story_summary_zh / _en,            # 原著剧情
spiritual_theme_zh / _en,          # 属灵主题
bible_references: [ {label_zh/_en, reference_zh/_en, note_zh/_en} ],
discussion_questions: [ {id, audience, question_zh/_en} ],   # audience: children|youth|seekers|adult|small_group
teacher_notes_zh / _en: [ ... ],
reflection_prompt_zh / _en,        # 默想回应
prayer_prompt_zh / _en             # 祷告
```

To edit content, change `GUIDES` in `tools/data_gen/build_teaching_guides.py`
and re-run it (keeps every reference under your control and the set in sync with
`data/chapters/`).

## 16-chapter teaching themes (engine scene → theme)

| # | scene | theme |
|--:|---|---|
| 1 | city_of_destruction | 觉醒与审判 — awakening & judgement |
| 2 | wilderness_road | 起步的代价、分别为圣 — the cost of beginning |
| 3 | slough_of_despond | 软弱中的呼求与帮助 — crying out, receiving help |
| 4 | wicket_gate | 信心叩门、恩典开门 — faith asks, grace opens |
| 5 | cross_and_tomb | 称义与赦罪 — justification & pardon |
| 6 | interpreter_house | 属灵分辨 — discernment |
| 7 | hill_difficulty | 成圣、忍耐、拒绝捷径 — endurance, no shortcuts |
| 8 | palace_beautiful | 团契与穿戴军装 — fellowship & the armour |
| 9 | valley_humiliation | 谦卑、抵挡控告、得胜 — humility, resisting accusation |
| 10 | valley_shadow_death | 黑暗中凭信持守 — faith without sight |
| 11 | vanity_fair | 不爱世界、付代价见证 — costly witness |
| 12 | doubting_castle | 应许胜过绝望 — the Promise over despair |
| 13 | delectable_mountains | 牧养恢复、重立盼望 — pastoral restoration |
| 14 | enchanted_ground | 警醒到底、抗拒沉睡 — staying watchful |
| 15 | river_of_death | 死亡面前的信靠 — trust facing death |
| 16 | celestial_city | 荣耀终局、恩典回顾 — glory & grace-review |

(Engine folds the attachment's standalone Armory→ch8, Apollyon→ch9, Faithful's
martyrdom→ch11, so those guides carry both themes.)

## Audience tiers

Every chapter ships at least one question each for **children / youth / adult**
(the schema also allows `seekers` and `small_group`). The panel tags each
question with its audience; a class can pick the row that fits. Children's
questions stay concrete ("what is the burden?"), adult questions go reflective
("have you tried to remove guilt by effort?").

## Follow-up hooks (designed, not yet wired — kept minimal on purpose)

- **Markdown reflection export**: compose `# title / theme / scripture / my
  response / prayer` from the loaded guide + a text field. (Skill 54's
  `exportChapterReflectionMarkdown` equivalent — a ~20-line method on the panel.)
- **Teaching/Debug chapter-select**: let a teacher jump to any chapter. The safe
  hook is `ChapterManager` — gate `can_enter_chapter()` to return `true` when
  `Settings.teaching_mode`/a debug flag is set, instead of editing the
  chapter-select UI. Left out of this pass to avoid touching core navigation.
- **Pause-after-chapter**: the panel currently overlays without pausing the
  tree; flip `get_tree().paused` in `open_for`/`hide_panel` if a hard pause is
  wanted (the panel already runs with `PROCESS_MODE_ALWAYS`).
