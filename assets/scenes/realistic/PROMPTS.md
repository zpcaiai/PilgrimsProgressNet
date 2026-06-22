# 写实背景图 · 生成清单 (Realistic backdrops)

在 Z-Image-Turbo(或任意文生图)按下面逐张生成,**分辨率 1536×864 (16:9)**,
下载后**重命名为对应文件名**放进本目录 `assets/scenes/realistic/`(`.jpg`/`.png`/`.webp` 都行)。

**统一后缀(每条提示词末尾都加上):**
```
, photorealistic landscape, cinematic natural light, deep depth of field, highly detailed, 17th-century rural England, no people, no text, no watermark, no modern objects
```

---

| 文件名 | 提示词(主体,末尾再加上面的后缀) |
|---|---|
| `city_of_destruction.jpg` | a doomed walled medieval town at dusk wreathed in fire and rolling black smoke, burning rooftops, open fields beyond, a faint bright gate on the far horizon |
| `slough_of_despond.jpg` | a vast bleak grey moorland bog with muddy pools and reeds, low clinging fog under a heavy overcast sky |
| `wicket_gate.jpg` | a small narrow wooden gate set in an old stone wall at the end of a long green field path, soft early-morning light |
| `interpreter_house.jpg` | the candlelit interior of an old 17th-century English house, dark oak beams, a warm hearth, dust in lamplight, deep shadows |
| `hill_difficulty.jpg` | a steep rugged green hill with a narrow winding path climbing it, a clear spring at its foot, bright sky above the summit |
| `palace_beautiful.jpg` | a stately pale-stone palace with towers and banners crowning a hill at golden hour |
| `valley_humiliation.jpg` | a dark narrow rocky valley with scorched ground, drifting embers and smoke, ominous red light |
| `valley_shadow_death.jpg` | a perilous narrow path between a deep ravine and a black marsh at night, a faint cold dawn far ahead, oppressive gloom |
| `vanity_fair.jpg` | a crowded gaudy medieval market fair, stalls heaped with silks and wares, fluttering banners, a bustling square |
| `doubting_castle.jpg` | a grim stone fortress with high battlemented walls under a stormy sky, cold and forbidding |
| `delectable_mountains.jpg` | lush green sunlit mountains with grazing sheep, distant blue ranges, a faint shining city on the far horizon |
| `enchanted_ground.jpg` | a misty drowsy meadow at dusk with tempting shaded arbours, soft hazy dreamlike light |
| `wilderness_road.jpg` | a rough lonely road winding through a windswept rocky wilderness under a wide pale sky |
| `river_of_death.jpg` | a deep wide bridgeless river at dusk, the far shore glowing with light, reeds on the near bank |
| `celestial_city.jpg` | a radiant city of pale stone with gates and towers crowning a high hill beyond a river at sunrise, catching golden light |
| `cross_and_tomb.jpg` | a rugged wooden cross on a grassy hilltop at dawn with an open empty tomb nearby, warm redemptive light breaking |

---

放好后:Godot 打开工程重新导入(网页版需重新导出),`AssetLib.realistic_backdrop()`
会在**虔诚(写实)模式**自动把它们当作各章天空/远景;缺的章自动回退程序化天空。
想让我帮忙校色/裁切/做成 2:1 全景,把生成的图发我即可。
