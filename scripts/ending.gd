extends Control

func _ready() -> void:
	$UI/VictorySFX.finished.connect(_on_victory_done)
	$UI/VictorySFX.play()


func _on_victory_done() -> void:
	await get_tree().create_timer(10.0).timeout
	$UI/LonelyBGM.play()
