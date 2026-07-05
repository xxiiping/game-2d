extends Area2D

## 死亡区域。玩家进入 → 重生。

func _ready() -> void:
	$EditorVisual.hide()
	body_entered.connect(func(b):
		if b.get(&"_heavy_state") == 2:
			return
		if b.has_method(&"die"):
			b.die()
	)
