extends CanvasLayer

func _ready() -> void:
	SaveManager._collectible_ui = $Label
	SaveManager._update_ui()
