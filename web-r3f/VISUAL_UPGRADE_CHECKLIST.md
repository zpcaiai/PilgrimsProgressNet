# R3F 画质冲刺清单 · Pilgrim's Progress (web-r3f)

> 目标：在**不换引擎**的前提下，把 web-r3f 的观感往上拉一档，并验证"画面瓶颈是资产/材质，而不是 Three.js"。
> 适配现状：`three@0.169` · `@react-three/fiber@8.17` · `@react-three/drei@9.114` · `@react-three/postprocessing@2.19`（以下 API 均在这些版本内可用，WebGPU 例外，见 P3）。

> **进度（已实现）**：✅ **P0 全部完成** — #1 程序化细节贴图(`lib/detailMaps`)、#2 三平面地面(`lib/triplanarMaterial`，全 16 章默认开)、#3 每章调色(`lib/colorGrade` `ColorGrade`+`GRADES`×16)、#4 曝光 1.08 + SSAO 20→7/r0.22。额外：内联招牌大件自动加细节(`AutoSurfaceDetail.tsx`)、移动端自动回退(`lib/quality.ts` `QUALITY`)。
> ✅ **P1 也已完成** — #5 实例化植被(`InstancedNature.tsx` `GrassField`+`FlowerField`，GPU 风摆，密度按 `QUALITY.vegetation`)接入乐山/困难山/受难地；#6 真实水面(`Water.tsx` 反射+滚动法线波纹，移动端按 `QUALITY.reflections` 回退)接入泥潭(死河本就反射)；#7 天空(`Atmosphere` `SunDisc`+`CloudBank`，经 SceneFx 的 `sun`/`clouds` 预设)接入乐山/天城/困难山；#8 圣光(`HolyLight.tsx` 放射光束+脉动核心)接入天城门/受难十架。
> ✅ **P2(管线)已完成** — #9/#11 GLB+Draco+KTX2 落地管线(`lib/loaders.ts` + `components/three/ModelProp.tsx`，Draco/Basis 已 vendored 到 `/public/draco`、`/public/basis`，自带无需 CDN;往 `/public/models` 放 `.glb` 并设 `src` 即可换上精模,代码零改动) + 窄门升级为高精度程序化模型(石柱+拱券+包铁橡木门)作为占位;#10 角色程序化行走动画(`Player.tsx` 加了从髋部摆动的腿 + 游泳打水)。
> ✅ **美术资产已用代码生成**(`tools/gen_models/`,trimesh+pygltflib,无需 Blender):`build_props.py` 生成真 `.glb` 英雄精模(疑惧堡 / 天城门 / 窄门)→ `/public/models`;`build_character.py` 生成节点动画小人 `pilgrim.glb`(关节层级 + 烘焙 `Walk` 动画,非蒙皮,规避扭曲风险);`render_preview.py` 出预览图肉眼核对(四个模型均正确)。已接入:窄门(Ch2)、天城门(Ch16,带程序化回退)、疑惧堡远景(Ch13);`pilgrim.glb` 放在 `Player.tsx` 的 `PLAYER_MODEL_SRC` 开关后(默认仍用会随灵命染色的程序化小人)。专业美术可用更高精度 GLB 覆盖 `/public/models/*.glb`,代码零改动。沙箱无 GPU,行走"动起来"未实测,但 glTF 结构经双解析器校验。

---

## 0. 你已经做对的（不用再碰）

这套管线起点其实很高，常见"新手清单"里的便宜活你基本做完了：

- **IBL 环境光**：`Game.tsx` 里用 `<Environment>` + 4 个 `<Lightformer>` 做了无网络的程序化环境贴图（金属/布料/水有像样的环境反射）。
- **阴影**：真实投影太阳 `directionalLight`（2048 shadow map）+ drei `<SoftShadows>` 面光软阴影。
- **后处理**：`EffectComposer` 已挂 SSAO + Bloom + Vignette + SMAA，且 `antialias:false` 交给 SMAA——这是对的选择。
- **色彩管线**：未覆盖 `toneMapping`，即用 R3F 默认的 **ACESFilmic + sRGB 输出**（0.169 默认开启 ColorManagement），正确。
- **每章氛围**：`SceneFx.tsx` 为 16 章各自调了渐变天空、粒子层、光轴、点光、路边十字架。

