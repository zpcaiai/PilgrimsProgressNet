# 部署清单：环境变量与素材资源

把《天路历程》联网版部署成可用服务所需的全部环境变量与资源。配合
[`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md)（操作步骤）与 [`QUICKSTART.md`](QUICKSTART.md)（本地试跑）。

---

## 1. 最小可用清单（先跑起来）

- 一台带公网 IP、开放 80/443 的 Linux 主机，装好 Docker + Docker Compose。
- 一个域名，DNS A 记录指向主机（TLS 由 Caddy 自动签发，无需手工准备证书）。
- `server/.env`（从 `.env.example` 复制）里**至少改这几项**：
  `PP_ENV=prod`、`PP_DEBUG=false`、`PP_JWT_SECRET`（强随机）、数据库密码、
  `PP_ADMIN_TOKEN`、`PP_ADMIN_USER`/`PP_ADMIN_PASSWORD`、`PP_EMAIL_DEV_ECHO=false`。
- 本机用 Godot 4.2+ 导出 Web 包到 `build/web/`（`NetConfig.base_url` 设 `/api/v1`）。
- `docker compose up` → 即得可玩的联网服务（画面为灰盒占位）。

> 美术/音频素材只影响**观感**，不影响服务可用性，可后续替换。

---

## 2. 环境变量

### 2.1 后端服务 `PP_*`（`server/.env`）

**生产必须修改（安全）**

| 变量 | 作用 | 生产取值 |
|---|---|---|
| `PP_ENV` | 运行环境 | `prod`（关闭自动建表，用 Alembic 迁移） |
| `PP_DEBUG` | 调试开关 | `false` |
| `PP_JWT_SECRET` | 玩家令牌签名密钥 | `openssl rand -hex 32` 生成 |
| `PP_DATABASE_URL` | PostgreSQL 异步连接串 | `postgresql+asyncpg://用户:强密码@postgres:5432/pilgrim` |
| `PP_REDIS_URL` | Redis 连接串 | `redis://redis:6379/0` |
| `PP_CORS_ORIGINS` | 允许的前端域名 | `https://你的域名`（同源部署可不依赖） |
| `PP_ADMIN_TOKEN` | cron/脚本用静态管理令牌 | 强随机串 |
| `PP_ADMIN_USER` / `PP_ADMIN_PASSWORD` | 后台网页登录 | 自定义强密码 |
| `PP_EMAIL_DEV_ECHO` | dev 回显验证码 | `false` |

**邮箱找回（要发真邮件才设；留空 `PP_SMTP_HOST` 则验证码仅写日志）**

`PP_SMTP_HOST` `PP_SMTP_PORT` `PP_SMTP_USER` `PP_SMTP_PASSWORD` `PP_SMTP_FROM` `PP_SMTP_TLS`
`PP_EMAIL_CODE_TTL_SEC` `PP_EMAIL_CODE_COOLDOWN_SEC`

**有默认值，可按需调**

| 类别 | 变量 |
|---|---|
| 连接池 | `PP_DB_POOL_SIZE` `PP_DB_MAX_OVERFLOW` `PP_DB_POOL_TIMEOUT` |
| 令牌 | `PP_ACCESS_TOKEN_TTL_MIN` `PP_REFRESH_TOKEN_TTL_MIN` `PP_ADMIN_SESSION_TTL_MIN` |
| 限流 | `PP_RATE_LIMIT_PER_MIN` |
| 赛季 | `PP_SEASON_OVERRIDE`（空=按季度自动） |
| 聊天 | `PP_BANNED_WORDS` `PP_BANNED_WORDS_FILE` `PP_CHAT_RETENTION_DAYS` `PP_CHAT_HISTORY_LIMIT` `PP_CHAT_RECALL_SECONDS` `PP_MEDIA_DIR` `PP_MAX_IMAGE_BYTES` |
| 防作弊 | `PP_SCORE_TOLERANCE` `PP_MIN_MS_PER_CHAPTER` `PP_DEVOUT_SCORE_MAX` |

### 2.2 监控 / 告警栈（compose 级，非 `PP_`）

| 变量 | 作用 |
|---|---|
| `GF_SECURITY_ADMIN_PASSWORD` | Grafana 管理员密码（改强） |
| `FEISHU_WEBHOOK` | 飞书机器人 webhook（可选，告警转发） |
| `DINGTALK_WEBHOOK` | 钉钉机器人 webhook（可选） |
| `DINGTALK_SECRET` | 钉钉加签密钥（可选） |

---

## 3. 素材 / 资源

### 3.1 基础设施（必需）

- Linux 主机（2 核 4G 起）、公网 IP、开放 80/443。
- 域名 + DNS 解析。
- TLS 证书：Caddy 自动签发（Let's Encrypt）。
- Docker / Docker Compose。
- 持久卷：PostgreSQL 数据卷、聊天图片目录 `PP_MEDIA_DIR`（建议挂卷）、
  Prometheus / Grafana 数据卷。

### 3.2 客户端构建（必需）

- Godot 4.2+（本机）导出的 Web/WASM 包 `build/web/`，交给 Caddy 同源托管。
- 中文字体（建议随项目自带，保证跨平台/浏览器一致显示）。

### 3.3 游戏美术 / 音频（可选——当前为灰盒占位）

| 资源 | 放置位置 / 约定 | 说明 |
|---|---|---|
| 低多边形 3D 美术 | 角色 / NPC / 各章节场景道具 | 现为胶囊体、方块占位 |
| 背景音乐 | `assets/audio/music/<章节>.ogg` | 章节 JSON 已引用路径，放进去即自动播放 |
| 环境音 | `assets/audio/ambient/<章节>.ogg` | 同上 |
| 音效 | `assets/audio/sfx/*.ogg` | 事件 SFX |
| 图标 / UI 美术 | 视需要 | 标题、按钮、HUD 等 |

> 音频已"接线但静默"：路径都做了存在性检查，**丢 `.ogg` 进去即播放，无需改代码**。

### 3.4 第三方账号（按需）

- SMTP 邮箱服务（邮箱绑定/找回）。
- 飞书 / 钉钉机器人（告警通知）。

---

## 4. 上线前检查清单

- [ ] `.env` 已改强密钥（JWT / DB / Admin），且 `.env` 不入 git。
- [ ] `PP_ENV=prod`，已执行 `alembic upgrade head`（不靠自动建表）。
- [ ] `PP_CORS_ORIGINS` 收紧到正式域名；`PP_EMAIL_DEV_ECHO=false`。
- [ ] DB / Redis 端口仅在 compose 内网，不对公网暴露。
- [ ] `PP_MEDIA_DIR` 与 PostgreSQL 数据挂到持久卷，并配置备份。
- [ ] cron：`purge_chat.py`（每日）、`settle_season.py --rollover`（每日）、
      `recompute_reviews.py`（每 5 分钟）。
- [ ] Grafana 密码已改；监控 + 告警（飞书/钉钉）按需接好。
- [ ] 压测过 `app=1` vs `app=3`，确认扩容与尾延迟达标。
