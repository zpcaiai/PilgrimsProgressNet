# 网络版后端架构设计（PilgrimsProgressNet）

> 把单机版《天路历程 · 重担落下》升级为联网版（B/S 架构），支持
> **排行榜、云存档、多人同行（异步幽灵）、数据统计**。
>
> 技术栈：**Python 3.12 + FastAPI（async）+ PostgreSQL + Redis**，
> Nginx 反向代理，Docker Compose 编排，可平滑横向扩容。
>
> 客户端：**Godot 4.2（WASM Web 导出）**，通过 `scripts/net/` 网络层接入。
> 单机逻辑（`GameState` / `SpiritualStateManager` / `QuestManager` / `SaveManager`）
> **完全保留**，后端只做"叠加层"——离线也能玩，联网时同步与增强。

---

## 1. 设计目标与约束

| 目标 | 说明 |
|---|---|
| 离线可玩 | 没有网络时，单机存档（`user://saves/slot_1.json`）照常工作。联网只是增强。 |
| 渐进接入 | 客户端网络层与游戏逻辑解耦，挂在 `EventBus` 信号上，不改动现有玩法代码。 |
| 低门槛上手 | 匿名设备令牌，首次进入自动建号，无需注册即可上排行榜 / 云存档。 |
| 防作弊（基础） | 服务端校验分数合理性、限流、令牌签名；高价值榜可加服务端重算。 |
| 可横向扩容 | 应用层**无状态**（JWT + Redis），可多副本；瓶颈下沉到 PG/Redis，按需分片。 |
| 可观测 | 结构化日志、`/healthz`/`/readyz`、Prometheus 指标、请求追踪 ID。 |

### 为什么是这套栈
- **FastAPI（ASGI/async）**：单进程内用协程承载大量 I/O 等待（DB、Redis），
  配合 `uvicorn --workers N` 或多容器副本即可横向扩容；自带 OpenAPI 文档便于客户端联调。
- **PostgreSQL**：事务 + JSONB（存档/统计的半结构化字段）+ 强一致排行榜兜底。
- **Redis**：排行榜（`ZSET` 实时 Top-N）、在线状态/幽灵的短 TTL 缓存、限流计数器、热点缓存。

---

## 2. 总体架构（B/S）

```
                        ┌──────────────────────────────────────────────┐
   Godot WASM 客户端     │                  服务端（云）                  │
  (浏览器 / 桌面 / 手机) │                                              │
        │               │   ┌────────────┐      ┌──────────────────┐    │
        │  HTTPS/JSON   │   │   Nginx     │      │  FastAPI App ×N   │    │
        ├──────────────▶│──▶│ 反向代理/TLS│─────▶│ (uvicorn workers) │    │
        │   (REST)      │   │ 限流/Gzip   │      │  无状态、可水平扩 │    │
        │               │   └────────────┘      └─────┬──────┬───────┘    │
        │               │                             │      │            │
        │               │                    ┌────────▼──┐ ┌─▼─────────┐  │
        │               │                    │ PostgreSQL│ │   Redis   │  │
        │               │                    │ 连接池    │ │ ZSET/缓存 │  │
        │               │                    │ (asyncpg) │ │ /限流/在线│  │
        │               │                    └───────────┘ └───────────┘  │
        │               └──────────────────────────────────────────────┘
```

**请求路径**：客户端 → Nginx（TLS 终止、静态 WASM 也可托管、限流、压缩）
→ FastAPI 副本（鉴权、业务）→ PostgreSQL（持久化）/ Redis（缓存与榜单）。

应用层不保存会话状态，任意副本都能处理任意请求 → 直接加副本即可扩容。

---

## 3. 模块与职责

| 模块 | 路由前缀 | 职责 |
|---|---|---|
| Auth 鉴权 | `/api/v1/auth` | 设备令牌建号、签发/刷新 JWT，可选邮箱绑定 |
| Cloud Save 云存档 | `/api/v1/saves` | 多槽位云存档读写、版本号/时间戳冲突处理、按设备拉取 |
| Leaderboard 排行榜 | `/api/v1/leaderboard` | 提交成绩、Redis ZSET 实时榜、分榜（通关时长/最少倒下/敬虔分） |
| Ghosts 多人同行 | `/api/v1/ghosts` | 上传"足迹/路标/在线状态"，按章节拉取他人幽灵（异步） |
| Stats 数据统计 | `/api/v1/stats` | 上报埋点事件、聚合查询（章节通过率、平均绝望值、流失漏斗） |
| Health 健康检查 | `/healthz` `/readyz` `/metrics` | 存活/就绪探针、Prometheus 指标 |

