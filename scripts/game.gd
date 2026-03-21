extends Control
## メインゲーム画面

var turn_manager: Node
var log_text: String = ""

@onready var header := $MarginContainer/VBox/HeaderLabel
@onready var stats_grid := $MarginContainer/VBox/StatsPanel/StatsGrid
@onready var log_label := $MarginContainer/VBox/LogLabel
@onready var buttons := $MarginContainer/VBox/ActionButtons


func _ready() -> void:
	turn_manager = preload("res://scripts/turn_manager.gd").new()
	add_child(turn_manager)

	turn_manager.action_resolved.connect(_on_action_resolved)
	turn_manager.event_occurred.connect(_on_event_occurred)
	turn_manager.turn_ended.connect(_on_turn_ended)

	GameState.game_over.connect(_on_game_over)
	GameState.game_clear.connect(_on_game_clear)

	buttons.get_node("DevelopBtn").pressed.connect(func(): _do_action("develop"))
	buttons.get_node("HireBtn").pressed.connect(func(): _do_action("hire"))
	buttons.get_node("MarketingBtn").pressed.connect(func(): _do_action("marketing"))
	buttons.get_node("FundraiseBtn").pressed.connect(func(): _do_action("fundraise"))
	buttons.get_node("TeamCareBtn").pressed.connect(func(): _do_action("team_care"))

	_add_log("さあ、経営を始めよう！")
	_update_ui()


func _do_action(action: String) -> void:
	_set_buttons_disabled(true)
	turn_manager.execute_turn(action)


func _on_action_resolved(result_text: String) -> void:
	_add_log(result_text)


func _on_event_occurred(title: String, description: String) -> void:
	_add_log("[color=yellow]【%s】%s[/color]" % [title, description])


func _on_turn_ended() -> void:
	_add_log("— 月末: 固定費 %d万円 支払い —" % GameState.monthly_cost)
	_update_ui()
	_set_buttons_disabled(false)


func _on_game_over(reason: String) -> void:
	_add_log("[color=red]%s[/color]" % reason)
	_set_buttons_disabled(true)
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _on_game_clear(reason: String) -> void:
	_add_log("[color=green]%s[/color]" % reason)
	_set_buttons_disabled(true)
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _update_ui() -> void:
	header.text = "%dヶ月目" % (GameState.month + 1)
	stats_grid.get_node("CashValue").text = "%d万円" % GameState.cash
	stats_grid.get_node("ProductValue").text = "%d" % GameState.product_power
	stats_grid.get_node("TeamValue").text = "%d人 (士気%d)" % [GameState.team_size, GameState.team_morale]
	stats_grid.get_node("UsersValue").text = "%d人" % GameState.users
	stats_grid.get_node("ReputationValue").text = "%d" % GameState.reputation
	stats_grid.get_node("ValuationValue").text = "%d万円" % GameState.valuation


func _add_log(text: String) -> void:
	log_text += text + "\n"
	log_label.text = log_text
	# 自動スクロール
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count())


func _set_buttons_disabled(disabled: bool) -> void:
	for btn in buttons.get_children():
		btn.disabled = disabled