**真正的瓶颈（看了 `NatureKit / NaturalGround / Player`）：**
1. 所有材质都是**纯色 `meshStandardMaterial`，零贴图**（无 albedo/normal/roughness/AO），表面像塑料；
2. 几何体全是**程序化基本体**（锥/胶囊/盒/二十面体），人物和道具偏方块；
3. 人物**没有真正的行走动画**（只有手臂 lerp + 游泳划水）。

下面按"性价比"（影响 ÷ 工作量）排序。工作量：**S ≈ 几小时 · M ≈ 约 1 天 · L ≈ 多天**。

---

## P0 — 最高性价比（无需新美术资产，先做这一档）

| # | 项目 | 现状 | 升级做法（落到文件/API） | 工作量 | 影响 |
|---|------|------|--------------------------|--------|------|
| 1 | **程序化材质细节（法线+粗糙度）** | 纯色，无贴图 | 用 canvas/noise 生成一张可平铺的 normalMap + roughnessMap（一次性），给 `NaturalGround`、`Rock`、`Tree` 树干等共享材质挂上 `normalMap` / `roughnessMap` + `repeat`。零外部资产。 | M | ★★★★★ |
| 2 | **地面贴图/三平面映射** | `NaturalGround` 是起伏纯色平面 | 地面占屏面积最大，收益最高。给它上可平铺的 albedo+normal（草/土/石），或写一个三平面（triplanar）noise 材质（`onBeforeCompile` 注入），消除"色块感"。 | S–M | ★★★★★ |
| 3 | **每章调色 LUT** | 仅 ACES 默认 | 在 `EffectComposer` 加 `LUT`（或先用 `HueSaturation`+`BrightnessContrast`）。按 `sceneId` 切不同 grade，和你已有的天空/粒子情绪呼应，"电影感"立刻出来。 | S | ★★★★☆ |
| 4 | **曝光 + SSAO 调参 + 接触阴影** | SSAO `intensity=20` 偏脏；小物件发飘 | 设 `gl={{ toneMappingExposure: 1.05 }}`；SSAO intensity 降到 ~6–10、radius 调大；给小道具加 drei `<ContactShadows>` 落地。 | S | ★★★☆☆ |

**P0 实现要点（节选）**

材质细节——做一张共享的程序法线贴图，避免任何下载：

```tsx
// lib/detailMaps.ts
import * as THREE from 'three'
export function makeNoiseNormal(size = 256, repeat = 8) {
  const c = document.createElement('canvas'); c.width = c.height = size
  const ctx = c.getContext('2d')!, img = ctx.createImageData(size, size)
  for (let i = 0; i < img.data.length; i += 4) {
    const n = 128 + (Math.random() - 0.5) * 40           // 轻微扰动
    img.data[i] = n; img.data[i+1] = n; img.data[i+2] = 255; img.data[i+3] = 255
  }
  ctx.putImageData(img, 0, 0)
  const t = new THREE.CanvasTexture(c)
  t.wrapS = t.wrapT = THREE.RepeatWrapping; t.repeat.set(repeat, repeat)
  return t
}
// 用法：<meshStandardMaterial color={color} normalMap={normal} normalScale={[0.4,0.4]} roughness={1}/>
```

调色 LUT（postprocessing 2.19 自带 `LUT` effect）：

```tsx
import { LUT } from '@react-three/postprocessing'
import { LUTCubeLoader } from 'postprocessing'
// 或先零资产方案：<HueSaturation saturation={0.08}/><BrightnessContrast contrast={0.06}/>
```

> 做完 P0 再回看：如果观感明显跳了一档，就证明"是资产不是引擎"，PlayCanvas/UE 的念头可以放下了。

