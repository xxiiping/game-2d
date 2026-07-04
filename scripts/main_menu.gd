extends Control

## 主菜单。

func _ready() -> void:
	$VBox/Continue.disabled = not SaveManager.has_save()


func _on_start() -> void:
	SaveManager.reset_save()
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")


func _on_continue() -> void:
	SaveManager.continue_game = true
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")


func _on_exit() -> void:
	get_tree().quit()
