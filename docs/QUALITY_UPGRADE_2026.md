# 画质与体验升级方案 2026

> 结论先行：**能，而且还有明显的一档。**
> 这份文档分两部分——第一部分是**现状证据**（每条都有 `文件:行号`），
> 第二部分是**分批实现记录**。**批次 1–4 全部已实现**，通过 gdparse、数据校验、
> 场景校验与 glTF 结构校验；尚未在 Godot 编辑器里实机运行（沙箱无引擎二进制）。

问题的核心不是"缺功能"，而是**已经写好的能力从来没有真正跑起来**：

- 16 章的雾、天空、环境光、SSAO、体积雾都有人认真调过，但 **一行都没到屏幕上**；
- 每个 GLB 里有 36 个 `CAM_*` 机位标记，**全项目没有任何代码读取它们**；
- 成人（Devout）模式**完全没有任何屏幕分级**——油画滤镜只挂在儿童模式；
- 角色一只眼睛就用掉 4096 个三角形，而**没有脚踝、没有手肘、没有头部转动**。

---

## 第一部分：现状证据

### 1. 渲染管线：桌面端也在跑 gl_compatibility

```
project.godot:127   renderer/rendering_method="gl_compatibility"
project.godot:128   renderer/rendering_method.mobile="gl_compatibility"
```

`rendering_method` 是**基础键**（没有平台后缀），所以 **桌面导出同样走兼容渲染器**。
后果是下面这些代码在任何平台上都不会执行：

| 代码 | 位置 | 谁在请求 |
|---|---|---|
| `volumetric_fog_*`（体积雾全套） | `ChapterBase.gd:845-853` | 8 个章节 profile：`ChapterArtProfiles.gd:62,85,181,202,246,286,324,345,368` |
| `ssao_enabled / radius / intensity` | `ChapterBase.gd:894-897` | profile 默认 `"ssao": true`（`ChapterArtProfiles.gd:39`）→ 16 章全开 |
| `ssil_enabled` | `ChapterBase.gd:898` | 死荫幽谷显式开启（`:207`） |
| `sdfgi_*`（实时全局光） | `ChapterBase.gd:906-909` | 写实模式整块 |
| `ssr_*`（屏幕空间反射） | `ChapterBase.gd:911-914` | 写实模式整块 |
| `light_angular_distance` 物理软阴影 | `ChapterBase.gd:958` | 兼容渲染器只有固定 PCF |

代码注释写着"在 gl_compatibility 回退时会被无害忽略"（`ChapterBase.gd:826-828`），
但兼容渲染器**不是回退，是唯一路径**——注释和配置是矛盾的。

### 2. 十六章共用一片天、一层雾

```
GlbChapter.gd:35    setup_environment(Color(0.5,0.55,0.62), Color(0.58,0.58,0.6), 0.7)   # 所有章同一个灰
GlbChapter.gd:92-97 env.fog_density = 0.011; env.fog_light_color = Color(0.62,0.64,0.70) # 硬编码
```

第二段在 `_apply_environment()` **之后**执行，直接覆盖掉刚写进去的每章雾色与密度。
所有 16 章走的都是 GLB 路径，所以**灭亡城的余烬雾霭和喜悦山的清晨空气长得一模一样**。

另外 profile 里的 `ambient.color` 是**死数据**：`setup_environment` 把环境光源设为
`AMBIENT_SOURCE_SKY`（`ChapterBase.gd:281`），而旧代码只在 `AMBIENT_SOURCE_COLOR`
时才写颜色（`ChapterBase.gd:835-836`）——16 组手调的环境色从未生效。

`_apply_environment()` 也从不改写 `ProceduralSkyMaterial`，所以天空永远是那一片灰。

### 3. 成人模式没有任何屏幕分级

```
ChapterBase.gd:805-806  if not RenderConfig.is_realistic(): _attach_postfx(...)
GlbChapter.gd:84-85     同样的门控
```

