# 天路历程 · 美术总表 (Art Bible)

每个素材给两条获取路径:**① 公共领域插图(直接下载)** 或 **② 写实 AI 提示词(用你自己的 AI 工具生成)**。
两者都做好后,按"目标文件名"放进对应文件夹**覆盖现有占位图**,告诉我放好了,我负责导入和校验。可以一次只做几张、分批来。

---

## 一、工作流

1. 选一条路:下载公共领域版画 **或** 用 AI 生成写实图。
2. 命名成下表的"目标文件名",放进对应文件夹(覆盖同名占位图)。
3. 跟我说一声(或说"导入素材"),我会刷新导入、检查尺寸/通道、必要时接线。

**尺寸(与现有占位图一致,直接覆盖即可):**

| 类型 | 文件夹 | 尺寸 | 说明 |
|---|---|---|---|
| 场景图 | `assets/scenes/<id>.png` | 1280×720 (16:9) | 章节标题卡背景 |
| 人物立绘 | `assets/characters/<stem>.png` | 512×640 (竖 4:5) | 对话头像,背景透明或纯色便于抠图 |
| 地面贴图 | `assets/textures/ground/<id>.png` | 512×512 | 需可平铺 (tileable) |

---

## 二、公共领域素材来源(已核实,版权安全)

- **Wikimedia Commons — Pilgrim's Progress**(128 张): <https://commons.wikimedia.org/wiki/Category:Pilgrim%27s_Progress>
- **Wikimedia Commons — William Blake 水彩集**(最具人物立体感,首选): <https://commons.wikimedia.org/wiki/Category:William_Blake%27s_Pilgrim%27s_Progress>
- **Internet Archive — 全本扫描(含全部版画)**: <https://archive.org/details/pilgrimbunyan00bunyrich>
- **Frederick Barnard 版**(55 幅版画,Dalziel 兄弟雕版,约 1890;场景覆盖最全)— 见上面 Archive / Commons。

> 版权说明:班扬原著(1678)与这些插图作者均已逝世逾百年 → **公共领域**,可自由使用、修改、商用。下载前在 Wikimedia 文件页看一眼许可标注(PD-old / CC0)即可。Archive 页面右侧有整本 PDF / 单页图下载。

**风格提醒:** 公共领域插图是 **维多利亚版画 / Blake 水彩**——很美但偏线条/古典,不是写实照片级。你要的"写实立体人物 + 逼真场景"主要靠下面的 **AI 提示词**实现,而把版画当作构图参考。建议:章节标题卡/过场可用版画的古典味;游戏内人物与场景用 AI 写实图。

---

## 三、统一风格后缀(关键 · 保证整套一致)

每条提示词末尾都**追加**下面对应的后缀(复制一次即可):

- **场景后缀 [S]:**
  `realistic painterly concept art, oil-painting texture, cinematic dramatic lighting, volumetric atmosphere, 17th-century rural England, grounded believable figures, muted earthy palette with a single warm light source, highly detailed, no text, no watermark, no modern objects --ar 16:9`

- **人物后缀 [P]:**
  `realistic character portrait, half-body, oil-painting concept art, dimensional form with soft rim light, 17th-century English plain clothing, weathered believable face, neutral dark background for easy cut-out, highly detailed, no text, no watermark --ar 4:5`

主角设定(贯穿全篇,务必一致):**"基督徒/Pilgrim"——一名 17 世纪英国普通男子,粗布褐色长衣,背上压着沉重的包袱(a heavy burden/bundle strapped to his back),手持一卷羊皮卷(a scroll),神情恳切而疲惫但带着盼望。**

---

## 四、场景图 ×16  (`assets/scenes/<id>.png`, 1280×720)

### 1. city_of_destruction — 毁灭城
- 场景:基督徒手按双耳、背负包袱,从一座笼罩在火光与浓烟中的城市逃出,奔向远方田野;身后家人呼喊。
- 公共领域:Blake《Christian Reading in His Book》/逃离毁灭城一图;Barnard 版开篇插图。
- AI:`A 17th-century English man with a heavy burden strapped to his back, fingers in his ears, fleeing a doomed city wreathed in fire and smoke at dusk, running toward open fields, a faint bright gate glowing on the far horizon, despair behind and hope ahead [S]`

