# 完整部署文档 · Pilgrim's Road — Burden Fallen

这是项目的**单一权威部署手册**，覆盖从纯单机到联网生产环境的全部路径：游戏客户端
（桌面 + 网页 WASM）、Python 后端（FastAPI + PostgreSQL + Redis）、HTTPS 同源上线、
扩容、定时任务、备份与监控，以及素材（中文字体 / 贴图 / 音频）的打包要点。

> 更深的专题文档（本手册已整合其要点，需要细节时再查）：
> 架构 [`ARCHITECTURE_BACKEND.md`](ARCHITECTURE_BACKEND.md) ·
> 后端上线 [`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md) ·
> 网页导出 [`DEPLOY_WEB.md`](DEPLOY_WEB.md) ·
> 快速验证 [`QUICKSTART.md`](QUICKSTART.md) ·
> 机器开通 [`PROVISIONING.md`](PROVISIONING.md) ·
> 客户端网络层 [`../scripts/net/README.md`](../scripts/net/README.md) ·
> 素材 [`ASSETS.md`](ASSETS.md)。

---

## 0. 先决定：你要部署哪一种？

| 场景 | 你需要 | 难度 | 看哪几节 |
|---|---|---|---|
| **纯单机**（最简单，无服务器） | 仅游戏本体 | ★ | §1, §2, §3，把 `NetConfig.enabled=false` |
| **桌面版分发**（Win/macOS/Linux 可执行文件） | 游戏导出 | ★★ | §1, §2, §3 |
| **本地联网联调**（一台机器跑前后端） | 游戏 + Docker 后端 | ★★ | §4（Docker 一条命令）+ §6 |
| **网页版 + 后端 · 生产上线**（域名 + HTTPS + 同源） | 云服务器 + 域名 | ★★★ | §3.4, §4, §5（全套） |
| **仅托管网页版**（itch.io / Pages / Netlify / Vercel） | 静态托管 + 可达后端 | ★★ | §3.4, §7 |

游戏的网络层**默认安全降级**：后端不可达时，所有联网功能（同行幽灵、留言路标、
排行榜、云存档、聊天）静默退化，单机流程始终可通关。

整体拓扑（生产 · 同源）：

```
玩家浏览器 ──HTTPS──▶ Caddy/Nginx (443, TLS) ──┬──▶ 静态 WASM 游戏 ( / )
                                               ├──▶ FastAPI ×N ( /api、/healthz、/metrics )
                                               └──▶ 上传图片静态 ( /media )
                                                      │
                                               PostgreSQL  +  Redis
```

---

## 1. 先决条件

**客户端（导出游戏）**
- **Godot 4.2+**（标准版，非 .NET）：<https://godotengine.org/download>
- 对应版本的 **Export Templates**（编辑器内 `Editor → Manage Export Templates`，
  或下载与引擎**完全同版本**的模板）。版本不匹配会导出失败。

**后端（联网时才需要）**
- **Docker + Docker Compose v2**（推荐路径），或 Python 3.12 + PostgreSQL 16 + Redis 7。
- 生产另需：一台 2 核 4G 起的云服务器（开放 80/443）、一个域名。

**本机校验工具（可选，本仓库自带）**
- Python 3 + `numpy`、`Pillow`、`fontTools`、`ffmpeg`（仅在需要**重新生成素材**或
  跑 `tools/validate_assets.py` 时）。

---

## 2. 素材确认（联网/单机都需要）

游戏的音频、贴图、立绘、动画、**中文字体**、聊天贴图都在 [`../assets/`](../assets)，
随仓库一起分发。导出前请确认它们在位（尤其字体，否则中文界面显示成 □□□）：

```bash
python3 tools/validate_assets.py     # 交叉校验所有素材与代码引用是否对得上
```

要点：
- **中文字体**：`assets/fonts/*.otf`（已内置 Noto Sans CJK SC 子集，OFL 许可证随附）。
  `ThemeManager`（autoload）启动时自动套用到全局主题。换字体只需丢一个 `.ttf/.otf` 进去。
- **贴图包**：`assets/ui/stickers/<包>/<名>.png` + `manifest.json`（聊天面板读取）。
- 如需重建素材：`tools/gen_audio.py`、`tools/gen_art.py`、`tools/gen_font.py`
  （详见 [`ASSETS.md`](ASSETS.md)）。
- **导出打包过滤**（`export_presets.cfg` 的 `include_filter`）已包含 `*.json, *.ttf, *.otf`
  ——因为章节/对话/任务数据与贴图 `manifest.json` 是**运行时按原始文件读取**的，字体亦然。
  若你新增了"按 `FileAccess` 读取的原始文件类型"，记得把它加进 `include_filter`，否则导出后丢失。

---

## 3. 部署游戏客户端

### 3.1 从编辑器直接运行（开发）

1. Godot 打开本目录的 `project.godot`（`Import`）。
2. 按 **F5**（Play）。标题屏 → **Begin the Journey**。

一切在 GDScript 里**程序化构建**，没有易碎的编辑器接线，导入后即可运行。

### 3.2 桌面导出（Windows / Linux / macOS）

`export_presets.cfg` 已内置 **Web** 与 **Windows Desktop** 预设；Linux/macOS 在
`Project → Export…` 里点 `Add…` 各加一个预设即可（无需额外配置）。

- Windows：导出到 `build/windows/PilgrimsProgress.exe`（预设已配）。
- 命令行导出（CI 友好，需先装好 export templates）：

  ```bash
  godot --headless --export-release "Windows Desktop" build/windows/PilgrimsProgress.exe
  godot --headless --export-release "Linux/X11"       build/linux/PilgrimsProgress.x86_64
  ```

把对应 `build/<平台>/` 目录打包分发即可。桌面版默认仍会尝试连后端（见 §3.5）。

### 3.3 应用图标

`project.godot` 用 `res://assets/ui/app_icon.png`；网页 PWA 图标用
`assets/ui/pwa_icon_{144,180,512}.png`——均已就位。换图标替换同名文件即可。

### 3.4 网页（WASM）导出

1. （生产同源部署时）把后端地址改成相对路径，见 §3.5。
2. `Project → Export… → Web` → 导出到 `build/web/index.html`。
   命令行：

   ```bash
   godot --headless --export-release "Web" build/web/index.html
   ```

3. 本地预览（**必须用 HTTP 服务器**，不能直接双击 `index.html`）：

   ```bash
   cd build/web && python3 -m http.server 8060
   # 打开 http://localhost:8060
   ```

> **关于跨域隔离头（COOP/COEP）**：本项目 Web 预设的 `线程支持(thread_support)` 已**关闭**，
> 因此 WASM 为单线程构建，**普通静态托管即可**，无需 SharedArrayBuffer / COOP+COEP 头。
> 若你将来开启线程，则托管端必须发送
> `Cross-Origin-Opener-Policy: same-origin` 与 `Cross-Origin-Embedder-Policy: require-corp`。

### 3.5 客户端网络配置（关键）

编辑 [`scripts/net/NetConfig.gd`](../scripts/net/NetConfig.gd)：

| 目标 | 设置 |
|---|---|
| **纯单机** | `enabled = false`（不发任何请求） |
| **本地联调** | `enabled = true`，`base_url = "http://localhost:8080/api/v1"`（与 §4 一致） |
| **生产 · 同源** | `enabled = true`，`base_url = "/api/v1"`（相对路径，**彻底无跨域**） |
| **生产 · 跨域** | `base_url = "https://api.你的域名/api/v1"`，并在后端放开 CORS（§5.4） |

`realtime = true` 时启用 WebSocket 实时同行；不可达会自动回落到异步幽灵。
网页版若用 HTTPS 提供，**必须**调用 HTTPS/WSS 后端（浏览器禁止混合内容）——这也是
推荐**同源**部署的原因。

---

## 4. 部署后端（本地 / Docker 一条命令）

```bash
cd server
cp .env.example .env          # 本地默认值即可直接用
docker compose up --build     # 起 postgres + redis + app + nginx(8080)
```

验证：

```bash
curl http://localhost:8080/healthz   # -> {"status":"ok"}
curl http://localhost:8080/readyz    # -> {"ready":true,"db":true,"redis":true}
# 浏览器打开 http://localhost:8080/docs 看交互式 API 文档
```

**不用 Docker（venv）**：

```bash
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
# 需自备 PostgreSQL/Redis，并在 .env 指好 PP_DATABASE_URL / PP_REDIS_URL
alembic upgrade head            # 建表（生产必走；dev 也建议）
uvicorn app.main:app --reload --port 8000
```

> 开发态（`PP_ENV=dev`）启动会自动建表；生产态（`PP_ENV=prod`）**不**自动建表，必须
> 手动 `alembic upgrade head`（仓库已带首个迁移 `0001_init`）。

### 4.1 环境变量速查（`.env`，前缀 `PP_`）

完整清单见 [`server/.env.example`](../server/.env.example)。**上线务必修改**的项：

| 变量 | 说明 | 生产建议 |
|---|---|---|
| `PP_ENV` / `PP_DEBUG` | 运行模式 | `prod` / `false` |
| `PP_JWT_SECRET` | 令牌签名密钥 | `openssl rand -hex 32` 生成的强随机串 |
| `PP_DATABASE_URL` | Postgres（asyncpg） | 改强密码，勿用默认 `pilgrim:pilgrim` |
| `PP_REDIS_URL` | Redis | 按部署填写 |
| `PP_CORS_ORIGINS` | 允许的前端域名 | 同源可留默认；跨域填 `https://你的域名` |
| `PP_ADMIN_TOKEN` | 脚本/cron 用管理头 | 强随机串 |
| `PP_ADMIN_USER` / `PP_ADMIN_PASSWORD` | 管理后台登录 | 改掉默认 |
| `PP_EMAIL_DEV_ECHO` | 验证码是否回显 | 生产 `false`，并配 `PP_SMTP_*` |
| `PP_MEDIA_DIR` / `PP_MAX_IMAGE_BYTES` | 聊天图片存储/大小 | 生产挂持久卷 |
| `PP_CHAT_RETENTION_DAYS` | 聊天留存天数 | 默认 7 |
| `PP_SCORE_TOLERANCE` / `PP_MIN_MS_PER_CHAPTER` / `PP_DEVOUT_SCORE_MAX` | 防作弊阈值 | 按需调 |

---

## 5. 生产上线（域名 + HTTPS + 同源，推荐）

目标：一个域名同时提供游戏与 API，绕开一切跨域。命令以 Ubuntu 22.04 为例。

### 5.1 DNS

把 A 记录指向服务器公网 IP：`A  pilgrim.example.com → <服务器IP>`，
`dig +short pilgrim.example.com` 能解析到即可。

### 5.2 服务器装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER     # 重新登录生效
docker compose version
```

### 5.3 本机导出 WASM 并上传

1. `NetConfig.gd` 把 `base_url` 改为 `"/api/v1"`（相对路径）。
2. 导出 Web 到 `build/web/`（§3.4）。
3. 上传：

   ```bash
   rsync -av build/web/ user@pilgrim.example.com:/srv/pilgrim/web/
   ```

### 5.4 服务器拉代码、配密钥

```bash
git clone <你的仓库> /srv/pilgrim/app && cd /srv/pilgrim/app/server
cp .env.example .env
```

编辑 `.env`：按 §4.1 改 `PP_ENV=prod`、`PP_DEBUG=false`、`PP_JWT_SECRET`、强 DB 密码、
`PP_CORS_ORIGINS=https://pilgrim.example.com`、管理密钥等。

### 5.5 TLS + 同源反代（Caddy，自动证书）

`/srv/pilgrim/Caddyfile`：

```caddyfile
pilgrim.example.com {
    encode gzip
    @api path /api/* /healthz /readyz /metrics /docs /openapi.json /media/*
    handle @api { reverse_proxy app:8000 }
    handle {
        root * /srv/pilgrim/web
        try_files {path} /index.html
        file_server
    }
}
```

生产 compose `/srv/pilgrim/docker-compose.prod.yml`（用 Caddy 取代 dev 的 nginx，
**不**对外暴露 DB 端口）——完整文件见 [`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md) §5。启动：

```bash
cd /srv/pilgrim
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec app alembic upgrade head   # 迁移
```

打开 `https://pilgrim.example.com` —— 游戏加载、证书自动就绪。

> 偏好 Nginx + Certbot：仓库已带 `server/nginx.conf`（HTTP 版），
> `certbot --nginx -d pilgrim.example.com` 签证书，把静态段与 `/api` 反代段并入同一 `server{}`。

### 5.6 横向扩容

应用层无状态，加副本即可（反代自动轮询）：

```bash
docker compose -f docker-compose.prod.yml up -d --scale app=3
```

容器内每个 app 由 gunicorn 跑 4 个 uvicorn worker（`-w` 约 `2*CPU+1`，按机器调）。
再往上：Postgres 加只读副本、前置 PgBouncer、`stat_events` 按月分区（见架构文档 §6）。

### 5.7 定时任务（cron）

```bash
# 防作弊重算：每 5 分钟处理一次可疑成绩队列
*/5 * * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app python scripts/recompute_reviews.py --limit 500
# 赛季结算：每天 04:00（幂等，仅跨季时真正结算并发奖励）
0 4 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app python scripts/settle_season.py --rollover
# 聊天留存清理：每天 05:00（连带过期图片）
0 5 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app python scripts/purge_chat.py
# PostgreSQL 备份：每天 03:00，保留 14 天（Redis 仅缓存可丢）
0 3 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T postgres pg_dump -U pilgrim pilgrim | gzip > /srv/pilgrim/backups/pilgrim-$(date +\%F).sql.gz
```

恢复备份：`gunzip -c 备份.sql.gz | docker compose ... exec -T postgres psql -U pilgrim pilgrim`。

### 5.8 管理后台与监控

- **管理后台**（同源）：`https://pilgrim.example.com/admin-ui/`，填 API base `/api/v1` 与
  `PP_ADMIN_TOKEN`：复核防作弊队列、批/拒申诉、结算赛季、看章节漏斗。生产建议对
  `/admin-ui` 与 `/api/v1/admin` 再加 IP 白名单或 Basic Auth。
- **Prometheus + Grafana**：后端已暴露 `/metrics`。一键起观测栈：

  ```bash
  cd server
  docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d
  # Grafana http://<host>:3000 (admin/admin，首登改密码)；Prometheus http://<host>:9090
  ```

---

## 6. 联网功能验收清单

进游戏后逐项确认（详版见 [`QUICKSTART.md`](QUICKSTART.md)）：

| 功能 | 验证 | 预期 |
|---|---|---|
| 匿名登录 | 启动自动 | 日志 `POST /api/v1/auth/device 200` |
| 数据统计 | 进出章节 | 日志 `POST /api/v1/stats/events 202` |
| 多人同行 | 章节里走几步 | 左上"同行人数"挂件 |
| 留言路标 | 按 **M** 写一句 | toast"路标已留下" |
| 排行榜 | 通关（调试可 F7 连跳） | 终章自动提交；按 **B** 看榜 |
| 云存档 | 存档（F5 / 暂停菜单） | `PUT /api/v1/saves/slot_1 200` |
| 聊天 + 贴图 | 打开聊天发贴图 | 对端收到；`message_in`/`mention` 音效 |

实时看后端：`cd server && docker compose logs -f app`。

---

## 7. 仅托管网页版（静态托管）

把 `build/web/` 整目录上传到 itch.io / GitHub Pages / Netlify / Vercel 即可
（线程已关闭，无需特殊响应头，见 §3.4）。注意：

- 联网功能需要一个**可达**的后端，且因网页走 HTTPS，后端也必须 HTTPS（WSS），
  并在 `PP_CORS_ORIGINS` 放开你的托管域名（跨域）；否则把 `NetConfig.enabled=false`
  发纯单机网页版。
- itch.io：上传 zip，勾选 "This file will be played in the browser"。

---

## 8. 上线前自检 & 烟测

```bash
# 1) 素材↔代码 交叉校验（沙箱可跑，无需 Godot）
python3 tools/validate_assets.py

# 2) 引擎内烟测（需本机 Godot 4.2+）
godot --headless --import                          # 先导入新素材
godot --headless --script tools/smoke_test.gd      # 校验字体/贴图/音频，失败返回非 0
godot --headless --quit-after 5                     # 启动一遍，暴露任何 GDScript 解析错误

# 3) 后端探针
curl -fsS http://localhost:8080/healthz && curl -fsS http://localhost:8080/readyz
```

---

## 9. 常见问题（Troubleshooting）

| 现象 | 排查 |
|---|---|
| 游戏能玩但不联网 | 后端没起或 `base_url` 不对；`curl /healthz` 确认，核对 `NetConfig.base_url`。联网功能会静默降级，不影响通关。 |
| 中文显示成 □□□ | `assets/fonts/` 缺字体；放入 `.ttf/.otf` 后重启（`ThemeManager` 自动套用）。 |
| 网页版联网失败 | 同源最稳；跨域需后端 HTTPS + `PP_CORS_ORIGINS` 放行；切勿 HTTPS 页面调 HTTP API。 |
| 导出报缺模板 | 装与编辑器**同版本**的 Export Templates。 |
| 导出后 JSON/字体丢失 | 确认 `export_presets.cfg` 的 `include_filter` 含 `*.json, *.ttf, *.otf`。 |
| 生产起来表不存在 | 生产不自动建表，跑 `alembic upgrade head`。 |
| `readyz` 返回 db/redis=false | 检查 `PP_DATABASE_URL`/`PP_REDIS_URL` 与容器健康（`docker compose ps`）。 |
| 上传图片重启后丢失 | 生产给 `PP_MEDIA_DIR` 挂持久卷。 |

---

## 10. 文件位置速查

| 用途 | 路径 |
|---|---|
| 游戏工程入口 | `project.godot` · 主场景 `scenes/core/Main.tscn` |
| 导出预设 | `export_presets.cfg`（Web / Windows） |
| 客户端网络配置 | `scripts/net/NetConfig.gd` |
| 素材 | `assets/`（音频/贴图/立绘/动画/字体/聊天贴图） |
| 后端代码 | `server/app/`（FastAPI） |
| 后端配置样例 | `server/.env.example` · 设置类 `server/app/config.py` |
| 容器化 | `server/Dockerfile` · `server/docker-compose.yml` · `server/nginx.conf` |
| 迁移 | `server/alembic/`（`alembic upgrade head`） |
| 观测 | `server/docker-compose.observability.yml` · `/metrics` |
| 压测 | `server/loadtest/`（`loadtest.py`） |
| 校验/烟测 | `tools/validate_assets.py` · `tools/smoke_test.gd` |

---

*主题与人物取自约翰·班扬《天路历程》(1678，公有领域)。内置 Noto Sans CJK 子集遵循
SIL OFL 1.1（见 `assets/fonts/LICENSE-NotoSansCJK.txt`）。*