Devout 模式下**没有暗角、没有颗粒、没有镜头特性、没有分色调**——
`vignette` / `grain` 全项目只存在于 painterly shader 的参数里。
再叠加"兼容渲染器没有 SSAO"，成人模式的画面缺少了两层最主要的空间感来源。

### 4. 角色：三万面的木偶

`HumanoidFigure.gd` 用 19–20 个图元拼一个人，**全部使用 Godot 默认细分**
（`SphereMesh` 64×32 ≈ 4096 tri）：

- 单个人物 ≈ **32,000 三角形**，玩家 ≈ 37,000（多一个胡子球）
- **每只眼睛 4096 tri**（`HumanoidFigure.gd:112-114`），和整个躯干同级
- 每个部位单独 `material_override`，**零共享**，一个人 20 个 draw call
- 一章有 42 个 `NPC_` 标记

动画侧（`HumanoidAnimator.gd`）只驱动 7 个节点，缺的是：

| 缺失 | 证据 |
|---|---|
| **步幅锁定**（脚不滑） | 频率是常量 `WALK_FREQ := 7.5` × 速度粗调（`:126-130`）→ 必然滑步 |
| 脚踝 | 没有 ankle 节点，脚永远平插进地面 |
| 手肘 | 上臂是一根整圆柱（`HumanoidFigure.gd:246-253`） |
| 头部转动 / 注视 | 头是躯干静态子节点，不参与动画 |
| 眨眼 / 表情 | 眼睛是两个静态球，无眉、无嘴、无 blend shape |
| 呼吸 / 衣摆 / 起停重心 | 只有 `sin(_t)` 上下浮动 |
| 坡度适应 | 全项目无地面法线查询 |
| 待机变化 | 单一 `sin` 循环，无 idle break |

### 5. 相机：一台焊在背上的摄像头

- 直接作为玩家孙节点，**无 SpringArm3D**（全项目零引用）→ 穿墙
- 逐帧刚性跟随，**无阻尼、无前瞻**（`PlayerController.gd:154-163`）
- **FOV 全项目零赋值**，距离恒定 ≈10.4 m
- **36 个 `CAM_*` 机位标记完全未被使用**：binder 把它们加进
  `cinematic_camera` 组（`ImportedSceneBinder.gd:190`），
  而 `grep -rn "cinematic_camera" scripts` **只有这一处**

### 6. 点光源全部不投影

全项目 30+ 处 `OmniLight3D.new()` / `SpotLight3D.new()`，
**没有任何一处设置 `shadow_enabled = true`**——
`grep shadow_enabled scripts` 只命中方向光两处（`ChapterBase.gd:955,965`）。
室内章节（讲解者之家、美宫、怀疑堡）因此完全没有接触阴影。

另外 `_apply_lighting()` **每次调用都新建一盏补光**（`ChapterBase.gd:961-966`，无去重），
重建两次就双倍补光、画面发灰。

### 7. 连续性与完整性的缺口

| 缺口 | 证据 |
|---|---|
| 章节切换是**硬切**：旧场景 `queue_free()` + 新场景 `add_child()` 同帧完成，只有切完之后才从黑淡入 | `ChapterManager.gd:425-446` + `Transition.gd:34-39` |
| `Transition.cover()` 文档自称是主要用法，**全项目零调用** | `Transition.gd:43-58` |
| 成就映射**缺 3 章**（旷野路、绝望泥潭、迷魂地），"全章完成"判定只按 13/16 算 | `Achievements.gd:11-25` |
| `show_credits` 标志被 4 个数据文件写入，**无任何读取者**，也没有演职表场景 | `SpiritualStateManager.gd:246-247` |
| **无 NG+**：`start_new_game` 全量清空，记住的经文卡也一并丢弃 | `Main.gd:263-268` |
| 结局屏只有 Return to Title / Quit，不接成就、不接演职表 | `Main.gd:389-404` |
| 屈辱谷程序化胜利**不写 `defeated_apollyon`**，而下一章 `required_flags` 需要它 | `ValleyHumiliation.gd:56-61` |
| 窄门程序化分支**没有出口**（提示玩家"继续向前进入经文之门"，但那道门由 GLB 标记提供） | `WicketGate.gd:150-164` |
| `can_enter_chapter()` / `evaluate_completion_conditions()` / `get_previous_chapter_id()` / `MVP_ROUTE` / `VERTICAL_SLICE_ROUTE` 零调用 | `ChapterManager.gd:187-205, 291-303, 359-370` |
| 11 个对话 JSON 无任何脚本引用（`hopeful_keep_awake`、`receive_armor`、`apollyon_intro` …） | `data/dialogues/` |
| `primary_temptation.type`（16 章各一）与 `get_temptation_resistance` 的 10 个 key 完全对应，但**只被生成脚本写入，未被 GDScript 读取** | `enrich_chapter_design.py:44` |

