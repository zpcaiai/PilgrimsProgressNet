# 后端部署到 Hugging Face Space（Docker）

把 `server/`（FastAPI）部署成一个 HF Space,给 Vercel 上的网页版当后端。
前端见 [`DEPLOY_VERCEL.md`](DEPLOY_VERCEL.md);本机/自有服务器整套见 [`DEPLOYMENT.md`](DEPLOYMENT.md)。

---

## 0. 为什么这么拆

HF Space(Docker SDK)= **跑一个你的 Dockerfile 容器**,对外暴露**一个端口**(默认 7860,可用
`app_port` 改),走 HTTPS:`https://<用户名>-<space名>.hf.space`。但 HF **不提供 Postgres/Redis,
且容器磁盘是临时的**——重启/休眠后写到盘上的数据**全部丢失**。

所以本项目的 `docker-compose.yml`(app + postgres + redis + nginx 四件套)**不能照搬**。正确拆法:

```
玩家浏览器 ──HTTPS──▶ Vercel(静态 WASM 游戏)
        │ fetch / wss
        ▼
  HF Space(只跑 FastAPI app 容器, app_port=8000)
        │                      │
        ▼                      ▼
  Neon/Supabase(Postgres)   Upstash(Redis)   ← 外部托管, 数据持久
```

仓库已为此准备好:`server/entrypoint.sh`(启动先迁移再起 gunicorn)、`server/Dockerfile`
(已改用 entrypoint)、`server/hf-space/README.md`(带 HF YAML 头,放到 Space 根目录)。

---

## 1. 先开外部 Postgres + Redis（免费档即可）

### Postgres —— Neon（或 Supabase）

1. <https://neon.tech> 注册,New Project,记下连接串。Neon 默认给的是:
   `postgresql://USER:PASS@ep-xxx.region.aws.neon.tech/neondb?sslmode=require`
2. **改成本项目要的 asyncpg 形式**(两处改动):
   - `postgresql://` → `postgresql+asyncpg://`
   - `?sslmode=require` → `?ssl=require`  ← **关键**:代码直接用连接串建 async 引擎,
     asyncpg 认 `ssl` 不认 `sslmode`,不改这里会连不上。
   - 用 **Direct connection(非 pooled)** 端点——本项目自带连接池,走 Neon 的 pgbouncer 池化
     端点会和 asyncpg 的 prepared statement 打架。Neon 控制台把 "Pooled connection" 关掉再复制。

   最终:
   ```
   PP_DATABASE_URL=postgresql+asyncpg://USER:PASS@ep-xxx.region.aws.neon.tech/neondb?ssl=require
   ```

> Supabase 同理:用 5432 的 **Session/Direct** 串(不是 6543 pooler),
> `postgresql+asyncpg://postgres:PASS@db.<ref>.supabase.co:5432/postgres?ssl=require`。

### 1.1 把表建到 `PilgrimsProgressDB`（库 vs 表，谁来建）

> **先纠正一个常见误解**:把代码推到 **GitHub** **不会**让 Neon 自动建表——Neon 不监听你的
> GitHub 仓库。**表是"迁移运行"那一刻才建的**,跟 git 本身无关。本项目里跑迁移的是
> **HF Space 启动时的 `entrypoint.sh`**(它执行 `alembic upgrade head`)。所以会"自动建表"的
> 那个 push,是 **push 到 HF Space 仓库**(触发 Space 重建、容器启动、迁移执行),不是 push 到 GitHub。

两层概念别混:
- **数据库(database)`PilgrimsProgressDB`** —— 这个要**先存在**。Neon 默认库叫 `neondb`;要用
  `PilgrimsProgressDB` 就去 Neon 控制台 **Databases → New Database** 建一个,或直接把连接串末尾
  的库名写成它。**alembic/应用不会替你建数据库**,只会在已存在的库里建表。
- **数据表(tables)** —— 由迁移创建(本项目共 **12 张表 + 索引**,见 `server/schema.sql`)。

⚠️ **大小写**:Postgres 不带引号的标识符会被转成小写。`PilgrimsProgressDB` 含大写,连接串里必须
**原样大小写**:`.../PilgrimsProgressDB?ssl=require`。想省心可干脆用全小写库名 `pilgrimsprogressdb`,
免得到处对大小写。连接串里的库名(`/` 后那段)就是要建表的目标库。

**建表三选一**(都把表建进 `PilgrimsProgressDB`):

1. **让 HF Space 建(推荐,即你说的"push 自动建")**:把 `PP_DATABASE_URL` 指到
   `.../PilgrimsProgressDB?ssl=require`,push 到 Space → 启动跑 `alembic upgrade head` → 表自动出现。
   以后改了表结构(加迁移),再 push 一次即自动增量迁移。
