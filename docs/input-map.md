# 输入映射 / Input Map

> 最后更新: 2026-07-03  
> 键盘与手柄可同时使用，随时切换，死区统一为 0.2

## 游戏动作

| 动作 | ⌨ 键盘 | 🎮 PS5 手柄 |
|------|------|------|
| `move_left` | A | 十字键← / 左摇杆← |
| `move_right` | D | 十字键→ / 左摇杆→ |
| `move_up` | W | 十字键↑ / 左摇杆↑ |
| `move_down` | S | 十字键↓ / 左摇杆↓ |
| `jump` | Space | × (Cross) |
| `dash` | Shift | ○ (Circle) / R1 |
| `restart` | R | 右摇杆按下 (R3) |

## 手柄按键对照

| PS5 按键 | Godot 索引 | 绑定动作 |
|------|------|------|
| 左摇杆 X | Axis 0 | move_left (−1) / move_right (+1) |
| 左摇杆 Y | Axis 1 | move_up (−1) / move_down (+1) |
| 十字键 ↑↓←→ | Button 12/13/14/15 | move_up/down/left/right |
| × (Cross) | Button 0 | jump |
| ○ (Circle) | Button 1 | dash |
| R1 | Button 5 | dash（备用） |
| 右摇杆按下 (R3) | Button 11 | restart |

## 技术细节

- 死区 (deadzone): 0.2（适合摇杆微操，比默认 0.5 更灵敏）
- 键盘 keycode: A=65, D=68, W=87, S=83, Space=32, Shift=4194325, R=82
- 文件: `project.godot` → `[input]` 段
- 只通过 MCP 修改以确保编辑器内存与文件同步
