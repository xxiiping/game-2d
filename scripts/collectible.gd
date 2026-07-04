extends Area2D

## 收集品。玩家接触 → 收集。

func _ready() -> void:
	body_entered.connect(func(b):
		if b is CharacterBody2D:
			SaveManager.add_collectible()
			queue_free()
	)