2. **本机一条命令直接建**(不想等 Space):
   ```bash
   cd server
   PYTHONPATH=. PP_DATABASE_URL="postgresql+asyncpg://USER:PASS@HOST/PilgrimsProgressDB?ssl=require" \
     python3 -m alembic upgrade head
   ```
3. **直接灌 SQL**:把仓库里的 [`../server/schema.sql`](../server/schema.sql) 全文贴进 Neon 的
   **SQL Editor**(先在左上把数据库切到 `PilgrimsProgressDB`)执行——它同时会写好
   `alembic_version`,之后再跑迁移会认为已是最新,不会重复建。

> `schema.sql` 是从迁移自动生成的快照(`alembic upgrade head --sql`),仅供查看/直接建表用;
> **改表结构请改 `alembic/versions/` 下的迁移**,然后重新生成它,别手改这个文件。

### Redis —— Upstash

1. <https://upstash.com> 注册,Create Database(Redis),选离 HF 近的区域。
2. 复制 **TLS** 连接串(`rediss://`,redis-py 支持):
   ```
   PP_REDIS_URL=rediss://default:PASS@xxx.upstash.io:6379
   ```

---

## 2. 建 Space + 推代码

### 2.1 建 Space

<https://huggingface.co/new-space> → 取个名(如 `pilgrim-api`)→ **Space SDK 选 `Docker`**
（**Blank / 空模板**,不要选某个 Docker 模板）→ 创建。建好后它就是个 git 仓库:
`https://huggingface.co/spaces/stephenzao/pilgrim-api`,公开 URL 为
`https://stephenzao-pilgrim-api.hf.space`。

### 2.2 把 `server/` 推上去

Space 仓库的**根目录**必须是后端代码(`Dockerfile`、`app/`、`alembic/`、`entrypoint.sh`…),
且根目录的 `README.md` 必须带 HF 的 YAML 头。用仓库里准备好的那份覆盖即可:

```bash
# 在本项目根目录
git clone https://huggingface.co/spaces/stephenzao/pilgrim-api /tmp/pilgrim-space

# 把后端代码拷进 Space(排除本地产物/测试,精简体积)
rsync -av --delete \
  --exclude '.venv' --exclude '__pycache__' --exclude '.pytest_cache' \
  --exclude 'tests' --exclude 'loadtest' --exclude 'media' \
  --exclude 'docker-compose*.yml' --exclude 'nginx.conf' \
  server/ /tmp/pilgrim-space/

# 用带 HF YAML 头的 README 覆盖 Space 根 README
cp server/hf-space/README.md /tmp/pilgrim-space/README.md

cd /tmp/pilgrim-space
git add -A && git commit -m "Deploy Pilgrim backend to HF Space" && git push
```

