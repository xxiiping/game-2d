# 移动设计与调参指南

本文档记录 **规则、流程与调参思路**。不重复具体数值。

| 需要什么 | 去哪里看 |
|---|---|
| **当前正式数值** | `resources/movement/player_default.tres` |
| **字段含义与检查器注释** | `scripts/resources/player_movement_config.gd`（每个 `@export` 上的 `##`） |
| **移动逻辑** | `scripts/player.gd` |

改手感：只改 `.tres` → 运行测试 → 在下方「变更记录」记一笔。**不必**把新数字抄进本文。

---

## 单位与尺度

- 速度 px/s，加速度 px/s²，时间 秒，距离 px
- 逻辑视口 640×360，瓦片与玩家碰撞 16 px
- 物理 60 fps；时间类参数可按 `秒 × 60 ≈ 帧数` 估算

---

## 数据怎么流转

```
player_movement_config.gd   定义字段 + 出厂默认 + 注释
		 ↓
player_default.tres         运行时权威数值（游戏读这个）
		 ↓
player.tscn (movement)  →  player.gd 读取 movement.xxx
```

- **新建配置：** 编辑器 → 新建 Resource → `PlayerMovementConfig` → 另存为 `.tres`
- **角色变体：** 复制 `player_default.tres`，在 `player.tscn` 换挂 **Movement**
- **避免：** 只在关卡里玩家实例上改 movement 却不写回 `.tres`

---

## 系统设计（代码里看不直观的）

### 跳跃优先级

1. 平地跳缓冲 + 地面土狼 → **平地跳**（`Jump / Gravity` 组）
2. 否则蹬墙跳缓冲 + 可蹬墙条件 → **蹬墙跳**（`Wall` 组）

平地跳与蹬墙跳 **数值分组独立**；改 Wall 组不应影响 `jump_velocity` 等平地跳字段。

### 蹬墙跳判定

- **贴墙：** `is_on_wall()` 真实碰撞（无射线预探测）
- **可起跳：** 正在贴墙，或离墙后 `wall_coyote_time` 未过期（须先贴过墙）
- **链式连跳：** 下落贴墙时，若蹬墙跳缓冲仍有效，会刷新为满缓冲

### 蹬墙跳大跳 / 小跳

- **有**水平输入：`wall_jump_velocity` + `wall_jump_push`（起跳角度由二者比值决定）
- **无**水平输入：`wall_jump_velocity_min` + `wall_jump_push_min`

### 冲刺与跳跃截断

`dash_active_time` 内禁用松键跳跃截断，避免冲刺纵向动量被削掉。

---

## 调参思路（改哪个字段）

| 目标 | 优先动 |
|---|---|
| 平地跳更高 / 更矮 | `jump_velocity`、`rise_gravity` |
| 蹬墙链式升更高 | `wall_jump_velocity` ↑ 或 `wall_jump_push` ↓ |
| 蹬墙飞不到对面墙 | `wall_jump_push` ↑ |
| 墙上停更久 | `wall_slide_max` ↓、`wall_slide_gravity` ↓ |
| 离墙后更好按跳 | `wall_coyote_time` ↑ |
| 冲刺更远 / 更飘 | `dash_speed`、`dash_gravity_lock` |
| 地面更滑 / 更黏 | `ground_friction`、`ground_accel` |

具体字段说明悬停 `player_movement_config.gd` 对应导出项查看。

---

## 推荐调参流程

1. 打开 `resources/movement/player_default.tres`
2. 在检查器按组修改（Horizontal / Jump / Gravity / Wall / Dash …）
3. 运行 `level_01`，在左侧窄墙竖井做链式墙跳回归
4. 满意后 git 提交 `.tres`；若定稿且希望「新建资源」同手感，可同步 `player_movement_config.gd` 的 `:=` 默认值
5. 在本文 **变更记录** 写「改了什么、为什么」，**不必**列每个数字

---

## 回归测试清单

改 `.tres` 后建议逐项试：

- [ ] 只动 Wall 组时，平地跳手感不变
- [ ] 两面墙链式蹬墙跳可稳定上升
- [ ] 未贴墙不能蹬墙跳；贴墙后离墙短窗口内仍可跳
- [ ] 冲刺方向、距离、hitstop 正常
- [ ] 冲刺后松跳不会在手感窗内异常截断纵向速度

---

## 变更记录

| 日期 | 说明 |
|---|---|
| 2025-06 | 数值迁至 `PlayerMovementConfig` + `player_default.tres` |
| 2025-06 | 蹬墙跳独立分组；贴墙碰撞判定；墙土狼与链式缓冲 |
| 2025-06 | 本文改为设计/流程文档，具体数值仅以 `.tres` 为准 |