---

## P1 — 高影响，中等工作量

| # | 项目 | 现状 | 升级做法 | 工作量 | 影响 |
|---|------|------|----------|--------|------|
| 5 | **植被实例化** | `GrassClump/Tree` 逐个 mesh，密度上不去 | 用 drei `<Instances>/<Instance>` 或 `InstancedMesh`，让乐山（Delectable Mountains）草木密度×10–50，虚华市（Vanity Fair）人群更密，绘制成本几乎不变。 | M | ★★★★☆ |
| 6 | **死亡之河真实水面** | 现为 `water.ts` 逻辑 + 普通材质 | 河是招牌场景：用 drei `MeshReflectorMaterial`（反射+模糊+法线扰动）或自写滚动法线的折射材质，水深已和 faith/fear 联动，视觉到位后这一幕封神。 | M | ★★★★☆ |
| 7 | **天空升级** | `GradientSky` 渐变球 | 加太阳盘/柔和云层，或用 drei `<Sky>` / `<Clouds><Cloud/>`；天国之城/乐山尤其受益。 | S–M | ★★★☆☆ |
| 8 | **"圣光"英雄元素** | 已有 Bloom + LightShafts | 给十字架、圣甲、天国城门加 `emissive` + 提 `emissiveIntensity`，配合现有 Bloom 做神圣高光时刻（受难地、入城）。 | S | ★★★★☆ |

---

## P2 — 高影响，偏内容/资产工作量

| # | 项目 | 现状 | 升级做法 | 工作量 | 影响 |
|---|------|------|----------|--------|------|
| 9 | **地标级 GLB 道具** | 全程序化 | 只给镜头会停留的地标做精细 GLB（窄门、受难十字架、天国城门、疑惧堡），Draco 压缩；其余继续程序化。"好钢用在刀刃"。 | M–L | ★★★★☆ |
| 10 | **骨骼角色 + 行走/待机循环** | `Player` 是基本体，无走路循环 | 最能提升"质感"的一项——动作卖画面。两条路：① 低成本：给现有基本体加程序化走路循环（腿/臂摆动）；② 彻底：换低模骨骼 GLB + 动画片段（drei `useGLTF`/`useAnimations`）。 | M（程序化）/ L（骨骼） | ★★★★★ |
| 11 | **KTX2/Basis 纹理管线** | 无纹理 | 一旦开始用贴图，统一压成 KTX2（`KTX2Loader`/drei `useKTX2`），保证网页/手机加载仍快。 | S（搭一次） | ★★★☆☆ |

---

## P3 — 战略级大改（P0–P2 之后再决定）

| # | 项目 | 说明 | 工作量 | 备注 |
|---|------|------|--------|------|
| 12 | **WebGPU 渲染器（three WebGPURenderer + TSL）** | 性能余量更大、着色更现代，但 **R3F v8 的 `<Canvas>` 走 WebGL**；要用 WebGPU 得迁移到 **R3F v9（React 19）** + three 的 webgpu 入口，不是 drop-in。 | L + 迁移风险 | 你现在的瓶颈不是渲染器，所以**别先做这个**。等 P0–P2 把资产拉满、确实撞到性能墙了再评估。 |

---

## 建议的执行顺序

1. **先做 P0 #1 + #2 + #3**（约一个周末）。这三项动到的是"满屏都在看"的材质和调色，最能立竿见影，也用来**验证瓶颈是资产而非引擎**。
2. 再做 **#10 行走动画** 和 **#6 河水**——一个提升全局"活人感"，一个点亮招牌场景。
3. 其余按章节需求穿插（乐山上 #5 植被、天国城 #7/#8 圣光）。
4. WebGPU（#12）单独立项，放到最后再判断。

**一句话**：你的引擎没问题，差的是材质贴图、角色动作和几处招牌场景的"特写资产"。这些在 R3F 里都能做，且大半是低成本就能验证的。
