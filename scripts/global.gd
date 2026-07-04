extends Node

## 跨场景全局状态：记录场景切换时的出生位置。
## 过渡区域脚本写入，玩家 _ready 读取。

var next_spawn_position := Vector2.ZERO
var transition_active := false