---

## 第二部分：路线图

### 批次 1 —— 渲染双档 / 十六章差异化 / 人物与相机 ✅ 已实现

全部是 `.gd` / `.gdshader` / `project.godot` / 一个 JSON，**没有编辑器连线，没有新预制体**，
`gdparse` 全通过，`verify_scenes` 的 marker 名称检查 16/16 全通过。

#### 1.1 双档渲染

```
project.godot   renderer/rendering_method      = "forward_plus"      ← 桌面
                renderer/rendering_method.mobile = "gl_compatibility"
                renderer/rendering_method.web    = "gl_compatibility" ← 新增
```

外加分平台的阴影贴图尺寸、MSAA、TAA、SSAO/SSIL 质量。

新增 **`scripts/render/QualityTier.gd`**：唯一一个回答"这个构建负担得起什么"的地方。
它读 `RenderingServer.get_current_rendering_method()`，返回 `high / mid / low`，
并提供 `supports_ssao()`、`supports_volumetric_fog()`、`point_shadow_budget()`、
`mesh_detail()`、`segments(full, floor)` 等。
所有渲染相关代码改为**问它**，而不是假设渲染器——同一份场景代码在两档下各自画出最好的画面。

`ChapterBase._apply_environment()` 里的 SSAO / SSIL / SDFGI / SSR / 体积雾全部按 tier 判定，
不再往兼容渲染器里写注定被丢弃的参数。
Forward+ 上真实 GI 接管后，"假环境光垫底"从 1.15 降到 0.85，画面不再被洗平。

#### 1.2 十六章重新长得不一样

- `GlbChapter.gd` 那段硬编码雾改为**只提供地平线兜底**，每章 profile 的雾色/密度胜出。
- `GlbChapter.gd` 的 `setup_environment` 改为从**本章 profile** 取天顶色与地平线色。
- 新增 `ChapterBase._tint_sky()`：从每章自己的太阳色/能量/雾色**推导**天空
  （天顶随日光冷暖与强度、地平线与雾同色、太阳圆盘可见），零额外美术工作量；
  profile 里写 `"sky": {...}` 可以覆盖。
- `ambient.color` 通过 `ambient_light_sky_contribution = 0.65` **真正生效**（不再是死数据）。

#### 1.3 成人模式的电影级分级

新增 **`assets/shaders/cinematic.gdshader`** + **`scripts/render/CinematicPostFX.gd`**：
暗角、胶片颗粒、边缘色散、分色调（冷阴影）、局部对比度（unsharp）、每章色调。

关键设计：**参数从每章的太阳/雾自动推导**——暖阳→暖调、暗章→更重的画框与更冷的阴影；
在没有 SSAO 的兼容构建上自动提高局部对比度与颗粒，替代缺失的接触阴影并掩盖 GLES 色带。
`ChapterBase._attach_grade()` 按模式二选一：儿童=油画，成人=电影。

#### 1.4 人物大修

`HumanoidFigure.gd` 重写：

