# Commercial Version & Product Strategy

Batch 7 · Skill 55, adapted to the actual stack: a **Godot 4 web build** that
already deploys (Vercel front-end `pilgrims-gold.vercel.app` + Hugging Face Space
backend + Neon + Upstash). This is a strategy reference, not code.

## Version tiers

1. **Free Web Demo** — chapters 1–4 (City → Slough/Wicket → Interpreter → Cross),
   playable in the browser. Goal: prove the loop, the look, and the spiritual
   storytelling. ~30–45 minutes; ends with the burden-release at the Cross and a
   "the full road continues into Hill Difficulty, House Beautiful, Apollyon,
   Vanity Fair, the River, and the Celestial City" teaser.
2. **Full Game** — all 16 scenes, one journey. Sell on itch.io / Steam / the
   project's own site (the web build also runs standalone).
3. **Teaching Edition** — Full Game + Teaching Mode (the 16
   `data/teaching_guides` + the in-game `TeachingGuidePanel`) + teacher control
   (chapter jump) + exportable reflections. Audience: churches, Sunday schools,
   Christian schools, small groups.
4. **Deluxe Edition** — game + per-chapter original-text commentary + the
   cinematic music pack + behind-the-scenes art bible (`docs/ART_BIBLE.md`,
   `data/art_direction/color_palettes.json`).
5. **Mobile Lite** — simplified controls / lighter scenes / chapter-by-chapter
   episodic build (the low-graphics path in `RELEASE_QA_CHECKLIST.md`).

## Demo scope & acceptance (chapters 1–4)

Why 1–4: a complete arc (awakening → the mire & the gate → instruction → the
Cross), a clear theological core (the burden falls), moderate build cost (no boss
fight), and the Cross release is the most moving beat.

- [ ] Completable in ~30–45 min, with a real beginning and climax.
- [ ] The burden-release cutscene/event lands emotionally.
- [ ] Closing card names the full game's later chapters.
- [ ] Web build loads and runs on a mid-range laptop browser.

## Chapter sell-points

- **1–4** sin & grace — the Demo.
- **5–8** sanctification, the church, the armour — for believer growth.
- **9–12** Apollyon, the Shadow Valley, Vanity Fair, Faithful's witness — the most
  dramatic.
- **13–16** Doubting Castle, the River, the Celestial City — the strongest emotional
  finale.

## DLC / expansion directions

Commentary (per-chapter original text + theology) · Pilgrim Journal (the
reflection-export feature, to PDF/Markdown) · Chapel Restoration (repair wayside
chapels to unlock prayers/verses/hymns — fits the existing `PROP_Chapel` system) ·
Companion Stories (Faithful / Hopeful / Evangelist side-arcs) · Bunyan Historical
Mode (his life, prison writing, the Puritan setting) · Sunday-School Pack (teacher
slides, worksheets — extends `data/teaching_guides`).

## Feature priority

- **P0 (must)** — 16-scene main line · save · chapter select · settings · full
  audio · web export/release. *(All present in the engine today.)*
- **P1 (strongly)** — Teaching Mode · journey review · teacher chapter-jump · zh/en
  bilingual · low-graphics mode. *(Teaching Mode + review present; bilingual present.)*
- **P2 (commercial)** — achievements · cloud save *(CloudSaveService present)* ·
  cosmetic skins · commentary · reflection export · New Game+.
- **P3 (long-term)** — more languages · mobile · narration VO · co-op · custom journal.

## Store copy (zh / en)

> **《天路历程：朝向天城》** 是一款低模 3D 属灵寓言冒险，改编自约翰·班扬的公版经典。你将
> 扮演一位背负重担的天路客，从灭亡城出发，经过窄门、十字架、艰难山、美宫、降卑谷、死荫谷、
> 虚华市、疑惑堡、死河，最终走向天城。这不是普通奇幻 RPG——你的敌人不只是怪物，还有惧怕、
> 疑惑、骄傲、虚华、绝望与沉睡；你的帮助也不只是武器，还有恩典、祷告、应许、同行者与神圣军装。

> **Pilgrim's Road: Toward the Celestial City** — a low-poly 3D allegorical
> adventure adapted from John Bunyan's public-domain classic. Carry a burden out
> of the City of Destruction, through the narrow gate, the Cross, Hill Difficulty,
> House Beautiful, the Valley of Humiliation, the Shadow of Death, Vanity Fair,
> Doubting Castle, and the River — home to the Celestial City. Not a typical
> fantasy RPG: your enemies are also fear, doubt, pride, vanity, despair, and
> sleep; your help is also grace, prayer, the promises, companions, and the armour
> of God.

## Risks & boundaries

- **Vertical audience.** Christian-themed games are niche; the faithful audience is
  smaller but more supportive. Aim at overseas Chinese Christians, the English
  Christian market, churches, and itch.io/Steam international.
- **No crude preachiness.** Gameplay and story must stand on their own; don't stack
  doctrine as text.
- **Visual bar.** Low-poly ≠ cheap — hold the unified art direction
  (`docs/ART_BIBLE.md`, the chapel-cross language, the per-chapter palettes).
- **China-market sensitivity.** Religious themes carry uncertainty for mainland
  release; favour overseas distribution and in-church teaching use.
- **IP.** *The Pilgrim's Progress* is public domain, but modern films, the 2011
  game, and any specific third-party art/music are **not** — use original assets
  ("inspired by", not copied). The engine's GLB/art/audio are all original
  generated assets (`tools/scene_gen`, `tools/gen_*`).