每个模块 = 一个 router + service + 一组 Pydantic schema，互不耦合，便于后续拆微服务。

---

## 4. 数据模型（PostgreSQL）

```
players                        — 玩家账号（匿名起步）
  id            UUID  PK
  device_id     TEXT  UNIQUE   — 客户端首次随机生成，存本地
  display_name  TEXT           — 昵称（默认"无名的朝圣者#xxxx"）
  email         TEXT  NULL UQ  — 可选绑定
  created_at / last_seen_at

cloud_saves                    — 云存档（每玩家多槽位）
  id PK, player_id FK, slot_id TEXT
  version       INT            — 乐观锁，递增防覆盖
  payload       JSONB          — 复用单机 save_game 的 payload 结构
  device_clock  TIMESTAMPTZ    — 客户端存档时间，用于冲突判断
  updated_at
  UNIQUE(player_id, slot_id)

leaderboard_entries            — 排行榜成绩（持久兜底；热数据在 Redis）
  id PK, player_id FK
  board         TEXT           — 'fastest_run' | 'fewest_falls' | 'devout_score'
  difficulty    TEXT           — 'standard' | 'child'
  score         BIGINT         — 统一存"越大越好"（时长榜存 负毫秒 或单独规则）
  meta          JSONB          — 通关章节数、用时、倒下次数等明细
  created_at
  INDEX(board, difficulty, score DESC)

ghost_trails                   — 多人同行：异步足迹/路标
  id PK, player_id FK
  chapter_id    TEXT
  kind          TEXT           — 'trail'（足迹点列）| 'marker'（路标留言）
  points        JSONB          — [[x,y,z,t], ...] 采样轨迹（限长）
  message       TEXT  NULL     — 路标留言（服务端过滤敏感词）
  created_at
  INDEX(chapter_id, created_at DESC)

stat_events                    — 数据统计：原始埋点（可批量、可异步入库）
  id BIGSERIAL PK, player_id FK NULL
  event         TEXT           — 'chapter_started' | 'chapter_completed' | 'spiritual_collapse' ...
  chapter_id    TEXT  NULL
  difficulty    TEXT  NULL
  props         JSONB          — 事件附带属性
  created_at
  INDEX(event, created_at), INDEX(chapter_id)

stat_daily_rollup（可选物化）   — 预聚合每日指标，供仪表盘快速读取
```

> 存档 `payload` 直接沿用 `SaveManager.save_game()` 的字典结构
> （`version / timestamp / game_state / spiritual_state / quest_state`），
> 服务端不需要理解游戏内部语义，只做存取与版本仲裁 → 玩法改动不影响后端。

---

## 5. 关键 API（v1 摘要）

| 方法 & 路径 | 说明 | 鉴权 |
|---|---|---|
| `POST /auth/device` | 用 `device_id` 建号/登录，返回 `access_token` | 否 |
| `POST /auth/refresh` | 刷新令牌 | refresh |
| `POST /auth/bind-email` | 绑定邮箱（跨设备找回） | 是 |
| `GET  /saves` | 列出本玩家所有槽位摘要 | 是 |
| `GET  /saves/{slot}` | 拉取某槽位云存档 | 是 |
| `PUT  /saves/{slot}` | 上传/覆盖存档（带 `version` 乐观锁） | 是 |
| `POST /leaderboard/submit` | 提交成绩（服务端校验+写 ZSET+落库） | 是 |
| `GET  /leaderboard/{board}` | Top-N + 我的排名（Redis ZSET） | 是 |
| `POST /ghosts/trail` | 上传本次章节足迹/路标 | 是 |
| `GET  /ghosts/{chapter}` | 拉取该章节他人幽灵（采样、限量） | 是 |
| `GET  /ghosts/presence/{chapter}` | 该章节当前在线人数（Redis） | 是 |
| `POST /stats/events` | 批量上报埋点（最多 N 条/次） | 是* |
| `GET  /stats/overview` | 聚合仪表盘数据（章节漏斗等） | admin |

错误统一 `{"error": {"code","message"}}`；所有写接口带 `X-Request-Id` 追踪。

---

## 6. 缓存与并发（对应"连接池 / 缓存 / 横向扩容"）

### 连接池
- 数据库用 **SQLAlchemy async + asyncpg**，引擎级连接池：
  `pool_size`、`max_overflow`、`pool_timeout`、`pool_pre_ping=True`（防陈旧连接）。
- 连接池大小按 `单副本worker数 × 每worker并发` 估算，并保证
  `副本数 × pool_size ≤ PostgreSQL max_connections` 的安全余量；
  规模再上一层时，前置 **PgBouncer**（transaction 模式）做连接复用。