### 2. slough_of_despond — 绝望泥潭
- 场景:一片灰暗沼泽,基督徒陷在烂泥中挣扎、被包袱拖累下沉;岸边一人(Help)伸手相援。
- 公共领域:Barnard / Archive 版"Slough of Despond"插图。
- AI:`A man sinking and struggling in a vast grey mire under a heavy overcast sky, weighed down by the burden on his back, mud clinging, a strong helper reaching out a hand from the firm bank, bleak desolate moorland [S]`

### 3. wicket_gate — 窄门
- 场景:旷野尽头一道墙上的窄小木门,门旁守门人(Goodwill)招手相迎,基督徒走近叩门。
- 公共领域:Blake《Christian Knocking at the Wicket Gate》;Barnard 版。
- AI:`A weary pilgrim approaching a small narrow wooden gate set in an old stone wall at the end of a long field path, a kindly gatekeeper beckoning him in, warm light spilling through the gate, early morning [S]`

### 4. interpreter_house — 释义者之家
- 场景:烛光摇曳的古旧室内,墙上挂着寓意画像;释义者举灯,向基督徒讲解。
- 公共领域:Barnard / Archive 版室内讲解图。
- AI:`Candle-lit interior of a 17th-century house, an old wise interpreter holding a lamp and gesturing toward an allegorical painting on the wall, a pilgrim listening intently, warm chiaroscuro, dust motes in lamplight [S]`

### 5. hill_difficulty — 艰难山
- 场景:一座陡峭高山,山脚有清泉,一条窄路盘旋而上;基督徒手脚并用攀爬。
- 公共领域:Barnard 版"Hill Difficulty";Archive。
- AI:`A lone pilgrim with a burden climbing a steep rugged hill on hands and knees along a narrow winding path, a clear spring at the foot of the hill, two easier side-roads veering off into shadow, bright sky above the summit [S]`

### 6. palace_beautiful — 华美宫
- 场景:山顶一座庄严华美的宫殿,通往宫门的窄路两侧蹲伏两头狮子;黄昏暖光。
- 公共领域:Barnard 版"Palace Beautiful / the lions";Archive。
- AI:`A stately beautiful palace crowning a hill at golden hour, a narrow approach road flanked by two chained lions, a hesitant pilgrim on the path, banners and warm window light, sense of refuge and testing [S]`

### 7. valley_humiliation — 屈辱谷
- 场景:幽暗山谷中,基督徒持剑举盾,直面庞大恐怖的恶魔亚玻伦;火光与硝烟。
- 公共领域:Blake《Christian Fighting Apollyon》(强烈推荐,Blake 此图极具张力);Barnard 版。
- AI:`A pilgrim standing his ground with sword and shield against a towering monstrous fiend in a dark narrow valley, the demon with fish-like scales, dragon wings and lion's maw belching fire and smoke, embers in the air, desperate courage [S]`

### 8. valley_shadow_death — 死荫幽谷
- 场景:一条窄路夹在深沟与泥潭之间,两侧幽影与地火,一盏将熄的灯笼;极远处透出微光黎明。
- 公共领域:Blake / Barnard"Valley of the Shadow of Death"。
- AI:`A perilous narrow path between a deep ditch and a treacherous quag at night, creeping shadows and flickering ground-flames on either side, a pilgrim shielding a nearly-snuffed lantern, a faint cold dawn far ahead, oppressive dread [S]`

### 9. vanity_fair — 名利场
- 场景:喧闹的中世纪集市,满目珠宝、华服、名利货摊与人潮;朴素的朝圣者格格不入。
- 公共领域:Barnard 版"Vanity Fair";Archive。
- AI:`A crowded bustling medieval fair, stalls heaped with jewels, fine silks, gold and worldly vanities, jeering richly-dressed merchants, two plain travel-worn pilgrims standing out and unmoved amid the throng, gaudy chaotic color [S]`

### 10. doubting_castle — 怀疑堡
- 场景:阴森城堡,巨人"绝望"(Giant Despair)统治;地牢中两名囚徒(基督徒与希望),一把名为"应许"的钥匙。
- 公共领域:Barnard 版"Doubting Castle / Giant Despair"。
- AI:`A grim fortress under a stormy sky ruled by a brutal giant, a dark dungeon where two ragged prisoners huddle, a single key glinting with hope in one prisoner's hand, cold stone, despair and the first spark of escape [S]`

