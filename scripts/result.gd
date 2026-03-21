extends Control

@onready var result_icon := $VBox/ResultIcon
@onready var result_title := $VBox/ResultTitle
@onready var stats_label := $VBox/StatsLabel


func _ready() -> void:
	$VBox/RetryButton.pressed.connect(_on_retry)
	$VBox/TitleButton.pressed.connect(_on_title)

	if GameState.valuation >= GameState.IPO_THRESHOLD:
		_show_victory()
		AudioManager.play_bgm("win")
	else:
		_show_defeat()
		AudioManager.play_bgm("lose")

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


func _show_victory() -> void:
	result_icon.text = "🎉"
	result_title.text = "IPO達成！"
	result_title.add_theme_color_override("font_color", Color(0.30, 0.85, 0.45, 1.0))
	stats_label.add_theme_color_override("font_color", Color(0.70, 0.90, 0.75, 1.0))


func _show_defeat() -> void:
	result_icon.text = "💀"
	result_title.text = "倒産…"
	result_title.add_theme_color_override("font_color", Color(0.90, 0.30, 0.30, 1.0))
	stats_label.add_theme_color_override("font_color", Color(0.90, 0.70, 0.65, 1.0))


func _on_retry() -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _on_title() -> void:
	AudioManager.play_sfx("click")
	get_node("/root/Main").change_scene("res://scenes/title.tscn")
