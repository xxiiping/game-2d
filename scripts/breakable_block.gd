extends StaticBody2D

## 可破坏方块。玩家冲刺撞击 → 反弹 → 销毁。
## 旋转实例即可改变方向。

@export var bounce_speed := 200.0
@export var destroy_time := 0.5

var _dead := false


func _ready() -> void:
	var phys: RectangleShape2D = $Shape.shape
	var det: RectangleShape2D = $Detector/CollisionShape2D.shape
	det.size = phys.size + Vector2(12, 12)

	$Detector.body_entered.connect(func(b):
		if _dead or not b is CharacterBody2D: return
		if b.get(&"_dash_active_timer") == null or b._dash_active_timer <= 0.0: return
		_dead = true
		var away: Vector2 = (b.global_position - global_position).normalized()
		b.velocity = away * bounce_speed
		b._dash_active_timer = 0.0
		b._dash_grav_lock_timer = 0.0
		b._dash_ctrl_lock_timer = 0.0
		b._dash_input_silence_timer = 0.0
		b._input_lock_timer = 0.5
		$Shape.set_deferred(&"disabled", true)
		$Detector.call_deferred(&"set_monitoring", false)
		$Anim.play(&"destroy")
		await get_tree().create_timer(destroy_time).timeout
		queue_free()
	)
