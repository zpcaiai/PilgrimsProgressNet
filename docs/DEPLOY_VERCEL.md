# 部署到 Vercel · Pilgrim's Road

**一句话**：Vercel 只能托管**前端**——也就是 Godot 导出的网页版 WASM 包（`build/web/`）。
你的 **Python 后端（FastAPI + PostgreSQL + Redis + nginx + alembic）跑不到 Vercel 上**，
它需要真正的容器/服务器主机。所以 Vercel 上要么发**纯单机网页版**，要么前端走 Vercel、
**后端单独部署到别处（HTTPS）**再让前端去连。

> 本文是 [`DEPLOYMENT.md`](DEPLOYMENT.md) §3.4 / §7 的 Vercel 专项展开，命令以 macOS 为例。

---

## 0. 前提：先在本机 Godot 导出 `build/web/`

Vercel 的构建机**装不了 Godot，也跑不了 Godot 导出**（导出需要与引擎同版本的 export
templates，且要带上整个工程与素材）。所以 `build/web/` 必须**在你自己的机器上**用 Godot 导出，
然后把导出的静态目录推给 Vercel。

```bash
# 一次性：Editor → Manage Export Templates → Download and Install（与引擎同版本）
# 然后命令行导出（或在 Project → Export… → Web 里点 Export Project）：
godot --headless --export-release "Web" build/web/index.html
```

导出后 `build/web/` 里应有 `index.html / index.js / index.wasm / index.pck / …`。
**本地先验一遍**（不能直接双击 index.html，浏览器禁 `file://` 加载 WASM）：

```bash
cd build/web && python3 -m http.server 8060   # 打开 http://localhost:8060
```

Web 预设已把**线程关闭**（`thread_support=false`），所以是单线程 WASM，
**普通静态托管即可，无需 COOP/COEP 跨域隔离头**——这正是它能直接上 Vercel 的原因。

---

## 1. 先选模式（决定导出前改哪一行）

导出会把 `scripts/net/NetConfig.gd` 的值**烤进 `.pck`**，所以"连不连后端、连谁"由**导出前**的
配置决定。三种上线形态：

| 模式 | NetConfig 设置 | 后端 | 适合 |
|---|---|---|---|
| **A · 纯单机网页版**（最简单） | `enabled = false` | 不需要 | 只想把游戏挂上网,人人可玩,无账号/排行/聊天 |
| **B1 · 联网·跨域**（推荐的联网做法） | `enabled = true`，`base_url = "https://api.你的域名/api/v1"` | 部署在别处(HTTPS) | 要排行榜/云存档/实时同行/聊天**全功能** |
| **B2 · 联网·同源代理** | `enabled = true`，`base_url = "/api/v1"`，`realtime = false` | 别处(HTTPS),经 Vercel rewrite 反代 | 想避开 CORS,但**不要实时**(见下) |

⚠️ **关于实时（WebSocket）**：`NetConfig.ws_url()` 把 `https→wss` 派生实时地址。
- **B1 跨域**：`base_url` 是完整 https 域名 → 实时走 `wss://api.你的域名/...`，**REST 与实时都正常**。
- **B2 同源代理**：`base_url` 是相对路径 `/api/v1`，浏览器能解析 REST，但
  **Vercel 的 rewrite 不代理 WebSocket**，实时连不通。所以 B2 必须设 `realtime = false`
  （异步同行/留言/排行/云存档/聊天历史仍可用，只是没有"实时位置同步"）。

> 任何模式下，后端不可达时所有联网功能都会**静默降级**，单机流程始终可通关——
> 但 B 模式若把 `base_url` 指向不可达地址，控制台会刷失败请求，体验不如直接用 A。

### 改哪一行

编辑 [`../scripts/net/NetConfig.gd`](../scripts/net/NetConfig.gd) 顶部：

```gdscript
# 模式 A：
var enabled: bool = false

# 模式 B1（把域名换成你的后端）：
var base_url: String = "https://api.example.com/api/v1"
var enabled: bool = true
var realtime: bool = true

# 模式 B2：
var base_url: String = "/api/v1"
var enabled: bool = true
var realtime: bool = false
```

改完**重新导出** `build/web/`（值是导出时烤进去的，改了不重导无效）。

---

## 2. 部署 `build/web/` 到 Vercel

### 方式一：Vercel CLI（推荐，可脚本化）

```bash
npm i -g vercel            # 一次性安装
cd build/web
vercel deploy --prod       # 首次会让你登录 + 选 scope/项目名
```

一个**纯静态目录**无需任何框架配置，Vercel 会原样托管，`.wasm/.pck/.js` 的 MIME 自动正确。
首次部署后，之后每次重导出再 `vercel deploy --prod` 即可覆盖上线。

> 本仓库带了一键脚本：`tools/deploy_vercel.sh`（见 §4），自动校验导出、装 CLI、可选注入反代后部署。

### 方式二：拖拽（不想用 CLI）

打开 <https://vercel.com/new> →「Deploy」静态项目，把整个 `build/web/` 文件夹拖进去即可。

### 方式三：Git 导入（不推荐用于本项目）

