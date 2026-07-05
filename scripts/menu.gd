extends Node2D

func _ready() -> void:
	$continue.disabled = not SaveManager.has_save()
	$play.grab_focus()


func _on_play_pressed() -> void:
	SaveManager.reset_save()
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")


func _on_continue_pressed() -> void:
	SaveManager.continue_game = true
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_settings_pressed() -> void:
	pass