| 项 | 之前 | 之后 |
|---|---|---|
| 单人三角形 | ~32,000 | ~3,500（桌面）/ ~2,000（网页） |
| 材质 | 每个部位一份，20 个 | 按 (颜色,粗糙度,foe) 缓存共享 |
| 手臂 | 一根圆柱 | 肩 → 上臂 → **肘** → 前臂 → 手（+拇指块） |
| 腿 | 髋 → 膝 → 脚 | 髋 → 膝（+膝盖）→ **踝** → 脚 + 脚趾 |
| 头 | 焊在躯干上 | 独立 `HeadPivot`，可转动 |
| 脸 | 两个球 | 眼白+虹膜（分眼睑节点，可眨）、眉、鼻、嘴、下颌 |
| 边缘光 | 无 | 全身 `rim_enabled`——**在兼容渲染器上也生效**，暗章里把人从背景里剥出来 |
| 个体差异 | 无 | 身高/肩宽/站姿/头围按姓名哈希抖动 |

`HumanoidAnimator.gd` 重写：

- **步幅锁定**：`cadence = π × speed / step_length` —— 一个步幅正好走一步的距离，**脚不再滑**。这是"走路"和"滑行"之间最大的一条差别。
- 脚踝滚动（脚跟着地 → 全掌 → 脚尖蹬离）
- 手肘在前摆时折叠、后摆时垂放
- **头部注视**：对话时转头看着玩家（`Interactable.face_toward_player` 接线，全程保持，结束后自然放开），待机时缓慢漂移，转身时看向转向侧
- **眨眼**（随机 1.8–6.0 s）
- 胸腔呼吸（移动时更快更深）+ 躯干反向扭转
- **起停重心**：加速时前倾过冲、减速时后坐——这是"开始走"和"停下"真正被看见的原因
- 衣摆逆着步伐摆动
- 坡度适应（`CharacterBody3D.get_floor_normal()`，零射线开销）
- 原地转身的脚步碎动与反向侧倾
- 待机小动作（重心换脚 / 环顾 / 耸肩），每 4–11 s 随机一次
- 游泳与泥沼挣扎两套特殊步态同步升级（含抬头换气）

#### 1.5 相机语言

`PlayerController.gd`：

- **SpringArm3D**：撞墙自动拉近（室内章节从此可玩）
- 阻尼跟随 + **行进方向前瞻**（最多 1.4 m）
- **FOV 呼吸**：常态 68 / 奔跑 74 / 对话 58
- 游泳与深陷泥潭时自动拉近
- `teleport()` 自动 `snap_camera()`——否则延迟跟随会横跨整关追过来
- 新增 `push_cinematic(xform, dur)` / `release_cinematic()`：用**独立相机**做过场（不与 SpringArm 抢变换）

新增 **`scripts/level/ChapterCamera.gd`** —— 终于用上那 36 个机位标记：

- 章节开场时挑一个 overview/wide/reveal 类标记，**朝玩家取景**，
  在标题卡与开场旁白播放期间保持 4.6 s（那段时间玩家本来就被旁白锁住，不损失操作），
  然后缓动交还给游戏相机；**任意按键跳过**。
- 静态 `ChapterCamera.shot("ThroneApproach", 3.0)` 供章节脚本在剧情点调用
  （望远镜、圣城开门等），调用方不需要知道相机在哪。

#### 1.6 点光源阴影

`ChapterBase._grant_point_shadows()`：按 tier 给**离出生点最近的 N 盏**点/聚光灯开阴影
（高档 6 盏 / 中档 2 盏 / 网页 0 盏）。
同时修掉 `_apply_lighting()` 每次重建都新增一盏补光的累积 bug（改为复用命名节点 `FillLight`）。

#### 1.7 连续性与完整性

- **真正的过场**：新增 `Transition.veil_out()`，`ChapterManager.transition_to()` 先淡出再换场，
  `ChapterExitTrigger` 与 `go_to_next_chapter()` 全部改走它。淡入淡出终于在切点的**两侧**。
- 补齐 3 个缺失成就（`road_taken` / `out_of_the_mire` / `stayed_awake`），
  含中英文文案，写入 `data/achievements.json`（22 条）。
