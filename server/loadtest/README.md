# 压测脚本（loadtest）

模拟大量并发玩家跑真实循环（登录→上传存档→提交成绩→上传足迹→拉榜单/同行→埋点），
输出每个接口的吞吐与延迟分位（p50/p90/p99），用来验证横向扩容效果。

## 用法

先起多副本后端：

```bash
cd server
docker compose up --build --scale app=3
```

再压测（另开一个终端）：

```bash
cd server
python loadtest/loadtest.py --base-url http://localhost:8080/api/v1 \
    --concurrency 50 --duration 20
```

参数：

| 参数 | 默认 | 说明 |
|---|---|---|
| `--base-url` | `http://localhost:8080/api/v1` | 后端地址（经 Nginx） |
| `--concurrency` | 50 | 同时模拟的玩家数 |
| `--duration` | 20 | 持续秒数 |
| `--self-check` | — | 干跑校验脚本本身，无需后端 |

## 对比扩容效果

用同样的 `--concurrency` 分别跑 `--scale app=1` 与 `--scale app=3`，对比
overall p90/p99 与 throughput：副本越多，高并发下尾延迟应明显下降、吞吐上升，
直到瓶颈下沉到 PostgreSQL/Redis（此时按架构文档 §6 加 PgBouncer / 读副本）。

依赖：`pip install httpx`（已在 `requirements.txt` 中）。
