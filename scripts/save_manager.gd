extends Node

## 存档管理器。每30s自动保存最近的复活点到 user://save.json。

const SAVE_PATH := "user://save.json"

var _current_scene := ""
var _save_position := Vector2.ZERO
var _save_timer := 0.0
var _has_save := false
var continue_game := false  ## 玩家 _ready 中读取
var collectible_count := 0
var _collectible_ui: Label = null


func _ready() -> void:
	_has_save = FileAccess.file_exists(SAVE_PATH)
	process_mode = PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	_save_timer += delta
	if _save_timer >= 30.0:
		_save_timer = 0.0
		auto_save()


func auto_save() -> void:
	var player := _find_player()
	if not player:
		return
	var pos := player.global_position
	var cp_pos := _find_nearest_checkpoint(player)
	if cp_pos != Vector2.ZERO:
		pos = cp_pos
	_save_position = pos
	_current_scene = get_tree().current_scene.scene_file_path
	_has_save = true
	_write_save()


func _find_player() -> CharacterBody2D:
	var nodes := get_tree().get_nodes_in_group(&"player")
	return nodes[0] as CharacterBody2D if nodes.size() > 0 else null


func _find_nearest_checkpoint(player: CharacterBody2D) -> Vector2:
	var cps := get_tree().get_nodes_in_group(&"checkpoint")
	var best := Vector2.ZERO
	var best_dist := INF
	for cp in cps:
		var d := player.global_position.distance_squared_to(cp.global_position)
		if d < best_dist:
			best_dist = d
			best = cp.global_position
	return best


func _write_save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	var data := {
		"scene": _current_scene,
		"position": {"x": _save_position.x, "y": _save_position.y},
			"collectibles": collectible_count,
	}
	f.store_string(JSON.stringify(data))


func load_save() -> Dictionary:
	if not _has_save:
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) == OK:
		return json.data
	return {}


func has_save() -> bool:
	return _has_save


func add_collectible() -> void:
	collectible_count += 1
	_update_ui()


func _update_ui() -> void:
	if not _collectible_ui:
		return
	_collectible_ui.text = "★ " + str(collectible_count)


func reset_save() -> void:
	_has_save = false
	_save_position = Vector2.ZERO
