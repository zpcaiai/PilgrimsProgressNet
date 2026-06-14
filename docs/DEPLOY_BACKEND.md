# 从零到上线：联网版部署手册

把 [`server/`](../server) 后端 + Godot WASM 前端部署到一台云服务器，配好域名与
HTTPS，并**同源托管**（一个域名同时提供游戏与 API，彻底绕开浏览器跨域）。

> 架构原理见 [`ARCHITECTURE_BACKEND.md`](ARCHITECTURE_BACKEND.md)；
> 本文是一步步的操作手册。命令以 Ubuntu 22.04 / Debian 为例。

---

## 0. 你需要准备

- 一台云服务器（2 核 4G 起步够用），公网 IP，开放 80 / 443 端口。
- 一个域名，例如 `pilgrim.example.com`，能改 DNS。
- 本机装好 **Godot 4.2+**（用来导出 WASM）。

整套拓扑（同源）：

```
玩家浏览器 ──HTTPS──▶ Caddy/Nginx(443, TLS) ──┬──▶ 静态 WASM（/）
                                              └──▶ FastAPI ×N（/api、/healthz）
                                                     │
                                              PostgreSQL + Redis
```

因为游戏与 API 同域，前端 `NetConfig.base_url` 直接写 `/api/v1`（相对路径），
**没有任何跨域问题**。

---

## 1. 域名解析

在域名服务商把 A 记录指向服务器公网 IP：

```
A   pilgrim.example.com   ->   <服务器IP>
```

等解析生效（`dig +short pilgrim.example.com` 能看到你的 IP）。

---

