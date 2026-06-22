# 用真·绘画级全身像替换程序化立绘

游戏里的角色立绘（站在 3D 世界里的 billboard）来自
`assets/characters/figures/<名>.webp`。当前这些是**程序化合成**的全身像
（上半身是原画，下半身是脚本画出来的腿/裙/袍）。想换成真正的绘画级全身像，
按下面三步走即可——**不用改任何代码**。

## 为什么要你来生成
这个运行环境无法把外部 AI 生图工具的结果自动存到磁盘（Adobe 上传被禁、
HuggingFace / hf.space 出口被墙）。但**你自己的 Adobe Firefly / Photoshop /
Express 登录里下载是正常的**，所以由你导出、丢进文件夹，是最可靠、质量最好的路线。

## 三步流程
1. 对每个角色，打开它的半身原图 `assets/characters/<名>.png`（512×640）。
2. 用 **Generative Expand（生成式扩展）向下扩展画布**，把人物补成站立全身，
   提示词（英文，直接粘贴）：
   > extend downward into a full standing figure, add the legs and feet in the
   > same period clothing, keep the exact same face, the same oil-painting style,
   > lighting and colours; full body from head to toe, plain or transparent background
   - 关键：**保持同一张脸、同样的服饰与画风**，只把身体补全到脚。
3. 抠掉背景导出**透明 PNG**，命名为 `assets/characters/figures_full/<名>.png`
   （同名覆盖即可），然后告诉我，我跑 `python3 tools/gen_full_figures.py`
   就会自动生成新的 `figures/<名>.webp` 接入游戏。（你也可以自己跑这条命令。）

## 图片规格（建议）
- 透明背景 PNG；人物**全身入画、脚接近底边**、头顶留一点点边距。
- 宽度约 768–1024px 即可；脚本会自动裁掉透明边并转成游戏用的 webp。
- 竖图比例约 1:2.4 ~ 1:3（正常站姿）。

## 14 个文件名 + 角色提示（帮助画对服饰）
| 文件名 (figures_full/&lt;名&gt;.png) | 角色 | 下半身建议 |
|---|---|---|
| `pilgrim.png` | 基督徒（主角，褐色行旅外套、背包） | 马裤+长袜+皮靴 |
| `pilgrim_child.png` | 主角·孩童版（米色衫、背包） | 马裤+长袜+鞋（童身比例） |
| `evangelist.png` | 传道者（年长、深绿长袍） | 及地长袍（教士袍） |
| `goodwill.png` | 善意（守门人，持钥匙） | 马裤+长袜+鞋 |
| `help.png` | 帮助（粗壮、劳作装） | 马裤+靴 |
| `hopeful.png` | 盼望（青年、绿色紧身上衣） | 马裤+长袜+鞋 |
| `obstinate.png` | 固执（神情严厉、深色外套） | 马裤+靴 |
| `pliable.png` | 易迁（青年） | 马裤+长袜+鞋 |
| `the_interpreter.png` | 释义者（年长、深色长袍、持烛） | 及地长袍 |
| `the_shepherds.png` | 群羊牧者（三位长袍牧者+羊） | 三人及地长袍（群像） |
| `watchful.png` | 警醒（守门人、紧身上衣） | 马裤+长袜+鞋 |
| `your_family.png` | 妻子与孩子（油画风，妻子蓝裙+两孩） | 妻子及地长裙 |
| `your_family_child.png` | 妻子与孩子（绘本风，母亲+两孩） | 母亲及地长裙 |
| `apollyon.png` | 亚玻伦（狮龙怪物 Boss） | 全身怪兽身躯（站立/扑姿） |

## 小贴士
- 可以先只做主角几张（`pilgrim`、`evangelist`、`your_family`）试水，满意再补齐。
- 旧的半身像备份在 `assets/characters/figures_busts_backup/`，程序化版本可随时用
  `python3 tools/make_full_figures.py` 重建——你放进 `figures_full/` 的真图**优先**，
  不会被覆盖（脚本不读 figures_full）。
- 想批量改提示词归类，见 `tools/make_full_figures.py` 顶部的 `MODE` 表。
