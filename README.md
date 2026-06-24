# game-2d

Godot 4.7 像素风 2D 平台游戏。核心移动为独立实现的 Celeste 风格手感（非第三方代码/素材移植）。

## 环境要求

- [Godot 4.7](https://godotengine.org/)（项目当前基于 4.7-stable）
- 可选：[godot-ai](https://github.com/) MCP 插件（已内置 `addons/godot_ai`，用于编辑器协作）

## 快速开始

1. 用 Godot 打开本项目目录
2. 按 **F5** 运行，主场景为 `scenes/levels/level_01.tscn`

### 操作

| 按键 | 动作 |
|---|---|
| A / D 或 ← → | 左右移动 |
| W / S 或 ↑ ↓ | 上下（冲刺八向） |
| Z 或 Space | 跳跃 |
| J 或 Shift | 冲刺 |

## 项目结构

```
game-2d/
├── scenes/
│   ├── player/player.tscn
│   └── levels/level_01.tscn
├── scripts/
│   ├── player.gd
│   └── resources/player_movement_config.gd
├── resources/movement/player_default.tres
├── docs/movement-params.md      # 玩家移动数值与调参说明
├── assets/placeholder/
└── addons/godot_ai/
```

## 世界尺度

| 项 | 值 |
|---|---|
| 逻辑视口 | 320 × 180 |
| 窗口显示 | 1280 × 720（整数缩放） |
| 瓦片 | 8 px |
| 玩家碰撞体 | 8 × 8 |

## 文档

| 文档 | 内容 |
|---|---|
| [docs/movement-params.md](docs/movement-params.md) | 玩家移动：系统设计、调参流程、回归测试、变更记录 |

移动逻辑在 `scripts/player.gd`；运行时数值来自 `resources/movement/player_default.tres`。字段定义与检查器注释见 `scripts/resources/player_movement_config.gd`。

## 关卡

`level_01.tscn` 使用 `TileMapLayer` 手动画烘焙地形，无运行时关卡生成器。

## 开发约定

- 场景结构优先通过 godot-ai MCP 操作；脚本逻辑直接编辑 `.gd`
- 阶段验收：`project_run` + `logs_read`，确认无运行时错误

## 许可与边界

- 本项目代码与占位资源为原创实现
- Celeste 仅作机制与手感设计参考，禁止复制其源码或素材