> 排除 `docker-compose*.yml`/`nginx.conf` 是因为 Space 只跑单容器,用不到它们。
> 留着也无害,但去掉更干净。`tests/` 体积大且 Space 不跑测试,排除即可。
>
> 第一次 `git push` 到 HF 会要登录:用户名填 HF 用户名,密码填 **Access Token**
> (<https://huggingface.co/settings/tokens>,建一个 write token)。大文件需 `git lfs`。

推上去后,Space 会自动开始 **Build**(看 Space 页右上 "Building" → "Running")。

---

## 3. 设置 Secrets（Space → Settings → Variables and secrets）

**别把这些写进代码**。逐个 **New secret** 添加(运行时它们就是 `PP_` 环境变量,
正好被 `app/config.py` 读到):

| Key | 值 | 必填 |
|---|---|---|
| `PP_ENV` | `prod` | ✅ |
| `PP_DEBUG` | `false` | ✅ |
| `PP_JWT_SECRET` | `openssl rand -hex 32` 生成 | ✅ |
| `PP_DATABASE_URL` | §1 的 Neon asyncpg 串(`+asyncpg`、`ssl=require`、direct) | ✅ |
| `PP_REDIS_URL` | §1 的 Upstash `rediss://` 串 | ✅ |
| `PP_CORS_ORIGINS` | 你的 Vercel 域名,如 `https://stephenzao-pilgrim.vercel.app`(精确、无尾斜杠) | ✅ |
| `PP_ADMIN_TOKEN` | 强随机串(cron/脚本管理头) | ✅ |
| `PP_ADMIN_PASSWORD` | 强口令(管理后台登录) | ✅ |
| `PP_EMAIL_DEV_ECHO` | `false`(生产别回显验证码) | 建议 |
| `PP_SMTP_HOST` / `PP_SMTP_USER` / `PP_SMTP_PASSWORD` / `PP_SMTP_FROM` | 想要邮箱绑定/找回才填;不填则该功能仅记日志 | 可选 |

> 改了任何 secret,Space 会自动重启生效。`PP_ENV=prod` 下不自动建表——但
> `entrypoint.sh` 启动会先跑 `alembic upgrade head` 建好表,无需手动操作。

---

## 4. 确认上线

Space 状态变 **Running** 后,看 **Logs** 应能看到:
`[entrypoint] alembic upgrade head ...` → `[entrypoint] starting gunicorn on 0.0.0.0:8000`。

探针(把域名换成你的):

```bash
curl https://stephenzao-pilgrim-api.hf.space/healthz   # -> {"status":"ok"}
curl https://stephenzao-pilgrim-api.hf.space/readyz    # -> {"ready":true,"db":true,"redis":true}
# 浏览器打开 .../docs 看交互式 API 文档
```

`readyz` 里 `db`/`redis` 都为 `true` 才算后端真正就绪。

---

## 5. 把前端接到这个后端

编辑 [`../scripts/net/NetConfig.gd`](../scripts/net/NetConfig.gd):

```gdscript
var base_url: String = "https://stephenzao-pilgrim-api.hf.space/api/v1"
var enabled: bool = true
var realtime: bool = true   # HF Space 支持 WebSocket, 实时同行/聊天可用(wss 自动派生)
```

然后**重新导出 Web** 并部署到 Vercel(见 [`DEPLOY_VERCEL.md`](DEPLOY_VERCEL.md),模式 B1 跨域)。
回到 Space 把 `PP_CORS_ORIGINS` 改成你**最终的 Vercel 域名**(含自定义域时填自定义域)。

进游戏后按 [`DEPLOYMENT.md`](DEPLOYMENT.md) §6 验收清单逐项点:匿名登录 → 埋点 → 同行人数 →
留言路标(M)→ 排行榜(B)→ 云存档 → 聊天(T)。

---

## 6. 关于数据持久与休眠（务必知道）

- **免费档会休眠**:Space 闲置一段时间后睡眠,下次请求冷启动(头一下较慢)。要常驻需升级硬件档。
- **磁盘临时**:外部 DB/Redis 的数据是**持久**的(在 Neon/Upstash 那边),但**容器本地磁盘**
  仍是临时的——也就是**聊天图片**(`PP_MEDIA_DIR=media`)会在重启后消失。两种处理:
  - 接受临时(图片偶尔丢,demo 够用);或
  - Space → Settings 挂一个 **Storage Bucket** 到 `/data`,再加 secret `PP_MEDIA_DIR=/data/media`,
    图片就持久了。
- **赛季结算 / 防作弊重算 / 聊天清理**这些 cron(`DEPLOYMENT.md` §5.7)在 HF 单容器里不会自己跑;
  需要的话用 **HF Jobs** 定时调 `scripts/*.py`,或在别处挂 cron 打 `/api/v1/admin/*`(带 `PP_ADMIN_TOKEN`)。

---

## 7. 常见问题

| 现象 | 排查 |
|---|---|
| Build 成功但 App 崩溃/一直重启 | 多半 `PP_DATABASE_URL` 不对:确认 `postgresql+asyncpg://` 前缀 + `?ssl=require`(不是 `sslmode`)+ 用 direct 端点。看 Logs 里 alembic 报错。 |
| `readyz` 里 `db:false` | DB 串错/SSL 没开/用了 pooler 端点。换 Neon **Direct** 串、`ssl=require`。 |
| `readyz` 里 `redis:false` | Upstash 必须 `rediss://`(TLS),别用 `redis://`。 |
| 打开域名 502 / 无响应 | App 没监听到 HF 路由的端口。确认 `README.md` 有 `app_port: 8000` 且 entrypoint 跑在 8000。 |
| 浏览器报 CORS | `PP_CORS_ORIGINS` 要等于你的 Vercel 源(`https://域名`,大小写/无尾斜杠都要对)。 |
| 实时聊天/同行不动,其它正常 | 检查前端 `realtime=true` 且 `base_url` 是完整 https 域名(wss 由它派生)。 |
| `git push` 到 Space 被拒 | 用 HF **write token** 当密码;大文件先 `git lfs install`。 |
| 表不存在 | entrypoint 默认会迁移;若设了 `PP_RUN_MIGRATIONS=0` 记得自己 `alembic upgrade head`。 |

---

*单容器上 HF、Postgres/Redis 外接、磁盘当临时——这是把一套 compose 后端塞进 Space 的标准做法。
要全功能 + 持久 + 自带 cron,自有服务器的同源方案(`DEPLOYMENT.md` §5)更省心;
HF 的好处是免费、零运维、HTTPS/WSS 现成。*