## 2. 服务器装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER   # 重新登录后生效
docker compose version          # 确认 v2 可用
```

---

## 3. 导出 Godot WASM（在本机）

1. 设置后端地址为相对路径：编辑 `scripts/net/NetConfig.gd`

   ```gdscript
   var base_url: String = "/api/v1"
   ```

2. Godot：**Project → Export… → Web** → 导出到 `build/web/index.html`
   （详见 [`DEPLOY_WEB.md`](DEPLOY_WEB.md)）。

3. 把 `build/web/` 整个目录上传到服务器，例如：

   ```bash
   rsync -av build/web/ user@pilgrim.example.com:/srv/pilgrim/web/
   ```

---

## 4. 拉代码、配密钥（在服务器）

```bash
git clone <你的仓库> /srv/pilgrim/app && cd /srv/pilgrim/app/server
cp .env.example .env
```

编辑 `.env`，**务必修改**：

```ini
PP_ENV=prod
PP_DEBUG=false
PP_JWT_SECRET=<用 `openssl rand -hex 32` 生成的强随机串>
PP_DATABASE_URL=postgresql+asyncpg://pilgrim:<强密码>@postgres:5432/pilgrim
PP_REDIS_URL=redis://redis:6379/0
PP_CORS_ORIGINS=https://pilgrim.example.com
```

> 同源部署其实不依赖 CORS，但把它收紧到正式域名是良好习惯。

---

## 5. TLS + 同源反代：用 Caddy（最省心）

Caddy 自动申请并续期 Let's Encrypt 证书。在 `/srv/pilgrim/` 放一个 `Caddyfile`：

```caddyfile
pilgrim.example.com {
    encode gzip

    # API 与探针走后端
    @api path /api/* /healthz /readyz /docs /openapi.json
    handle @api {
        reverse_proxy app:8000
    }

    # 其余走静态游戏文件
    handle {
        root * /srv/pilgrim/web
        try_files {path} /index.html
        file_server
    }
}
```

再写一个生产用 compose（覆盖 dev 版的 nginx，换成 Caddy + 不暴露 DB 端口）
`/srv/pilgrim/docker-compose.prod.yml`：

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: pilgrim
      POSTGRES_PASSWORD: <与 .env 一致的强密码>
      POSTGRES_DB: pilgrim
    volumes: [ "pgdata:/var/lib/postgresql/data" ]
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    restart: unless-stopped

  app:
    build: ./app/server
    env_file: ./app/server/.env
    depends_on: [ postgres, redis ]
    restart: unless-stopped
    expose: [ "8000" ]

  caddy:
    image: caddy:2-alpine
    ports: [ "80:80", "443:443" ]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./web:/srv/pilgrim/web:ro
      - caddy_data:/data
      - caddy_config:/config
    depends_on: [ app ]
    restart: unless-stopped

volumes:
  pgdata:
  caddy_data:
  caddy_config:
```

启动：

```bash
cd /srv/pilgrim
docker compose -f docker-compose.prod.yml up -d --build
```

打开 `https://pilgrim.example.com` —— 游戏加载，证书自动就绪。

> 想用 Nginx + Certbot 也行：仓库已带 `server/nginx.conf`（HTTP 版），
> 加一个 `certbot --nginx -d pilgrim.example.com` 签发证书，并把
> `try_files` 静态段与 `/api` 反代段合到同一个 `server {}` 即可。Caddy 只是更省事。

---

## 6. 数据库迁移（生产不要用自动建表）

生产把 `PP_ENV=prod`，启动时**不**自动 `create_all`，需手动跑 Alembic：

```bash
cd /srv/pilgrim
docker compose -f docker-compose.prod.yml exec app alembic upgrade head
```

仓库已带首个迁移 `0001_init`。以后改了模型：

```bash
docker compose -f docker-compose.prod.yml exec app alembic revision --autogenerate -m "xxx"
docker compose -f docker-compose.prod.yml exec app alembic upgrade head
```

---

## 7. 横向扩容

应用层无状态，直接加副本，Caddy 的 `reverse_proxy app:8000` 会对所有副本轮询：

```bash
docker compose -f docker-compose.prod.yml up -d --scale app=3
```

压一压看效果（见 [`../server/loadtest/README.md`](../server/loadtest/README.md)）：

```bash
python app/server/loadtest/loadtest.py \
    --base-url https://pilgrim.example.com/api/v1 -c 100 --duration 30
```

再往上：给 PostgreSQL 加只读副本承接榜单/统计读；连接数吃紧时前置
**PgBouncer**（transaction 模式）；`stat_events` 按月分区。详见架构文档 §6。

---

## 7.5 赛季结算与防作弊（定时任务）

两类后台任务，用 `X-Admin-Token`（`PP_ADMIN_TOKEN`）保护的 `/admin/*` 端点，
也可直接跑管理脚本（更适合 cron）。

**防作弊重算**——可疑成绩进 `score_reviews` 队列、暂不进榜，重算通过才进榜。
每几分钟跑一次：

```bash
# crontab：每 5 分钟处理一次队列
*/5 * * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app \
  python scripts/recompute_reviews.py --limit 500
```

**赛季结算**——赛季末快照各榜前三、发奖励 token（生命冠冕/棕榈枝/朝圣杖），
并标记赛季已结算；新赛季按季度自动开启。每天跑 `--rollover`（幂等，只在跨季后真正结算）：

```bash
# crontab：每天 04:00 结算上一季（若已结算则无操作）
0 4 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app \
  python scripts/settle_season.py --rollover
```

**聊天留存清理**——聊天记录入库保留 `PP_CHAT_RETENTION_DAYS`（默认 7）天，过期自动删除
（连带上传图片）。每天跑：

```bash
0 5 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T app \
  python scripts/purge_chat.py
```

> 上传的图片存在 `PP_MEDIA_DIR`（默认 `media/`），经 `/media/` 同源托管；生产建议挂持久卷
> 并对图片做反代缓存。聊天频道：本关 / 世界 / 私聊；敏感词过滤与禁言（`/admin/mute`）已内置。

手动结算某一季：`... python scripts/settle_season.py --season 2026-S1`。
对应 HTTP（需管理员头）：`POST /api/v1/admin/seasons/{season}/settle`、
`POST /api/v1/admin/seasons/rollover`、`POST /api/v1/admin/reviews/recompute`、
`GET /api/v1/admin/reviews?status=pending`。玩家端用 `GET /api/v1/rewards` 看自己获得的奖励。

> 调阈值：`PP_SCORE_TOLERANCE`、`PP_MIN_MS_PER_CHAPTER`、`PP_DEVOUT_SCORE_MAX`。

## 8. 备份

PostgreSQL 每日备份（Redis 是缓存，可丢）：

```bash
# 加进 crontab：每天 03:00 备份并保留 14 天
0 3 * * * docker compose -f /srv/pilgrim/docker-compose.prod.yml exec -T postgres \
  pg_dump -U pilgrim pilgrim | gzip > /srv/pilgrim/backups/pilgrim-$(date +\%F).sql.gz
```

恢复：`gunzip -c 备份.sql.gz | docker compose ... exec -T postgres psql -U pilgrim pilgrim`。

---

## 8.5 管理后台与监控

**可视化管理后台**（同源托管，无跨域）：访问 `https://pilgrim.example.com/admin-ui/`，
填入 API base（`/api/v1`）与 `PP_ADMIN_TOKEN`，即可：复核/重算防作弊队列、批准或拒绝
申诉、结算赛季、查看章节漏斗。生产建议再在 Nginx/Caddy 对 `/admin-ui` 与 `/api/v1/admin`
加 IP 白名单或 Basic Auth 双重保护。

**Prometheus + Grafana**：后端已暴露 `/metrics`。本地/单机一键起：

```bash
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d
# Grafana http://<host>:3000 （admin/admin，首次请改密码）——已自动预置数据源与
# "Pilgrim API" 面板（QPS/状态码、p95 时延、5xx 错误率、热门端点）。
# Prometheus http://<host>:9090
```

生产请把 Grafana 密码、端口暴露收敛到内网或加反代鉴权。

**告警（Alertmanager）**：observability 叠加层已含 Alertmanager（:9093）。规则在
`observability/alert_rules.yml`（5xx 率 >5%、p95 >1s、目标宕机、无流量），默认路由到
**飞书/钉钉桥接**服务 `alert-bridge`。启用时设环境变量后再起叠加层：

```bash
export FEISHU_WEBHOOK="https://open.feishu.cn/open-apis/bot/v2/hook/xxx"
export DINGTALK_WEBHOOK="https://oapi.dingtalk.com/robot/send?access_token=xxx"
export DINGTALK_SECRET="SECxxx"   # 钉钉加签（可选）
docker compose -f docker-compose.yml -f docker-compose.observability.yml up -d
```

桥接 `observability/alert_bridge/bridge.py` 解析告警、格式化中文消息并转发；
钉钉自动加签。也可改 `alertmanager.yml` 用 Slack/邮件接收器（注释里有示例）。

**实时同行（WebSocket）**：后端 `/api/v1/ws/ghosts/{chapter}?token=<JWT>` 已就绪，
跨副本靠 Redis pub/sub 广播。Caddy/Nginx 反代需放行 WebSocket 升级——Caddy 的
`reverse_proxy` 默认支持；客户端 `NetConfig.realtime=false` 可回退到纯异步幽灵。

**管理后台登录**：`/admin-ui/` 现为账号密码登录（`PP_ADMIN_USER`/`PP_ADMIN_PASSWORD`
→ 短期管理员 JWT）；cron/脚本仍可用 `X-Admin-Token`。两者都务必改强。

## 9. 监控与排错

- 健康探针：`curl https://pilgrim.example.com/healthz`（存活）、`/readyz`（含 DB+Redis）。
- 日志：`docker compose -f docker-compose.prod.yml logs -f app`（结构化 JSON，带 `X-Request-Id`）。
- 指标：`/metrics` 已接入，Grafana 看 QPS/时延/错误率（见 §8.5）。
- 常见问题：
  - **游戏白屏**：浏览器 F12 看控制台；多半是 WASM 的 MIME 类型——用 Caddy `file_server` 已正确处理。
  - **接口 401**：令牌过期或 `PP_JWT_SECRET` 改过导致旧令牌失效，客户端会自动重新登录。
  - **接口 429**：触发限流，调 `PP_RATE_LIMIT_PER_MIN` 或 Caddy/Nginx 边缘限流。
  - **`/readyz` 返回 false**：DB 或 Redis 没起来，`docker compose ps` 看容器状态。

---

## 10. 上线检查清单

- [ ] `PP_JWT_SECRET` 已换成强随机串，`.env` 不进 git。
- [ ] `PP_ENV=prod`，已跑 `alembic upgrade head`（不靠自动建表）。
- [ ] `PP_CORS_ORIGINS` 收紧到正式域名。
- [ ] `GET /api/v1/stats/overview` 已加管理员鉴权（当前骨架是开放的）。
- [ ] PostgreSQL 密码已改强，DB/Redis 端口**不**对公网暴露（只在 compose 内网）。
- [ ] 备份 cron 已配，并验证过能恢复。
- [ ] 压测过 `app=1` vs `app=3`，确认扩容生效、尾延迟达标。
- [ ] 健康探针接入告警（探针挂掉时通知你）。