- **演职表**：`Main._show_credits()` 终于读了 `show_credits` 这条一直被写入虚空的标志；
  内容含 16 章标题、记住的经文数、旅程日志摘要。
- **New Game+**：`start_new_game_plus()`——重置这一趟旅程（flag/灵性状态/任务），
  保留经文卡与成就，打上 `new_game_plus` 标记。
- 结局屏改为闭环：演职表 / 成就 / 再走一次 / 返回标题 / 退出。
- 修 `ValleyHumiliation._on_victory` 不写 `defeated_apollyon`（下一章 required_flags 需要它）。
- 修窄门程序化分支无出口：`_ensure_forward_exit()` 在没有其它出口时补一个。

---

### 批次 2 —— 骨骼蒙皮角色 ✅ 已实现

批次 1 把"程序化图元人"做到了它的上限。再上一档必须换表示方式，这一批换了。

**新增管线（纯 Python，不需要 Blender）**

| 文件 | 作用 |
|---|---|
| `tools/scene_gen/glb_lib.py` | GLB 写出器新增 **蒙皮与动画**：`JOINTS_0` / `WEIGHTS_0` / `skins` / `inverseBindMatrices` / `animations`（旋转采样器） |
| `tools/scene_gen/rig_lib.py` | 27 骨人形骨架 + 扫掠管状肢体几何 + 按候选骨段的反距离蒙皮 + 六段步态采样器 |
| `tools/scene_gen/gen_pilgrim_rig.py` | 生成 `assets/characters/rig/pilgrim.glb` |

**产出**：1215 顶点 / 1688 三角形 / 7 个材质面 / 27 骨 / 6 段动画（Idle、Walk、Run、Talk、Swim、Struggle），162 KB。
静息姿态是纯位移，所以逆绑定矩阵就是 `translate(-restPos)`——写出与调试都很直白。

**运行时**

| 文件 | 作用 |
|---|---|
| `scripts/render/SkinnedFigure.gd` | 实例化、按 `CharacterPalette` **逐材质名重新着色**（Skin/Robe/Robe2/Hair/Accent/Eye/Boot），一个模型服务全部角色 |
| `scripts/render/SkinnedAnimator.gd` | **继承 HumanoidAnimator**，所以 9 处 `find_in()` 调用方一行不用改；把步幅锁定接到 `AnimationPlayer.speed_scale` 上 |
| `scripts/render/SkeletonPoseOverride.gd` | `SkeletonModifier3D`——注视与眨眼写在动画之后、蒙皮之前，这是 Godot 里唯一不会被 AnimationPlayer 覆盖的位置 |
| `scripts/render/FigureFactory.gd` | 唯一入口。模型缺失 / 低档（网页、移动）→ 自动回退到图元人 |

**关键设计**：`SkinnedAnimator extends HumanoidAnimator`。整个项目通过
`HumanoidAnimator.find_in(root)` 拿角色动画并调用 `nudge()` / `look_at_node()` /
`swimming` / `mud_struggling`——继承意味着骨骼版是**零改动的替换件**。

**故意保留图元的两处**：巨人绝望（把獠牙、眉骨、驼峰以绝对坐标嫁接到 `Body` 上）
与灭亡城的家人（自己驱动 `ArmL`/`ArmR` 节点）。两处都是图元专有契约，代码里已注明原因。

**替换成真正的美术**：只要骨骼**名字**与 `rig_lib.BONES` 一致、动画名为
Idle/Walk/Run/Talk/Swim/Struggle、材质名为 Skin/Robe/…，直接覆盖
`assets/characters/rig/pilgrim.glb` 即可，代码一行不改。

---

### 批次 3 —— 场景几何与材质 ✅ 已实现

