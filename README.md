# game-2d

Godot 4.7 像素风 2D 平台游戏。原创实现。

## 快速开始

1. Godot 4.7 打开项目
2. 按 **F5** 运行

### 操作

| ⌨ 键盘 | 🎮 PS5 | 动作 |
|---|---|---|
| A / D | 左摇杆 / 十字键 | 移动 |
| W / S | 左摇杆 / 十字键 | 冲刺方向 |
| Space | ×(Cross) / △(Triangle) | 跳跃 |
| Shift | ○(Circle) / □(Square) | 冲刺 |
| C | R1 | 重坠+破瓦（按住蓄力0.5s） |
| R | R3 | 重新载入 |

> 详见 [docs/input-map.md](docs/input-map.md)

## 核心机制

| 机制 | 说明 |
|---|---|
| 平地跳 | 满跳/短跳 + 土狼时间 + 输入缓冲 |
| 蹬墙跳 | 墙滑 + 链式蹬墙 + 墙土狼 |
| 八向冲刺 | hitstop + 相机震动 + 转角修正 |
| 重坠破瓦 | 按住C蓄力→加速下落+破坏脚下脆瓦 |
| 传送锚 | 重坠落入锚点→静止→瞬移到下层 |
| 可破坏方块 | 冲刺撞击→反弹→销毁 |

## 项目结构

```
game-2d/
├── scenes/
│   ├── player/player.tscn
│   ├── levels/level_01.tscn
│   └── objects/
│       ├── transition_zone.tscn
│       └── breakable_block.tscn
├── scripts/
│   ├── player.gd
│   ├── global.gd
│   ├── transition_zone.gd
│   ├── breakable_block.gd
│   └── resources/player_movement_config.gd
├── resources/movement/player_default.tres
├── docs/
│   ├── movement-params.md
│   └── input-map.md
├── assets/
│   ├── audio/          (BGM + SFX)
│   ├── player/animations/ (idle/run/jump/dash)
│   └── placeholder/    (瓦片/背景占位)
└── addons/godot_ai/
```

## 世界尺度

| 项 | 值 |
|---|---|
| 视口 | 640 × 360 |
| 窗口 | 1280 × 720 (2x) |
| 瓦片 | 16 px |
| 玩家 | 16 × 16 |
| 适配 | 720p/1080p/2K/4K 完美整数缩放 |

## 文档

| 文档 | 内容 |
|---|---|
| [docs/movement-params.md](docs/movement-params.md) | 移动设计、调参流程、回归测试 |
| [docs/input-map.md](docs/input-map.md) | 输入映射 |
