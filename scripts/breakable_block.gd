extends StaticBody2D

## 可破坏方块。玩家冲刺/重坠撞击 → 反弹 → 播放动画 → 销毁。

@export var bounce_speed := 200.0
@export var destroy_time := 0.5

var _dead := false
var _break_sfx: AudioStream = preload("res://assets/audio/breakwall.ogg")


func _ready() -> void:
	var phys: RectangleShape2D = $Shape.shape
	var det: RectangleShape2D = $Detector/CollisionShape2D.shape
	det.size = phys.size + Vector2(12, 12)

	$Detector.body_entered.connect(func(b):
		if _dead or not b is CharacterBody2D: return
		var is_dashing: bool = b.get(&"_dash_active_timer") != null and b._dash_active_timer > 0.0
		var is_heavy: bool = b.get(&"_heavy_state") != null and b._heavy_state == 2
		if not is_dashing and not is_heavy: return
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
		$Visual.play()
		_play_sfx()
		await get_tree().create_timer(destroy_time).timeout
		queue_free()
	)


func _play_sfx() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _break_sfx
	sfx.global_position = global_position
	sfx.volume_db = 4
	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()
