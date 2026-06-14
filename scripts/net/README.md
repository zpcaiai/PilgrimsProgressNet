# Godot 网络层（`scripts/net/`）

把单机版接到 [`server/`](../../server) 后端的客户端层。**完全可选、默认安全**：
`NetConfig.enabled = false` 或后端不可达时，每个服务都退化为 no-op，游戏照常单机运行。

## 设计原则

- **不侵入玩法**：所有服务只监听 `EventBus` 信号、读写 `GameState` /
  `SpiritualStateManager` / `QuestManager`，不改动现有任何一行玩法代码。
- **离线降级**：任何请求失败都静默回退到本地行为（本地存档照常）。
- **匿名起步**：首次启动自动生成 `user://device_id.txt`，换取 JWT，无需注册。

## 单例一览

| 文件 | 作用 |
|---|---|
| `NetConfig.gd` | 基址、总开关、采样间隔等配置 |
| `ApiClient.gd` | `HTTPRequest` 的 async/JSON 封装，自动带令牌 |
| `AuthService.gd` | 设备令牌登录；邮箱绑定/找回（验证码）；暴露 `is_online` / `player_id` / `email` |
| `CloudSaveService.gd` | 监听 `save_completed` 上传；`download()` 拉云存档 |
| `LeaderboardService.gd` | 终章自动提交成绩；`fetch(board, diff, season)` 取榜（本赛季/历史） |
| `GhostService.gd` | 异步同行：采样足迹、拉取他人幽灵与在线人数 |
| `RealtimeService.gd` | 实时同行：WebSocket 连接本关房间，收发实时位置（`NetConfig.realtime`） |
| `AnalyticsService.gd` | 关键信号转埋点，批量上报 |

## 接入步骤

**已默认接好，开箱即用。** 仓库已完成下面 1–3 的接线，你通常只需做第 2 步改地址：

1. ✅ **7 个 autoload 已注册**在 `project.godot` 的 `[autoload]` 段
   （顺序：`NetConfig`、`ApiClient`、`AuthService` 在依赖它们的服务之前）。

2. **设置后端地址**：编辑 `NetConfig.gd` 的 `base_url`
   （本地 docker：`http://localhost:8080/api/v1`；同源上线：`/api/v1`）。
   不想联网时把 `NetConfig.enabled` 设为 `false`，全部退化为单机。

3. ✅ **UI 已接入**：`Main.tscn`（即 `Main.gd._ready()`）已实例化
   `scenes/ui/NetUI.tscn`（榜单 B / 同行挂件 / 云存档冲突弹窗 / 留言 M），
   且 `ChapterBase` 会给每个章节自动挂 `GhostRenderer` 并绑定玩家——
   **无需再手动调用 `GhostService.set_player()`**。

> 想自定义而非用示例 UI，也可直接消费这些信号：
> `LeaderboardService.board_received`、`GhostService.ghosts_received` /
> `presence_updated`、`CloudSaveService.cloud_conflict`。

## 示例 UI（排行榜 / 同行）

仓库已附带可直接用的示例界面，全部"自建式"，无需在编辑器里连线：

| 文件 | 作用 | 触发 |
|---|---|---|
| `scripts/ui/LeaderboardPanel.gd` | 排行榜面板（三个榜 + 我的排名），按 **B** 开关 | 键盘 B |
| `scripts/ui/CompanionOverlay.gd` | 左上"本关同行人数 + 他人路标留言"小挂件 | 自动随章节刷新 |
| `scripts/level/GhostRenderer.gd` | 在 3D 世界里渲染他人幽灵（沿足迹行走的半透明身影 + 路标光点） | 由 `ChapterBase` 自动挂载 |
| `scripts/ui/CloudSyncDialog.gd` | 云存档冲突弹窗（下载云端 / 保留本地） | `CloudSaveService.cloud_conflict` |
| `scripts/ui/MarkerInput.gd` | 留言路标输入框，按 **M** 弹出 | 键盘 M |
| `scripts/ui/AccountPanel.gd` | 账号面板：绑定邮箱 / 找回账号 + 赛季奖励，按 **N** 弹出 | 键盘 N |
| `scripts/ui/RewardPopup.gd` | 上线时若有未读赛季奖励，自动弹出嘉奖窗并标记已读 | 登录自动 |
| `scripts/ui/ReviewPanel.gd` | 成绩复核/申诉：查看被标记成绩，对被拒成绩发起申诉，按 **R** 弹出 | 键盘 R |
| `scripts/ui/ChatPanel.gd` | 游戏内实时聊天：本关/世界/私聊，按 **T** 输入；@自动补全、点击看原图、角落消息日志 | 键盘 T |
| `scripts/ui/ConversationPanel.gd` | 私聊会话列表（独立窗口）：会话+未读、选中看完整历史并回复，按 **Y** | 键盘 Y |
| `scenes/ui/NetUI.tscn` | 把上面三个 CanvasLayer 打包好的场景 | 实例化即可 |

接入方式：

1. **整体 UI（一步到位）**：在 `Main.tscn`（或主 HUD 所在场景）里实例化
   `scenes/ui/NetUI.tscn`，即同时获得排行榜面板、同行挂件、云存档冲突弹窗。
   离线时面板显示"离线模式"提示，不报错。

