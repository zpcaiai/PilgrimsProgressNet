# 世界重塑 · 油画/绘本级 3D (World Rebuild)

把 16 章的 3D 世界从「平面色块方盒 + 单一天光」整体重塑为**油画/绘本级**观感:
**逐章建模(程序化道具)+ PBR 贴图 + 逐章布光 + 全屏 painterly 后处理**。

---

## ★ 高保真 GLB 升级(「3D Max」级,2026-06)

导入场景 `assets/imported_scenes/*.glb` 已从**平面着色三角汤**升级为**渲染级几何 + PBR**,
两条流水线共用 `tools/scene_gen/scene_defs.py`(同一份布局,逐物体一致):

| 维度 | 旧 | 新 |
|---|---|---|
| 方块 | 6 面硬边「纸盒」 | **倒角(chamfer)方块**,每条棱都吃高光 |
| 曲面 | 10 边硬边柱/锥 | **24 段解析法线平滑** 柱/锥/球/环面/**车削(lathe)** |
| 地面 | 0.5m 平板 | **细分起伏地形**(振幅 ≤7cm,仍可行走、道具不悬空) |
| 材质 | 全部 metallic0/rough0.95 哑光 | **按名字+颜色推断 PBR**:金/剑/盔/钟=金属高光,水=高光泽,石/木/草各异 |
| 道具 | 色块 | 屋舍带屋顶/烟囱/暖光窗,柱子车削,人群有头,树有球冠,天城有光环 torus + 顶球 |

绕序(winding)做了双保险:凸体按质心朝外定向,平滑索引网格按解析法线对齐,**绝不会被背面剔除而漏面**。
所有 16 章共 **~4.6 万三角面 / 合计 ~2.0 MB**,配合 Godot 导入的 auto-LOD + shadow mesh,网页可跑。
节点命名、Zone 的 AABB 碰撞范围、Marker 全部原样保留,`ImportedSceneBinder` 绑定不受影响。

### 重新生成(两条流水线)
```bash
# A. 纯 Python(无需 Blender,网页用的就是它,CI 可跑):
python3 tools/scene_gen/build_scenes.py     # 写 16 个 GLB
python3 tools/scene_gen/verify_scenes.py    # 校验技术对象齐全 + GLB 合法

# B. Blender(本机高保真/烘焙;产物轮廓与 A 一致):
blender --background --python tools/blender/export_all_glb.py
# 高模烘焙档(加细分曲面 + 倒角 + 程序化微凹凸,适合英雄渲染):
PILGRIM_HIFI=1 blender --background --python tools/blender/export_all_glb.py
```
预览(非 Godot,纯 numpy 软渲染,仅用于快速肉眼检查):
`python3 tools/glb_preview.py <scene.glb> <out.png>`;16 张样张见 `docs/world_rebuild_previews/`。

> 关键文件:`tools/scene_gen/glb_lib.py`(几何 + PBR 推断 + GLB 写出)、
> `tools/scene_gen/scene_defs.py`(16 章布局,逐章英雄道具升级)、
> `tools/blender/blender_scene.py`(bpy 后端,Principled + 平滑 + 可选修改器)。

---

整套系统沿用项目原有的「程序化、素材可选、缺失即优雅降级」架构——没有任何外部
3D 模型文件,所有几何都在代码里生成,任何贴图缺失都会自动回退,不会报错。

---

## 〇、画风随模式切换:儿童=油画,成人=写实 (RenderConfig)

`scripts/render/RenderConfig.gd` 按**所选旅程模式**自动切换整套画风:

```gdscript
RenderConfig.is_realistic()   # 童趣版(Children's Journey)= false → 油画/绘本
                              # 虔诚版(Devout / 成人)      = true  → 自然写实
const FORCE := 0              # 0=按模式自动;1=强制写实;2=强制油画(测试用)
```

**童趣版 → 油画/绘本(stylised)**:油画 Kuwahara 全屏后处理、"画作当天空"的背景、
调色板向画作靠拢、神光柱/光晕太阳/发光金城/火口光幕/发光梦花等奇幻特效全开;
`PainterlyPostFX` 用暖色油画预设(明亮、温暖、适合孩子)。

**虔诚版 → 自然写实**:关掉油画后处理与画作天空;干净程序化天空(或写实背景照片)、
PBR 材质、自然布光/雾、辉光压到写实档、去自发光彩雾;奇幻特效跳过或大幅压暗,
只留自然布景(树木、岩石、水、建筑、雾、羊群、集市…);天城变成阳光下的真实石城。

**写实环境背景(仅虔诚版用)**:把写实风景图放进 `assets/scenes/realistic/<id>.{jpg,png,webp}`
即被 `AssetLib.realistic_backdrop()` 当作该章天空/远景;没有就用程序化天空(优雅降级)。
图可 AI(Z-Image/Firefly)生成或用真实照片。详见该目录 README。
> 这批写实背景照片由定时任务 `generate-realistic-backdrops` 在 GPU 配额恢复后自动分批生成。

---

## 一、改了什么(总览)

| 层面 | 内容 | 文件 |
|---|---|---|
| 渲染后端 | 渲染器用 **`gl_compatibility`**(全平台/网页兼容);开启 MSAA 4x、软阴影、4K 阴影图、各向异性过滤。⚠️ 曾试 Forward+ 但网页/非 Vulkan 环境会让 3D **全黑**(HUD 仍在),已回退 | `project.godot` |
| 画风后处理 | 全屏 **Kuwahara 油画滤镜** + 调色/暖色画布染/暗角/颗粒;按模式切换(虔诚=油画、童趣=绘本) | `assets/shaders/painterly.gdshader`、`scripts/render/PainterlyPostFX.gd` |
| PBR 材质 | 命名表面材质工厂(stone/wood/grass/gold/marble/mud/foliage…),加载 albedo/normal/rough/ao,克制高光、画味调和 | `scripts/render/MaterialKit.gd`、`scripts/core/AssetLib.gd`(新增 `pbr()`/`ground_map()`) |
| 逐章建模 | 程序化道具库:树/松/灌木/草地(MultiMesh)/芦苇/岩石/峭壁/山脊/门/拱/墙/城垛/柱/十字架/墓/旗/集市摊/羊/灯/火/烟/雾/光柱/水面 | `scripts/level/PropKit.gd` |
| 逐章布光+氛围 | 每章一份美术档案:主光/补光角度色温能量、环境光、雾(含体积雾)、辉光、色调映射、调色、SSAO/SSIL、painterly 参数,以及一份**环境点缀清单** | `scripts/chapters/ChapterArtProfiles.gd` |
| 接线 | `ChapterBase` 在每章 `_build_chapter()` 之后叠加上述重塑;`make_*` 全部升级为 PBR/画味,**且保持原有函数签名** | `scripts/chapters/ChapterBase.gd` |
| 贴图生成 | 程序化、可平铺、版权安全的 PBR 贴图库 + 为 16 张地面图派生法线/粗糙度 | `tools/gen_pbr.py` |

> 关键点:每个章节脚本(`SloughOfDespond.gd` 等)**一行都不用改**。重塑通过共享基类
> `ChapterBase` + 数据表 `ChapterArtProfiles` 自动套到全部 16 章。

---

## 二、渲染管线流程

每章加载时 `ChapterBase._ready()` 的顺序:

1. `_sample_palette()` — 采样该章画作主色(原有)
2. `_build_chapter()` — 章节自己的玩法几何(原有,未改)
3. `_apply_art_palette()` / `_attach_backdrop()` — 画作上天空、调和色(原有)
4. **`_apply_world_rebuild()`(新增)**
   - `_apply_environment()` — 雾/体积雾/辉光/色调映射/调色/SSAO/SSIL(读美术档案)
   - `_apply_lighting()` — 把原有那盏太阳重配为**投影主光**,再加一盏无影补光
   - `_apply_dressing()` — 按档案清单铺**环境点缀**(树石雾火光柱…)
   - `_attach_postfx()` — 挂上 painterly 后处理层

### 后处理层级(重要)
全部 UI 都在 CanvasLayer 第 9–22 层(HUD=10、对话=16、菜单=20…)。painterly 层设在
**第 5 层**:位于 3D 画面之上、所有 UI 之下。`hint_screen_texture` 因此只采到渲染好的
3D 帧,**不会糊到 HUD 文字或对话框**。

---

## 三、逐章美术档案(怎么调)

每章在 `ChapterArtProfiles._overrides(id)` 里。字段(全部可选,`base()` 给默认):

```
sun     { angle:Vector3(度), color:Color, energy:float }   # 投影主光
fill    { angle, color, energy }                            # 无影补光
ambient { color, energy }
fog     { enabled, color, density, volumetric, vol_density, albedo, emission, emission_energy, aerial }
glow    { enabled, intensity, strength, bloom, threshold }
tonemap { mode:"aces"|"filmic"|"agx", exposure, white }
adjust  { brightness, contrast, saturation }
ssao / ssil : bool
post    { strength, saturation, tint:Vector3, tint_amount, vignette_amount, grain_amount, brush }  # 覆盖 painterly 参数
dressing[ {op:..., ...} ]                                   # 环境点缀清单
```

### 点缀清单 op 一览(纯数据,`ChapterBase._dress_one` 解释执行)
`scatter`(kind=tree/pine/bush/rock/sheep/lantern)、`grass`、`reeds`、`mist`、`smoke`、
`fire`、`shaft`(光柱)、`water`、`ridge`(远山)、`cliff`、`boulders`、`arch`、`wall`、
`castle_wall`、`pillar`、`gate`、`cross`、`tomb`、`banner`、`stall`、`lantern`、`tree`、`pine`、`bush`。

**布置规则**:所有带碰撞的点缀都放在中央通道两侧(|x| ≥ ~8),不挡路、不挡触发器;
点缀是**叠加的环境布景**,不重复各章已有的玩法主体。改坐标/数量/色调即可重新布置。

---

## 三-bis、逐章专属精修 (ChapterArt) — 深度精修层

在通用「档案 + 点缀」之上,每章还有一份**手工编排的标志性主景**,统一由
`scripts/chapters/ChapterArt.gd` 提供。`ChapterBase._apply_world_rebuild()` 在铺完
通用点缀后调用一次 `ChapterArt.build(self, id)`,内部 `match id` 分发到各章的 `_<章节>()`
构建函数。**不需要改任何章节脚本**(天城也走这条统一路径)。

每章主景(均避开玩法主体、碰撞体避开通道):

| 章 | 专属主景 |
|---|---|
| city_of_destruction | 身后燃烧的废墟之城(带火光窗)、浓烟、火星雨、前方逃生之门微光 |
| slough_of_despond | 路侧大片浑浊泥沼水面(动画水)、半沉枯树 |
| wicket_gate | 把窄门嵌进一道大石墙,门内涌出迎接的暖光束 + 灯 |
| interpreter_house | 室内化:两侧墙 + 屋梁天花 + 发光寓意画框 + 壁炉火 |
| hill_difficulty | 山顶巨岩 + 远山脊 + 脚下清泉(动画水)+ 两条入暗的岔路 |
| palace_beautiful | 宫后高塔群 + 两尊守门石狮 + 旗 |
| valley_humiliation | 亚玻伦的喷火巨拱 + 火堆 + 火星雨 |
| valley_shadow_death | 紧贴窄道(x±4)的高耸黑峡 + 两侧黑渊 + 冷焰 + 远处冷色黎明 |
| vanity_fair | 两列花哨摊位 + 彩旗 bunting + 镀金偶像 |
| doubting_castle | 笼罩牢房的森严城堡(城垛墙 + 双塔 + 冷光窗)+ 雾 |
| delectable_mountains | 翠绿丘峦 + 地平线上初见的天城微光 |
| enchanted_ground | 诱人催眠的发光凉亭(拱 + 叶顶 + 软光 + 长椅)+ 梦尘 |
| wilderness_road | 远方台地群 + 路边巨石枯骨 + 孤远目标微光 |
| river_of_death | 彼岸荣光:发光的「天使群」+ 光束 + 河面动画微光 |
| cross_and_tomb | 十字架后破晓的荣光光束 + 远丘 + 升腾光尘 |

**自定义动画着色器**(全部缺失即优雅回退):
`assets/shaders/glory_gold.gdshader`(脉动金 + 菲涅尔泛光)、`godray.gdshader`(加性神光柱)、
`water.gdshader`(波动 + 菲涅尔深浅 + 闪光)。

**专属精修样板**:`celestial_city` 走最丰富的 `CelestialCityArt.build()`(分层金城 + 门洞光帘 +
6 道神光 + 荣光逆光 + 升腾光尘)。要精修某章,改 `ChapterArt.gd` 里对应的 `_<章节>()` 即可。

---

## 三-ter、角色立绘 (Character billboards)

主角与 NPC 不再是"胶囊 + 球"灰模,而是用真实人物画当**广告牌立绘**站进 3D 世界
(主角 = pilgrim,Evangelist = evangelist,等等)。

- `scripts/render/CharacterBillboard.gd`:`make(tex, height)` 生成 Y 轴广告牌 `Sprite3D`
  (始终面向相机但保持竖直,unshaded,alpha 裁切,脚踩地面)。
- `AssetLib.figure(speaker)`:按 `SPEAKER_MAP` 解析出 stem,优先加载
  `assets/characters/figures/<stem>.webp`,回退 `.png`,童趣模式优先 `_child` 变体;
  没有立绘则返回 null(调用方回退灰模胶囊)。
- 接入点:`ChapterBase.make_npc()`(NPC)、`PlayerController._build()`(主角,隐藏胶囊+头)、
  `Companion.setup()`(同伴)。
- `tools/gen_figures.py`:用 **OpenCV GrabCut** 把人物从画背景中干净抠出(前/背景分割,
  无需下载模型),生成透明 `figures/<stem>.webp`;没装 OpenCV 时回退到 flood-fill + 椭圆羽化。
  需要 `pip install opencv-python` 以获得最佳质量。

**覆盖/重生成**:把你自己的**透明** `pilgrim.webp` 等放进 `assets/characters/figures/`
即可覆盖自动抠图(`.webp` 优先于 `.png`)。立绘是半身像,站立时呈"半身人像"感;
要全身请放全身透明图。重生成:`python3 tools/gen_figures.py`。

---

## 四、PBR 贴图

### 表面库(MaterialKit)
`assets/textures/pbr/<surface>_{albedo,normal,rough,ao}.png`(512²,可平铺)。
表面名见 `MaterialKit.SURFACES`。任一贴图缺失 → 该通道跳过,材质仍是干净的画味纯色。

### 逐章地面
- albedo = 现有 `assets/textures/ground/<id>.png`(未改)
- 法线 = `<id>_n.png`、粗糙度 = `<id>_r.png`(由 `gen_pbr.py` 从 albedo 派生)

### 重新生成 / 替换
```bash
python3 tools/gen_pbr.py all        # 表面库 + 地面派生(约 9 秒)
python3 tools/gen_pbr.py surfaces   # 只重生表面库
python3 tools/gen_pbr.py ground     # 只重生地面法线/粗糙度
```
想用更高质量的手绘/AI 贴图:直接用同名文件覆盖 `assets/textures/pbr/` 里的图即可,
代码零改动自动生效。

> **导入提示**:法线/粗糙度/AO(及地面 `_n`/`_r`)在 Godot 里最好设为**线性导入(关 sRGB)**,
> 法线图设为 Normal Map 类型,可达到最佳效果。在 painterly 后处理下,默认导入其实也已经够看。

---

## 五、平台 / 性能

- **当前渲染器 = `gl_compatibility`(全平台/网页都能跑)**:PBR 材质、逐章实时布光、程序化天空、
  辉光、色调映射、painterly 全屏 shader、水/神光/金辉 spatial shader、角色立绘——全部生效。
  体积雾、SSAO/SSIL(Forward+ 专属)被自动忽略,无报错、画面无碍。
- ⚠️ **不要切回 Forward+**,除非只做桌面、且确认机器支持 Vulkan。Forward+ 需要 Vulkan/WebGPU;
  在 WebGL2 网页或非 Vulkan 环境下会让 **3D 渲染全黑**(2D HUD 仍在显示),曾因此踩坑已回退。

### 调性能 / 关效果
- 关 painterly:把某章 `post` 设 `{"strength": 0.0}`,或在 `PainterlyPostFX` 里不挂载。
- 油画笔触强弱:painterly 的 `brush`(笔刷大小)、`strength`(混合度);shader 里 `RADIUS` 常量控制采样半径(默认 3 = 64 采样)。
- 草地用单个 MultiMesh(一次 draw call);道具数量在各章 `dressing` 里调。

---

## 六、上线前必做(因为新增了脚本与贴图)

1. 用 Godot 编辑器打开工程一次(或 `godot --headless --import`),让它:
   - 导入新贴图(`assets/textures/pbr/*`、`assets/textures/ground/*_n|_r.png`)
   - 注册新 `class_name`(MaterialKit / PropKit / ChapterArtProfiles / PainterlyPostFX)
2. 跑一遍 `python3 tools/validate_assets.py`(应 ✓)。
3. 网页导出前按上面「平台」一节处理渲染器。
