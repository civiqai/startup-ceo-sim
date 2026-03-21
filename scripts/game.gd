extends Control
## メインゲーム画面

var turn_manager: Node
var log_text: String = ""
var debug_panel: Node = null

@onready var header := $MarginContainer/VBox/HeaderLabel
@onready var stats_grid := $MarginContainer/VBox/StatsPanel/StatsGrid
@onready var log_label := $MarginContainer/VBox/LogLabel
@onready var buttons := $MarginContainer/VBox/ActionButtons
var event_popup: Node

# ステータス値の色テーマ
const COLOR_CASH_NORMAL := Color(0.55, 0.85, 0.55, 1.0)
const COLOR_CASH_LOW := Color(0.90, 0.40, 0.35, 1.0)
const COLOR_CASH_WARNING := Color(0.90, 0.75, 0.30, 1.0)
const COLOR_PRODUCT := Color(0.55, 0.72, 0.95, 1.0)
const COLOR_TEAM_NORMAL := Color(0.90, 0.68, 0.38, 1.0)
const COLOR_TEAM_LOW_MORALE := Color(0.90, 0.40, 0.35, 1.0)
const COLOR_USERS := Color(0.80, 0.60, 0.90, 1.0)
const COLOR_REPUTATION := Color(0.90, 0.80, 0.40, 1.0)
const COLOR_VALUATION := Color(0.50, 0.85, 0.80, 1.0)


func _ready() -> void:
	turn_manager = preload("res://scripts/turn_manager.gd").new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)

	# EventPopupをCanvasLayerとしてコードから生成（最前面保証）
	var EventPopupScript = load("res://scripts/event_popup.gd")
	event_popup = CanvasLayer.new()
	event_popup.set_script(EventPopupScript)
	add_child(event_popup)

	turn_manager.action_resolved.connect(_on_action_resolved)
	turn_manager.event_triggered.connect(_on_event_triggered)
	turn_manager.event_resolved.connect(_on_event_resolved)
	turn_manager.turn_ended.connect(_on_turn_ended)

	GameState.game_over.connect(_on_game_over)
	GameState.game_clear.connect(_on_game_clear)

	buttons.get_node("DevelopBtn").pressed.connect(func(): _do_action("develop"))
	buttons.get_node("HireBtn").pressed.connect(func(): _do_action("hire"))
	buttons.get_node("MarketingBtn").pressed.connect(func(): _do_action("marketing"))
	buttons.get_node("FundraiseBtn").pressed.connect(func(): _do_action("fundraise"))
	buttons.get_node("TeamCareBtn").pressed.connect(func(): _do_action("team_care"))

	event_popup.popup_closed.connect(_on_event_popup_closed)

	_add_log("さあ、経営を始めよう！")
	_update_ui()
	AudioManager.play_bgm("game")

	# デバッグパネルを追加
	_setup_debug_panel()


func _setup_debug_panel() -> void:
	var panel_scene = load("res://scenes/debug_panel.tscn")
	if not panel_scene:
		return
	debug_panel = panel_scene.instantiate()
	if not debug_panel:
		return
	debug_panel.visible = false  # デフォルト非表示
	add_child(debug_panel)
	if debug_panel.has_method("set_game_node"):
		debug_panel.set_game_node(self)
	if debug_panel.has_method("on_turn_ended"):
		turn_manager.turn_ended.connect(debug_panel.on_turn_ended)


func _do_action(action: String) -> void:
	AudioManager.play_sfx("click")
	_set_buttons_disabled(true)
	turn_manager.execute_turn(action)


func _on_action_resolved(result_text: String) -> void:
	_add_log(result_text)


func _on_event_triggered(event_data: Dictionary) -> void:
	AudioManager.play_sfx("notification")
	event_popup.show_event(event_data)


func _on_event_popup_closed(_choice_index: int) -> void:
	# ポップアップが閉じられたら、効果テキストをログに追加してターンを完了
	var effect_text = event_popup.get_effect_text()
	var event_title = event_popup._event_data.get("title", "")
	if event_title != "":
		_add_log("[color=#FFD966]【イベント】%s[/color]" % event_title)
	if effect_text != "":
		_add_log("[color=#FFD966]→ %s[/color]" % effect_text)
	_update_ui()
	turn_manager.finish_after_event(effect_text)


func _on_event_resolved(_effect_text: String) -> void:
	# event_resolved は _on_event_popup_closed 内で直接ログ追加しているため
	# 追加のログは不要（将来の拡張用シグナル）
	pass


func _on_turn_ended() -> void:
	AudioManager.play_sfx("turn_advance")
	_add_log("[color=#8899AA]— 月末: 固定費 %d万円 支払い —[/color]" % GameState.monthly_cost)
	_update_ui()
	_set_buttons_disabled(false)


func _on_game_over(reason: String) -> void:
	_add_log("[color=#E85555]%s[/color]" % reason)
	_set_buttons_disabled(true)
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _on_game_clear(reason: String) -> void:
	_add_log("[color=#55CC70]%s[/color]" % reason)
	_set_buttons_disabled(true)
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _update_ui() -> void:
	header.text = "%dヶ月目" % (GameState.month + 1)

	# 資金 - 残高に応じて色を変える
	var cash_value := stats_grid.get_node("CashValue")
	var cash_label := stats_grid.get_node("CashLabel")
	cash_value.text = "%d万円" % GameState.cash
	var cash_color: Color
	if GameState.cash <= 200:
		cash_color = COLOR_CASH_LOW
	elif GameState.cash <= 500:
		cash_color = COLOR_CASH_WARNING
	else:
		cash_color = COLOR_CASH_NORMAL
	cash_value.add_theme_color_override("font_color", cash_color)
	cash_label.add_theme_color_override("font_color", cash_color.darkened(0.2))

	# プロダクト力
	stats_grid.get_node("ProductValue").text = "%d" % GameState.product_power

	# チーム - 士気が低いとき色を変える
	var team_value := stats_grid.get_node("TeamValue")
	var team_label := stats_grid.get_node("TeamLabel")
	team_value.text = "%d人 (士気%d)" % [GameState.team_size, GameState.team_morale]
	var team_color: Color
	if GameState.team_morale <= 30:
		team_color = COLOR_TEAM_LOW_MORALE
	else:
		team_color = COLOR_TEAM_NORMAL
	team_value.add_theme_color_override("font_color", team_color)
	team_label.add_theme_color_override("font_color", team_color.darkened(0.2))

	# ユーザー数
	stats_grid.get_node("UsersValue").text = "%d人" % GameState.users

	# 評判
	stats_grid.get_node("ReputationValue").text = "%d" % GameState.reputation

	# 時価総額
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
