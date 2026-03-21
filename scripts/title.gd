extends Control

func _ready() -> void:
	$VBox/StartButton.pressed.connect(_on_start_pressed)
	AudioManager.play_bgm("title")


func _on_start_pressed() -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	get_node("/root/Main").change_scene("res://scenes/game.tscn")