| 问题（批次 1 文档中列出的） | 现状 |
|---|---|
| 无顶点色 / 无 AO | **`tools/scene_gen/glb_ao.py`**：体素占据网格 + 每顶点半球射线步进 + 接触项，烘进 `COLOR_0`（normalized ubyte4，4 字节/顶点）。`ImportedSceneBinder._apply_baked_ao()` 在绑定时打开 `vertex_color_use_as_albedo`——**Godot 的 glTF 导入器不会自动打开它**，不做这一步烘焙就白烘了 |
| 大多数网格没有 UV | 新增 `cylinder_mesh_uv` / `cone_mesh_uv` / `sphere_mesh_uv` / `torus_mesh_uv` / `lathe_mesh_uv` / `terrain_mesh_uv`；`Scene.cylinder/cone/sphere/torus/lathe/ground` 全部接受 `tex=` 与 `tile=`（米/重复），密度一致 |
| 贴图被硬编码钳在 160 px | `EMBED_MAX` 改为环境变量驱动：桌面 384、`--web` 160，写入 `assets/imported_scenes/web/`；`GlbChapter._scene_path_for_tier()` 在网页构建时优先取 web 版 |
| 地面写出整张背面 | 只保留裙边环，去掉 `2·nx·nz` 个永不可见的三角形（60×60 地面：1800+ → 960 三角形） |
| 颜色启发式把暖色一律判成金属 | 加了否定词表（Ground/Sand/Cloth/Wood/Flame…），并新增 `PBR_ROLES` 显式角色表 + `pbr=` 参数 |
| LOD / shadow mesh 的实际情况 | ⚠️ **勘误**：我原先写"无 LOD"，那只对 **GLB 文件本身**成立（写出器不产生 `MSFT_lod`）。实际跑 `fix_glb_imports.py` 后发现，16 个 `.glb.import` **本来就已经**开着 `generate_lods` / `create_shadow_meshes` / `ensure_tangents`——Patched 0 of 16。所以这一项**原本就没有缺口**。脚本仍然保留：它是新增资源（骨骼角色）和将来手动改动的护栏，并已为 `pilgrim.glb` 预写好正确的 `.import`，第一次导入就是对的 |

**顺带补的洞**：窄门与旷野之路这两章 `tex=` 调用数为 **0**——玩家最先踩到的那块石头、最先走过的那条土路，
全项目最没有表面细节。曲面与地面的 UV 支持是这一批才有的，所以现在给它们上了 cobble / stone / dry_earth，
石头也第一次能贴图（`s.sphere(tex=)` 以前根本不支持）。

**净效果（在你机器上、贴图齐全的真实构建）**：
桌面档 **33.3 MB**（384 px 贴图 + 烘焙 AO），网页档 **19.6 MB**（160 px）。
对比原来单档 20.4 MB：桌面拿到了 5.8 倍的贴图纹素密度和一整层 AO，网页档基本持平。
全 16 章构建约 20 秒。

---

### 批次 4 —— 玩法深度 ✅ 已实现

#### 4A 释放已经写好的系统

- **诱惑抵抗终于接线**。`get_temptation_resistance()` 建模了 10 种试探，
  `DialogueManager` 早就支持 `"conditions": {"temptation": {...}}`，而
  `data/dialogues/` 里**一个都没用过**。
  新增 `tools/data_gen/build_temptation_dialogues.py`，从每章已有的
  `design.primary_temptation`（类型、谎言、`resisted_by`）生成 15 段
  **诱惑时刻**对话。四种出路：**抵挡**（灵性姿态真的胜过难度才出现）、
  **想起**（凭你早先领受的东西，而非你此刻的力量）、**挣扎**（约半难度，站住但有代价）、
  **屈服**（永远可选——一无所有的人总是可以让步，游戏应当允许，并记住）。
  运行时是 `scripts/spiritual/TemptationMoment.gd`：等到本章的压力真的积累起来才开口。
- **对话后果预览**：`get_choice_preview()` 返回 `gain / cost / marks`，HUD 用
  **绿▲ 红▼ 蓝◆** 三色分开显示，并第一次显示选择会设下的 **flag**
  ——本作最长程的后果恰恰住在 flag 里。