### 11. delectable_mountains — 安乐山
- 场景:阳光下青翠群山,牧人与羊群;远处可借"望远镜"望见天城轮廓。
- 公共领域:Barnard 版"Delectable Mountains / Shepherds"。
- AI:`Lush sunlit green mountains with grazing sheep, kindly shepherds pointing toward the distant horizon, two pilgrims gazing through a perspective glass at a faint shining city far away, fresh air, restful pastoral beauty [S]`

### 12. enchanted_ground — 迷魂地
- 场景:雾气弥漫、令人昏睡的草甸,路边凉亭诱人歇息;朝圣者强撑睡意前行。
- 公共领域:Barnard / Archive"Enchanted Ground"。
- AI:`A misty drowsy meadow at dusk where the heavy air lulls travelers to sleep, tempting shaded arbors beside the path, two pilgrims forcing themselves onward against overwhelming sleepiness, soft hazy dreamlike light [S]`

### 13. wilderness_road — 旷野之路
- 场景:荒凉崎岖的旷野长路,风沙与乱石;远方目标若隐若现。
- 公共领域:Archive 通用旷野/行路插图。
- AI:`A rough lonely road winding through a windswept wilderness of rock and scrub under a wide pale sky, a small determined pilgrim figure pressing forward, a faint distant goal on the horizon, vast and austere [S]`

### 14. river_of_death — 死亡之河
- 场景:一条无桥的深河,两名朝圣者涉水而过,望向对岸的辉煌光芒;天使在彼岸守候。
- 公共领域:Blake / Barnard"Crossing the River"。
- AI:`Two pilgrims wading across a deep bridgeless river at the threshold of the far shore, water rising to their chests, a blinding glorious light and shining figures waiting on the opposite bank, awe and fear giving way to peace [S]`

### 15. celestial_city — 天城
- 场景:河对岸高处一座金光璀璨的圣城,城门洞开、光芒万丈,号角与荣光。
- 公共领域:Blake / Barnard"Celestial City"。
- AI:`A radiant golden celestial city crowning a high hill beyond a river, gates of light flung open, beams of glory streaming down, distant shining hosts, overwhelming luminous triumph, the journey's end [S]`

### 16. cross_and_tomb — 十字架与空墓
- 场景:基督徒来到十字架前,背上的包袱忽然松脱、滚落进山脚的空墓;如释重负,光照其身。
- 公共领域:Blake《Christian Losing His Burden》(经典,推荐);Barnard 版。
- AI:`A pilgrim standing before a rugged cross on a small hill at dawn, the heavy burden suddenly loosed from his back and rolling down into an open empty tomb, his arms lifting in relief and wonder, warm redemptive light breaking over him [S]`

---

## 五、人物立绘 ×12  (`assets/characters/<stem>.png`, 512×640, 背景透明/纯色)

| 角色 | 目标文件 | 公共领域参考 | 写实 AI 提示词(末尾加 [P]) |
|---|---|---|---|
| 基督徒(主角) | `pilgrim.png` | Blake 群像中的 Christian | `An earnest weary 17th-century English pilgrim, brown coarse robe, a heavy burden bundled on his back, a rolled scroll in hand, weathered hopeful face, mid-40s` |
| 传道者 | `evangelist.png` | Barnard"Evangelist" | `A wise older guide in a long robe, one hand raised pointing the way, a parchment in the other, grave kindly bearded face, calm authority` |
| 帮助(Help) | `help.png` | Slough 救援图中的 Help | `A strong kindly working man with muddy hands and forearms, sleeves rolled, reaching out to help, sturdy reassuring presence` |
| 善意(Goodwill) | `goodwill.png` | Wicket Gate 守门人 | `A welcoming gatekeeper standing at a narrow gate, warm open expression, simple keeper's clothing, a key at his belt` |
| 希望(Hopeful) | `hopeful.png` | 同行少年朝圣者 | `A younger companion pilgrim, bright earnest hopeful expression, simple traveling clothes, optimistic and steadfast` |
| 亚玻伦 | `apollyon.png` | Blake《Apollyon》(强推) | `A monstrous demon fiend covered in fish-like scales, great dragon wings, bear-like feet, a lion's maw breathing fire and smoke, terrifying and powerful, dark valley behind` |
| 释义者 | `the_interpreter.png` | Barnard 室内讲解者 | `A thoughtful teacher holding a lamp/candle, scholarly robe, gentle illuminating gaze, emblematic objects faintly behind` |
| 群羊牧者 | `the_shepherds.png` | Delectable Mountains 牧人 | `A group of three or four weathered kindly shepherds on green hills, crooks in hand, sheep nearby, watchful caring faces` |
| 警醒(Watchful) | `watchful.png` | 牧人/门房之一 | `An alert vigilant shepherd-porter, keen watchful eyes scanning the distance, staff in hand, dependable` |
| 固执(Obstinate) | `obstinate.png` | Barnard 开篇 | `A scornful stubborn townsman turning away with a sneer, arms crossed, refusing the journey, hard closed expression` |
| 易迁(Pliable) | `pliable.png` | Barnard 开篇 | `A soft well-meaning but easily-discouraged companion, uncertain wavering expression, glancing back, lightly dressed` |
| 家人 | `your_family.png` | 毁灭城离别图 | `A pleading wife and two children reaching out in distress, simple 17th-century cottage clothing, sorrow and love` |