2. **世界内幽灵（已自动接好）**：`ChapterBase._ready()` 现在会在网络层启用时，
   自动给每个章节挂一个 `GhostRenderer` 并绑定当前 `player`——**16 个章节无需逐个改**。
   渲染器会把玩家注册给 `GhostService` 采样足迹，并在 `ghosts_received` 到达时
   生成沿路重走的半透明朝圣者与路标光点。想关掉只需设 `NetConfig.enabled = false`。

3. **云存档冲突**：当本设备的存档版本落后于云端（例如你在另一台设备玩过），
   上传会返回 409，`CloudSaveService` 发出 `cloud_conflict`，弹窗自动出现并暂停游戏，
   让玩家选择"下载云端"或"保留本地（覆盖云端）"。

4. **留言路标**：按 **M** 弹出输入框（`MarkerInput.gd`），写一句鼓励留在当前位置，
   其他玩家下次进入本关会看到。也可在代码里直接调
   `GhostService.leave_marker("白日将尽，仍要前行")`。

5. **账号绑定 / 找回**：按 **N** 打开账号面板。绑定邮箱后，可在另一台设备用
   "找回账号 + 邮箱验证码"把存档找回到本机（验证码：开发模式直接显示，生产走邮件）。

6. **赛季榜**：榜单面板（B）顶部可切"本赛季 / 历史总榜"。赛季按季度自动滚动
   （如 `2026-S2`），每次提交同时进当季榜与历史总榜；服务端可用 `PP_SEASON_OVERRIDE` 固定赛季。

7. **赛季奖励通知**：玩家上线时若上个赛季进了前三、且尚未读，`RewardPopup` 自动弹出
   嘉奖窗（生命冠冕 / 棕榈枝 / 朝圣杖），点确认后服务端标记已读，不再重复弹。

8. **成绩申诉**：按 **R** 打开复核面板，查看被防作弊标记的成绩；被**拒绝**的可一键
   "申诉"，转入 `appealed` 状态等待管理员人工复核（`POST /admin/reviews/{id}/resolve`）。

9. **实时聊天（IM）**：按 **T** 聊天，支持 **本关 / 世界 / 私聊** 三个频道（私聊从本关在线者
   下拉选择）。可**发图片**（"图"按钮选图→上传，服务端压缩并生成缩略图，对方看缩略图）。
   **@提及高亮**：消息里的 @某人/@所有人 会高亮，被@时有特别提示。**私聊未读红点**：离线/未读
   消息有数量角标，打开会话自动已读。角落常驻消息日志，关闭时新消息以 toast 闪现；进房补最近
   50 条历史。聊天经**敏感词过滤**与**禁言**约束，记录**留存 7 天**自动清理。

10. **实时连接质量与自适应缓冲**：同行挂件显示延迟与质量（通畅/一般/不稳，ping/pong 测得）；
    同伴位置用**插值缓冲延迟回放**渲染，且延迟会**按网络质量自适应**（好 ~90ms / 差 ~260ms）抗抖动。

11. **@自动补全 / 原图查看 / 私聊会话**：聊天输入 **@** 触发同关在线者补全下拉；
    聊天里的图片缩略图**点击看原图**——全屏查看器支持**滚轮缩放**与**保存到本地**；按 **Y** 打开
    **私聊会话列表**独立窗口：可**搜索昵称**、**☆置顶**（置顶会话排在最前），右侧看完整历史并回复。

12. **@离线提醒**：被人 @到（按昵称匹配）会**入库为提醒**，即使当时不在线，**下次登录**也会以
    toast 补发；查看后自动标记已读。会话置顶与未读都跨设备保留。

13. **表情/快捷短语 · 拖拽看图 · 撤回**：输入栏 😀 按钮弹**表情与快捷短语**选择器一键插入，
    带**最近使用**记忆（本地持久化置顶）；图片全屏查看器支持**拖拽平移**（配合滚轮缩放）；
    自己 **2 分钟内**的消息可点 **×撤回**，撤回后留**"此消息已撤回"占位**（会话历史也保留占位）。

14. **已读回执**：在私聊会话面板里，当对方读到你的最新消息，会显示**"对方已读"**
    （实时回执 + 重开时按持久状态补显）。

15. **群聊/临时房间 · 引用回复 · 自定义贴图包**：频道选 **群聊**，点"建"生成房间码或填码点"进"
    加入临时房间（跨章节，按码进同一群，含历史）；任意消息点 **引** 可**引用回复**（输入上方显示引用条），
    消息与历史都会显示被引内容；表情面板底部的**贴图包**可"＋添加"上传图片为贴图、点击发送、右键删除（本地持久化）。

> 快捷键 **B**（榜单）/ **M**（留言）/ **N**（账号）/ **R**（申诉）/ **T**（聊天）/ **Y**（私聊会话）
> 与现有按键无冲突（战斗用 J/K/L/U/P，C=人物，Tab=地图，Esc=暂停）。

## Web 导出注意

WASM 版的 HTTP 请求受浏览器 CORS 约束 —— 后端 `PP_CORS_ORIGINS` 要包含游戏域名。
若同源部署（Nginx 同时托管 `build/web/` 与 `/api`），则无跨域问题，最省心。
