extends Node
## シーン切替を管理するエントリーポイント

var current_scene: Node = null


func _ready() -> void:
	change_scene("res://scenes/title.tscn")


func change_scene(path: String) -> void:
	if current_scene:
		current_scene.queue_free()
	var scene = load(path).instantiate()
	current_scene = scene
	add_child(scene)
