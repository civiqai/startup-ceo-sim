extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start_pressed)


func _on_start_pressed() -> void:
	GameState.reset()
	get_node("/root/Main").change_scene("res://scenes/game.tscn")