- **三个隐藏计量可见**：困倦 / 虚荣压力 / 河深，只在用到它的那一章出现。
- **章节主题开场**：`spiritual_theme` / `core_mechanic` 两个字段过去只被一个走不到的
  回退分支读取；现在每章开场旁白之后作为教学 toast 出现。

#### 4B 关卡深度

- **亚玻伦三阶段真的不一样了**。过去三个阶段只换 `attack_effects` 字典。现在：
  1 **恐吓**——有预兆的范围吼叫，答案是距离；
  2 **控告**——`AccusationCard` 逐条飘来的具名控告，用应许（U）逐句回应，
     **对上的经文伤害翻倍**；不回应就落在你身上；
  3 **困兽之斗**——有闪避窗口的俯冲，冲空后进入**破绽窗口，反击伤害 ×2**。
  阶段提示同时告诉你**该怎么应对**。
- **箭雨渐强**：`pressure_level` 过去只写不读、`fire_interval` 是常量。现在按
  **停留时间**与**累积压力**双轴收紧（1.6 s → 0.45 s），盾牌吸收会缓解，
  并分三档提示。
- **叠加危险**：假地移进深泥中心、窄门箭雨走廊下铺泥、死荫谷最窄处让恐惧区与低语区重叠、
  迷睡之地把"看起来最像怜悯"的休息草地放进睡眠场里。
- **虚荣集市四个摊位各有各的谎**，且每个谎都有**由前面章节解锁的反驳**
  （讲解者之家 / 登顶 / 披上军装 / 站住不被控告）。拒绝不需要学过什么；**回答**需要。
- **牧人考问**：借望远镜之前要你说出山谷里那个谎和回答它的真理，正确答案只对
  真的站住过的人开放。
- **望远镜变成揭示镜头**：相机离开朝圣者，飞向那城，停住，再回来。

#### 4C 关系与叙事

- **同伴重写**：按章节的台词库、按你身上最响的那个压力（绝望/惧怕/疲惫/羞愧/骄傲）选词、
  **可以按 E 回应他**（一起祷告 / 求建议 / 反过来问他好不好）、有会累积的
  `bond` 值让他的话更有分量、绳索式跟随 + 向下射线贴地、说话时转头看你。
  顺带把 `hopeful_keep_awake` 与 `hopeful_cell_encouragement` 这两个从未被引用的文件接上了。
- **重担带着你的罪**：`BurdenColour` 按当下最重的那一项着色（欺哄紫 / 骄傲红 / 羞愧赭 /
  惧怕蓝 / 绝望灰 / 疲惫褐），背包实时改色；滚进坟墓的是**你的**重担，
  落下时**说出它由什么构成**，并在墓中褪成素色——赦免作为**转化**而非删除。
- **见证之云**（美宫）：一整面画像墙，走近才亮起、报出名字；其中一幅由**你实际做过的事**
  选出，走到它时闪回"别人也这样活过"。
- **牢房的记忆**（怀疑堡）：钥匙不再是墙角一个交互点。四个影子站在暗处，
  每一个都是**你这一周目自己的失败**（读你的 flag，没掉进泥潭的人不会被指泥潭），
  答完最后一个，才想起"钥匙一直在怀里"。
- **圣城开门 + 镜子**：两扇真的门叶缓缓打开（窄门早就有开门动画，最后一道门没有）；
  门内的镜子说出**属于你这一趟**的三句话，取自你的 flag 与诱惑时刻的统计。

#### 4D 完整性

- **章节选择**：路线图从只读 Label 变成按钮，走过的章节可以重走。
  这也让 `can_enter_chapter()` 第一次真正被调用——在自由跳转处强制
  `required_flags`（主线仍然不设卡，避免自锁），缺什么会直接说出来。
- **路线变体暴露**：`MVP_ROUTE`(5) / `VERTICAL_SLICE_ROUTE`(9) 从死代码变成标题界面上的
  「旅程长度」；`get_next_chapter_id()` 改为**以当前路线为准**，否则短路线根本停不下来。
