# 世界重塑 · 油画/绘本级 3D (World Rebuild)

把 16 章的 3D 世界从「平面色块方盒 + 单一天光」整体重塑为**油画/绘本级**观感:
**逐章建模(程序化道具)+ PBR 贴图 + 逐章布光 + 全屏 painterly 后处理**。

整套系统沿用项目原有的「程序化、素材可选、缺失即优雅降级」架构——没有任何外部
3D 模型文件,所有几何都在代码里生成,任何贴图缺失都会自动回退,不会报错。

---

## 一、改了什么(总览)

| 层面 | 内容 | 文件 |
|---|---|---|
| 渲染后端 | 主渲染器切到 **Forward+**(桌面画质优先),网页/移动回退 `gl_compatibility`;开启 MSAA 4x、软阴影、4K 阴影图、各向异性过滤 | `project.godot` |
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

- **桌面(Forward+)**:体积雾、SSAO/SSIL、完整辉光、软阴影、ACES/AGX 色调映射全开。
- **网页 / 移动(`gl_compatibility`)**:体积雾/SSAO/SSIL 自动忽略(无报错);PBR、逐章布光、
  painterly 滤镜(2D 全屏 shader)依旧生效,画面仍是油画味,只是少了体积光等重型效果。
- ⚠️ **网页导出**:WebGL2 只支持 `gl_compatibility`。当前主渲染器是 `forward_plus`(按你的选择,桌面优先)。
  导出网页时,要么把渲染器切回 `gl_compatibility`(画面自动降级,仍好看),要么用实验性的
  **WebGPU** 导出以保留 Forward+ 效果。`project.godot` 已保留 `rendering_method.mobile="gl_compatibility"` 作回退。

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
