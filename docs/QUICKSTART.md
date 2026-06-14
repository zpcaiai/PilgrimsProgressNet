# 快速上手：起后端 + 跑游戏 + 验证联网

三步把联网版跑起来。纯单机随时可玩（把 `NetConfig.enabled` 设为 `false` 即可），
本文讲的是**带后端**的完整体验。

> 更深入：架构见 [`ARCHITECTURE_BACKEND.md`](ARCHITECTURE_BACKEND.md)，
> 上线见 [`DEPLOY_BACKEND.md`](DEPLOY_BACKEND.md)，
> 客户端网络层见 [`../scripts/net/README.md`](../scripts/net/README.md)。

---

## 第 1 步 · 起后端（Docker，一条命令）

```bash
cd server
cp .env.example .env          # 本地默认值即可直接用
docker compose up --build
```

起来后验证：

```bash
curl http://localhost:8080/healthz      # -> {"status":"ok"}
curl http://localhost:8080/readyz       # -> {"ready":true,"db":true,"redis":true}
```

也可浏览器打开 `http://localhost:8080/docs` 看交互式 API 文档。

> 没装 Docker？看 `server/README.md` 的"本地不用 Docker"小节用 venv 起。

---

## 第 2 步 · 跑游戏（Godot）

1. 确认后端地址：`scripts/net/NetConfig.gd` 的 `base_url` 默认就是
   `http://localhost:8080/api/v1`——与第 1 步一致，无需改。

2. Godot 4.2+ 打开 `project.godot`，按 **F5**。

网络层已默认接好（autoload + `Main.tscn` 里的 `NetUI`），无需任何手动接线。

---

## 第 3 步 · 验证联网

进游戏后逐项确认：

| 功能 | 怎么验证 | 预期 |
|---|---|---|
| 匿名登录 | 启动即自动进行 | 后端日志出现 `POST /api/v1/auth/device 200` |
| 数据统计 | 开始游戏、进出章节 | 后端日志出现 `POST /api/v1/stats/events 202` |
| 多人同行 | 进入任一章节走几步 | 左上出现"同行人数"挂件；`POST /ghosts/trail`、`GET /ghosts/...` |
| 留言路标 | 按 **M**，写一句，回车 | toast"路标已留下"；再次进本关能看到（多开一个存档/设备更明显）|
| 排行榜 | 通关到终章（调试可按 F7 连跳） | 终章自动提交；按 **B** 看榜，自己上榜 |
| 云存档 | 存档（F5 或暂停菜单 Save） | `PUT /api/v1/saves/slot_1 200`，本地+云端各一份 |
| 云存档冲突 | 见下方"造一个冲突" | 弹出"云端存档冲突"对话框 |

### 用后端日志实时观察

另开一个终端：

```bash
cd server
docker compose logs -f app
```

边玩边看请求流过，最直观。

### 造一个云存档冲突（验证弹窗）

原理：客户端记得"上次云端 version"，若服务端 version 比它新，上传就 409 → 弹窗。
所以要用**游戏自己的账号**把云端偷偷推进一版。

1. 正常玩、存一次档（云端 `slot_1` 的 version 变成 1，客户端也记下 1）。
2. 找到游戏的 `device_id`——它存在 Godot 的 `user://device_id.txt`，macOS 路径通常是
   `~/Library/Application Support/Godot/app_userdata/Pilgrim's Road - Burden Fallen/device_id.txt`：

   ```bash
   DEV=$(cat ~/Library/Application\ Support/Godot/app_userdata/Pilgrim*/device_id.txt)
   TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/device \
     -H 'Content-Type: application/json' -d "{\"device_id\":\"$DEV\"}" \
     | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

   # 用 version=1（与当前云端一致）推一版 -> 云端变 version 2，但客户端还停在 1
   curl -s -X PUT http://localhost:8080/api/v1/saves/slot_1 \
     -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
     -d '{"payload":{"game_state":{"current_chapter_id":"vanity_fair"}},"version":1}'
   ```

3. 回到游戏再存一次档——客户端用旧 version(1) 上传，服务端已是 2，返回 409，
   **云存档冲突弹窗**弹出，可选"下载云端"或"保留本地"。

---

## 压一压（可选）

确认横向扩容有效：

```bash
cd server
docker compose up --build --scale app=3        # 3 副本
python loadtest/loadtest.py -c 100 --duration 30
```

对比 `--scale app=1` 与 `app=3` 的 p90/p99 与吞吐（详见 `server/loadtest/README.md`）。

---

## 常见问题

- **游戏能玩但不联网**：后端没起，或 `base_url` 不对。所有联网功能会静默退化为单机，
  不影响通关。`curl /healthz` 确认后端，核对 `NetConfig.base_url`。
- **想纯单机**：`NetConfig.gd` 里 `enabled = false`，启动不再发任何请求。
- **F5 报 parse 错**：把报错贴出来即可定位（沙箱无法替你跑 Godot 编译）。
- **WASM 网页版联网**：需同源部署或后端放开 CORS，见 `DEPLOY_BACKEND.md` 第 5 步。
