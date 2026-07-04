# 输入映射 / Input Map

> 最后更新: 2026-07-04
> 键盘与手柄可同时使用，死区统一 0.2

## 游戏动作

| 动作 | ⌨ 键盘 | 🎮 PS5 |
|------|------|------|
| `move_left` | A | 十字键← / 左摇杆← |
| `move_right` | D | 十字键→ / 左摇杆→ |
| `move_up` | W | 十字键↑ / 左摇杆↑ |
| `move_down` | S | 十字键↓ / 左摇杆↓ |
| `jump` | Space | ×(Cross) / △(Triangle) |
| `dash` | Shift | ○(Circle) / □(Square) |
| `restart` | R | R3 |
| `heavy_fall` | C | R1 |

## 手柄按键对照

| PS5 | Godot 索引 | 绑定 |
|------|------|------|
| 左摇杆 X | Axis 0 | move_left(−1) / move_right(+1) |
| 左摇杆 Y | Axis 1 | move_up(−1) / move_down(+1) |
| 十字键 | Button 12-15 | move |
| ×(Cross) | Button 0 | jump |
| ○(Circle) | Button 1 | dash |
| □(Square) | Button 2 | dash |
| △(Triangle) | Button 3 | jump |
| R1 | Button 5 | heavy_fall |
| R3 | Button 11 | restart |

## 技术细节

- 死区: 0.2
- keycode: A=65, D=68, W=87, S=83, C=67, Space=32, Shift=4194325, R=82
- 文件: `project.godot` → `[input]` 段
