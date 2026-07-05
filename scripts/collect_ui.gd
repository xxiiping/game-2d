extends CanvasLayer

var _blink_timer := 0.0
var _blink_visible := true


func _ready() -> void:
	SaveManager._collectible_ui = $Label
	var count := 0
	for node in get_tree().get_nodes_in_group(&"collectible"):
		count += 1
	SaveManager.total_collectibles = count
	SaveManager._update_ui()


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody2D
	if not player:
		return
	var has_anchor: bool = player.get(&"_has_anchor")
	$AnchorIcon.visible = has_anchor
	if has_anchor:
		_blink_timer -= delta
		if _blink_timer <= 0.0:
			_blink_timer = 0.3
			_blink_visible = not _blink_visible
		$AnchorIcon.modulate.a = 1.0 if _blink_visible else 0.2
