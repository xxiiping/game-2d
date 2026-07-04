extends Area2D

## 复活点。玩家进入后自动设置为重生位置。

func _ready() -> void:
	$EditorVisual.hide()
	body_entered.connect(func(b):
		if b.has_method(&"set_respawn"):
			b.set_respawn(global_position)
	)
