extends Area2D

## 下落冲刺触发传送锚。触发后传送到最近的复活点。

@export var audio_max_distance := 700.0

var _player: CharacterBody2D = null
var _timer: float = 0.0
var _triggered := false
var _played_countdown := false

@onready var _audio: AudioStreamPlayer2D = $AnchorAudio
@onready var _trigger_sfx: AudioStreamPlayer2D = $TriggerAudio
@onready var _countdown_sfx: AudioStreamPlayer2D = $CountdownAudio


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_audio.stop()


func _process(delta: float) -> void:
	if _triggered:
		_audio.stop()
		_timer -= delta
		if _timer <= 2.0 and not _played_countdown:
			_played_countdown = true
			_countdown_sfx.play()
		if _timer <= 0.0:
			_do_teleport()
		return

	var player := _find_player()
	if player:
		var dist := global_position.distance_to(player.global_position)
		if dist <= audio_max_distance:
			if not _audio.playing:
				_audio.play()
			var t := clampf((audio_max_distance - dist) / (audio_max_distance - 30.0), 0.0, 1.0)
			_audio.volume_db = linear_to_db(0.3 + 0.7 * t)
		else:
			if _audio.playing:
				_audio.stop()


func _find_player() -> CharacterBody2D:
	if _player and is_instance_valid(_player):
		if not _triggered:
			return _player
		return null
	var found := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if found:
		_player = found
	return _player


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body is CharacterBody2D:
		return
	if not body.has_method("is_dashing_downward") or not body.is_dashing_downward():
		return
	_player = body
	_player.freeze_for(4.1)
	_trigger_sfx.play()
	_audio.stop()
	_timer = 4.0
	_triggered = true


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
	_played_countdown = false
