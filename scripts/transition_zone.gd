extends Area2D

## 传送锚。触发后传送到最近的复活点。

var _player: CharacterBody2D = null
var _timer: float = 0.0
var _triggered := false

var _meows := [
	preload("res://assets/audio/Meow.ogg"),
	preload("res://assets/audio/Meow-01.ogg"),
	preload("res://assets/audio/Meow-02.ogg"),
	preload("res://assets/audio/Meow-03.ogg"),
]


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if _triggered:
		_timer -= delta
		if _timer <= 0.0:
			_do_teleport()
		return


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("is_dashing_downward") or not body.is_dashing_downward():
		return
	_player = body
	_player.freeze_for(1.1)
	# 随机播放喵叫
	_play_random_meow()
	_timer = 1.0
	_triggered = true


func _play_random_meow() -> void:
	var sfx := AudioStreamPlayer2D.new()
	sfx.stream = _meows[randi() % _meows.size()]
	sfx.global_position = global_position
	get_tree().current_scene.add_child(sfx)
	sfx.finished.connect(sfx.queue_free)
	sfx.play()


func _do_teleport() -> void:
	var best := Vector2.ZERO
	var best_dist := INF
	for cp in get_tree().get_nodes_in_group(&"checkpoint"):
		var d := _player.global_position.distance_squared_to(cp.global_position)
		if d < best_dist:
			best_dist = d
			best = cp.global_position
	if best != Vector2.ZERO:
		_player.global_position = best
	_player.frozen = false
	_triggered = false