Vercel 从仓库构建，但**它的构建机跑不了 Godot 导出**。若坚持 Git 流程，需要把导出的
`build/web/` 一并提交（仓库默认 `.gitignore` 忽略了 `build/`，要去掉那行），并在项目设置里
**Build Command 留空、Output Directory 填 `build/web`**。这会把二进制塞进 Git，一般不划算——
优先用方式一/二。

---

## 3. 模式 B 的后端怎么办（Vercel 之外）

后端那一套（FastAPI + Postgres + Redis）部署到**支持长驻进程/容器的主机**：

- **Hugging Face Space（Docker）** → 详见 [`DEPLOY_HF_SPACE.md`](DEPLOY_HF_SPACE.md)（外接 Neon + Upstash，仓库已备好 entrypoint / Dockerfile / Space README）。
- **自有 VPS**（Caddy/Nginx + docker compose，全套见 [`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md) / [`DEPLOYMENT.md`](DEPLOYMENT.md) §4–§5），或 Render / Railway / Fly.io 这类容器平台。

无论选哪个,要点都一样：

1. **必须 HTTPS**：网页版在 Vercel 上走 https，浏览器**禁止 https 页面调 http 接口**（混合内容）。
   后端域名要有 TLS（`wss` 同理）。
2. **B1 跨域**：后端 `.env` 把 `PP_CORS_ORIGINS` 放开你的 Vercel 域名，例如
   `PP_CORS_ORIGINS=https://你的项目.vercel.app`（绑了自定义域就填自定义域）。
3. **B2 同源代理**：在 Vercel 加 rewrite 把 `/api/*` 反代到后端（脚本可自动注入，见 §4）；
   `realtime=false`。注意 `/media/*`（聊天图片）也要一并反代，否则头像/贴图原图取不到：

   ```json
   {
     "rewrites": [
       { "source": "/api/:path*",   "destination": "https://api.example.com/api/:path*" },
       { "source": "/media/:path*", "destination": "https://api.example.com/media/:path*" }
     ]
   }
   ```
4. **生产建表**：后端首次要 `alembic upgrade head`（生产不自动建表）。
5. 上线后按 [`DEPLOYMENT.md`](DEPLOYMENT.md) §6 的验收清单逐项点一遍（登录/埋点/同行/排行/云存档/聊天）。

> 想彻底"一个域名搞定前后端、零跨域、还要实时"——那其实是文档 §5 的**同源反代（Caddy/Nginx）**
> 方案，把静态包和 `/api`、`/ws` 放同一台机器，不必用 Vercel。Vercel 的价值在于"前端 CDN 托管"，
> 代价是实时 WebSocket 得直连后端域名（即 B1）。

---

## 4. 一键脚本 `tools/deploy_vercel.sh`

```bash
# 纯单机 / B1 跨域（vercel.json 不需要反代）：
tools/deploy_vercel.sh

# B2 同源代理：把 /api 和 /media 反代到你的后端，再部署
PP_API_PROXY="https://api.example.com" tools/deploy_vercel.sh
```

脚本会：校验 `build/web/index.html` 是否已导出 → 没装 `vercel` 就 `npm i -g vercel` →
（若设了 `PP_API_PROXY`）往 `build/web/vercel.json` 注入 `/api`+`/media` 反代 →
`vercel deploy --prod`。

---

## 5. 自定义域名 / 环境

- **自定义域名**：Vercel 项目 → Settings → Domains 添加你的域名并按提示配 DNS。
  绑了域名记得回去把后端 `PP_CORS_ORIGINS` 改成该域名（B1）。
- **预览 vs 生产**：不带 `--prod` 的 `vercel deploy` 出**预览**链接（适合自测），带 `--prod` 才更新正式域名。
- **回滚**：Vercel 控制台每次部署都有独立 URL，可一键 Promote/Rollback。

---

## 6. 常见问题

| 现象 | 排查 |
|---|---|
| 打开是白屏 / "Failed to start" | 八成是没用 HTTP 静态托管或 `.wasm` MIME 不对；Vercel 默认正确，先确认 `build/web/` 是**完整导出**（含 `index.wasm/index.pck`）。F12 看控制台。 |
| 中文显示成 □□□ | `assets/fonts/` 缺字体；导出过滤器要含 `*.ttf,*.otf`（预设已配）。 |
| 网页能玩但联网全失败 | B 模式下 `base_url` 不可达或非 HTTPS；或忘了重导出（改了 NetConfig 没重导）。纯展示就用模式 A。 |
| 实时同行/聊天位置不动，其它联网正常 | 多半是 B2（同源代理不转发 WebSocket）。要实时请用 B1（`base_url` 填完整 https 域名）。 |
| 跨域被 CORS 拦 | 后端 `PP_CORS_ORIGINS` 没放开 Vercel 域名（B1）。 |
| 聊天图片/头像裂图 | B2 下 `/media/*` 没一起反代；B1 下 `media_url` 已用 `base_url` 同域，确认后端 `/media` 可达。 |

---

*前端上 Vercel，后端在别处——这是把静态游戏放 CDN、又保留全功能联网的标准拆法。
纯展示直接走模式 A，最省心。*