> 还会用到但暂无立绘:**Merchant(名利场商贩)**、**Giant Despair(绝望巨人)**。要的话告诉我,我把它们加进 `SPEAKER_MAP` 并给提示词。

---

## 六、地面贴图 ×16  (`assets/textures/ground/<id>.png`, 512×512, 可平铺)

这些是脚下材质,可用 AI"**seamless tileable texture, top-down, PBR albedo**"加各章关键词生成,或直接从对应场景图里裁一块平铺:

- city_of_destruction:`cracked ash-grey cobblestone, soot, embers`
- slough_of_despond:`thick wet brown mud, reeds, puddles`
- wicket_gate:`packed dirt field path, trampled grass`
- interpreter_house:`worn wooden plank floor, candle-warm`
- hill_difficulty:`rocky scree and stony trail`
- palace_beautiful:`polished stone courtyard flagstones`
- valley_humiliation:`scorched dark rocky ground, ash`
- valley_shadow_death:`black wet stone, faint embers`
- vanity_fair:`muddy market cobbles, scattered straw`
- doubting_castle:`cold damp dungeon stone slabs`
- delectable_mountains:`lush green meadow grass with wildflowers`
- enchanted_ground:`soft mossy turf, low mist`
- wilderness_road:`dry cracked earth, gravel, sparse scrub`
- river_of_death:`wet riverbed pebbles and shallow water`
- celestial_city:`golden luminous marble, light`
- cross_and_tomb:`dawn-lit grassy hilltop earth`

统一后缀:`seamless tileable PBR albedo texture, top-down orthographic, even lighting, no seams, no text --ar 1:1`

---

## 七、优先级建议

最值得先替换、视觉冲击最大的 5 张:
1. `pilgrim.png`(主角,出现最多)
2. `apollyon.png`(Boss,Blake 原图就极震撼)
3. `scenes/city_of_destruction.png`(开场第一印象)
4. `scenes/celestial_city.png`(终局)
5. `scenes/cross_and_tomb.png`(卸下重担的核心时刻)

做好任意几张丢进文件夹,跟我说一声,我就导入并校验。

---

## 八、儿童版 (Children's Version)

童趣模式("Children's Journey")会自动加载 `<名字>_child.png`(场景与人物都支持);没有童版的素材自动回退到标准版——所以两个版本切换时都能正确引用。代码已接好(`AssetLib.scene_art` / `portrait` 检查 `GameState.is_child_mode()`)。

**做法:** 用上面每张素材的场景/人物描述,把风格换成童书风,文件名加 `_child` 后缀,存进 `assets/_incoming/`,我跑 `tools/import_incoming.py` 一键导入。

**童书风后缀:**
`gentle warm children's picture-book illustration, soft friendly storybook colors, rounded cute characters, child-friendly, reassuring, soft lighting, no scary elements, highly detailed`(场景 --ar 16:9;人物 --ar 3:4)

**把吓人的场景柔化:** 亚玻伦 → "友善的大狮子龙";死荫幽谷 → "夜里有萤火虫的温柔小路";怀疑堡 → "灰色小城堡但不可怕";死亡之河 → "浅浅的小溪轻松涉过"。

**目标文件名:** 场景 `<chapter_id>_child.webp`(16),人物 `<stem>_child.webp`(12)。

**已生成 8 张:** pilgrim, your_family, city_of_destruction, celestial_city, cross_and_tomb, slough_of_despond, wicket_gate, interpreter_house。**待生成 20 张。**