### 缓存（Redis）
- **排行榜**：`ZADD board:{board}:{difficulty} score player_id`，
  读 Top-N 用 `ZREVRANGE`，我的排名用 `ZREVRANK` —— O(logN)，避免每次扫表。
  PG 作为持久兜底与重建数据源（Redis 重启可从 PG 回填）。
- **在线/同行**：`presence:{chapter}` 用带 TTL 的集合或计数，心跳续期。
- **热点缓存**：章节聚合统计、幽灵列表做短 TTL（10–60s）缓存，抗突发读。
- **限流**：固定窗口/令牌桶计数器（`ratelimit:{ip|player}:{route}`）。

### 横向扩容路径
1. 起步：单机 `docker compose up`（app×1 + pg + redis + nginx）。
2. 加压：`uvicorn --workers N` 或把 app 容器扩到多副本，Nginx 轮询负载。
3. 再加压：PG 读写分离（只读副本承接排行榜/统计读）、Redis 主从、PgBouncer。
4. 海量：`stat_events` 按时间分区/转列存（ClickHouse）、榜单按赛季分片。

因为应用层无状态、会话信息在 JWT 与 Redis 中，**横向加副本不需要改代码**。

---

## 7. 安全

- **令牌**：设备令牌随机高熵；服务端签发 **JWT（HS/RS256）**，access 短期 + refresh。
- **传输**：仅 HTTPS（Nginx 终止 TLS）。CORS 白名单到游戏域名。
- **防作弊（基础）**：成绩提交做范围/单调性校验（用时不为负、章节数 ≤ 16、
  与该玩家最近一次通关事件交叉核对）；写接口限流；可疑成绩进人工/重算队列。
- **隐私**：埋点不收集 PII；昵称/留言走敏感词过滤；可一键删除账号数据（GDPR 友好）。
- **配置**：所有密钥走环境变量（`.env`，不入库），生产用 Secret 管理。

---

## 8. 可观测性与运维

- `/healthz`（存活）/`/readyz`（依赖 DB+Redis 就绪）供 k8s/compose 探针。
- `/metrics` 暴露 Prometheus 指标（QPS、时延、错误率、池占用）。
- 结构化 JSON 日志 + `X-Request-Id` 贯穿一次请求。
- 数据库迁移用 **Alembic**，版本化、可回滚。
- 备份：PG 定时 `pg_dump`/物理备份；Redis 仅缓存，可丢可重建。

---

## 9. 客户端接入（Godot）

新增 `scripts/net/`，作为 autoload 单例，**只监听 `EventBus` 信号、调用 `SaveManager`**，
不侵入玩法：

| 客户端单例 | 作用 | 触发点 |
|---|---|---|
| `ApiClient` | `HTTPRequest` 封装：基址、JSON、令牌头、重试、队列 | 被其它服务调用 |
| `AuthService` | 启动时用本地 `device_id` 换取令牌 | 游戏启动 |
| `CloudSaveService` | `save_completed`→上传；可手动"上传/下载/合并云存档" | `EventBus.save_completed` |
| `LeaderboardService` | 通关时提交成绩；提供榜单数据给 UI | `EventBus.chapter_completed`（终章） |
| `GhostService` | 章节内采样足迹、进出章节上传/拉取幽灵 | `chapter_started` / `chapter_completed` |
| `AnalyticsService` | 把关键 `EventBus` 信号转为埋点批量上报 | 多个信号 |

**离线降级**：任何请求失败都静默回退到单机行为（本地存档照常），并入队稍后重试。

接入只需在 `project.godot [autoload]` 增加这些单例（详见 `server/README.md` 与 `scripts/net/README.md`）。

---

## 10. 实施路线图

1. **M1（本次骨架）**：鉴权 + 云存档 + 排行榜 + 幽灵 + 埋点的可运行后端，
   docker-compose 一键起；Godot 网络层骨架与接入说明。
2. **M2**：✅ 邮箱绑定/找回（验证码）；管理后台聚合仪表盘（`/stats/overview`，已加管理员鉴权）；
   敏感词过滤、Prometheus+Grafana（待办）。
3. **M3**：✅ 赛季榜（当季+历史，季度自动滚动）、✅ 赛季结算（前三发奖励 token、自动开新季）、
   ✅ 防作弊重算队列（可疑成绩入队、重算通过才进榜，admin 端点 + cron 脚本）；
   PgBouncer/读副本、埋点入 ClickHouse（待办）。
4. **M4（可选）**：实时同行（WebSocket 房间）作为异步同行的升级路径。

> 赛季/防作弊的运维（cron、管理端点）见 [`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md) §7.5。

---

*后端只是叠加层：删掉 `scripts/net/` 与服务端，游戏仍是完整可玩的单机版。*