- **九个孤儿对话全部接线**：`receive_armor`（穿军装时说出口）、
  `promise_stone_lines`（应许石文字改为数据驱动，并把中文并进该文件）、
  `false_voice_shadow`（FalseVoiceZone 一直支持对话、从没有人设过）、
  `apollyon_intro` / `shadow_valley_entry` / `children_fear`（新增承载触发器）、
  `wilderness_obstinate_returns` / `pliable_in_wilderness`（原来两处触发器错用了「城里」版本）、
  `demo_end_reflection`（结局回顾之后）。
- `GameState.has_visited_chapter()` 让 `visited_chapters` 有了第一个读者。

---

## 重新生成产物

```bash
python3 tools/scene_gen/build_scenes.py          # 16 章 GLB（含 AO 烘焙），~12s
python3 tools/scene_gen/build_scenes.py --web    # 网页轻量版 -> assets/imported_scenes/web/
python3 tools/scene_gen/gen_pilgrim_rig.py       # 骨骼角色 -> assets/characters/rig/pilgrim.glb
python3 tools/data_gen/build_temptation_dialogues.py
python3 tools/data_gen/build_vanity_stalls.py
# 在 Godot 里打开一次让它导入，然后：
python3 tools/scene_gen/fix_glb_imports.py       # 打开 LOD / shadow mesh / tangents
```

## 验证

```bash
find scripts tools -name "*.gd" | xargs gdparse   # 全部 OK
python3 tools/validation/validate_data.py         # PASS
python3 tools/scene_gen/verify_scenes.py          # PASS: 16/16
```

另外做了一遍 **glTF 结构校验**（17 个 GLB：chunk 长度、accessor 越界、bufferView 对齐、
索引越界、属性数量一致、skin joint 越界、动画采样器输入输出等长）——0 问题。

## 上手后重点看的地方

1. **桌面端确认真的是 Forward+**（`QualityTier.describe()` / 启动日志的 `[FigureFactory]` 行会打印）。
   若 macOS 上 Forward+ 有问题，把 `renderer/rendering_method` 改回 `gl_compatibility` 即可，
   `QualityTier` 会自动降档，其它代码一行不用动。
2. **骨骼角色**：`FigureFactory.FORCE = "primitive"` 可以一键 A/B 对比。
   若蒙皮在肩/胯有拉扯，调 `rig_lib.SkinMesh.skin(falloff=)` 或该部位的 `GROUPS` 候选骨。
3. **AO 强度**：`glb_ao.py` 的 `CONTACT_STRENGTH` / `MIN_AO` / `RAYS`；
   `PILGRIM_NO_AO=1` 可临时关掉以便快速迭代。
4. **TAA 鬼影**（细网格如头发、栏杆）：不满意就关 `anti_aliasing/quality/use_taa`。
5. **相机 SpringArm 只与 layer 1 碰撞**；若某章地形不在 layer 1，相机会穿进去。
6. **诱惑时刻的触发时机**：`TemptationMoment.PRESSURE_TRIGGER` / `TIME_TRIGGER`；
   它永远不会打断对话、过场或被锁定的玩家。

---

## 仍未做的事（诚实清单）

- **没有在 Godot 里跑过。** 沙箱里没有引擎二进制，验证到 `gdparse` + 数据校验 +
  glTF 结构校验为止。骨骼蒙皮与 `SkeletonModifier3D` 这两块是最需要你在编辑器里过一眼的。
- **巨人绝望与灭亡城家人仍是图元人**（原因见上，代码里也写了）。
- **面部表情**：骨骼里有 `Jaw` 与两个眼骨，说话时下颌会动、会眨眼，但没有 blend shape，
  所以没有真正的表情系统。
- **`Transition.cover()`** 仍然零调用（`veil_out()` 取代了它的用途）。
- **存档仍然回到本章开头**，不是离开时的位置：`GameState.player_position` 依旧没有写入者。
  这是有意的取舍（章节内状态靠 flag 恢复），但它仍然是一个缺口。
