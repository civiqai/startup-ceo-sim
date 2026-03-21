extends Control

@onready var result_title := $VBox/ResultTitle
@onready var stats_label := $VBox/StatsLabel


func _ready() -> void:
	$VBox/RetryButton.pressed.connect(_on_retry)
	$VBox/TitleButton.pressed.connect(_on_title)

	if GameState.valuation >= GameState.IPO_THRESHOLD:
		result_title.text = "🎉 IPO達成！"
	else:
		result_title.text = "💀 倒産…"

	stats_label.text = """経過: %dヶ月
最終資金: %d万円
ユーザー数: %d人
チーム: %d人
プロダクト力: %d
時価総額: %d万円""" % [
		GameState.month,
		GameState.cash,
		GameState.users,
		GameState.team_size,
		GameState.product_power,
		GameState.valuation
	]


func _on_retry() -> void:
	GameState.reset()
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _on_title() -> void:
	get_node("/root/Main").change_scene("res://scenes/title.tscn")
