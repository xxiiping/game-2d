extends Area2D

## 收集品。玩家接触 → 平滑跟随 → 落地收集。死亡则回到原位。

var _player: CharacterBody2D = null
var _attached := false
var _target_offset := Vector2(-40, -40)
var _orig_pos := Vector2.ZERO
var _orig_parent: Node = null


func _ready() -> void:
	_orig_pos = global_position
	_orig_parent = get_parent()
	body_entered.connect(_on_body_entered)


func _on_body_entered(b: Node2D) -> void:
	if _attached:
		return
	if not b is CharacterBody2D:
		return
	_player = b
	_attached = true
	$CollisionShape2D.set_deferred(&"disabled", true)
	reparent(_player)
	position = _target_offset


func _process(_delta: float) -> void:
	if not _attached or not _player:
		return
	position = position.lerp(_target_offset, 0.15)
	if _player.is_on_floor():
		SaveManager.add_collectible()
		queue_free()


func detach() -> void:
	## 玩家死亡时调用：回到原位，恢复碰撞。
	if not _attached:
		return
	_attached = false
	reparent(_orig_parent)
	global_position = _orig_pos
	$CollisionShape2D.set_deferred(&"disabled", false)
	_player = null
