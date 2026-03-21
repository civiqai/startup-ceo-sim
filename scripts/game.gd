extends Control
## メインゲーム画面

const FundraiseTypes = preload("res://scripts/fundraise_types.gd")

var turn_manager: Node
var log_text: String = ""
var debug_panel: Node = null
var sugoroku_popup: Node
var fundraise_select_popup: Node
var _menu_open := false

@onready var month_label := $VBox/Header/HBox/MonthLabel
@onready var cash_label := $VBox/Header/HBox/CashLabel
@onready var office_view := $VBox/OfficeView
@onready var log_label := $VBox/LogTicker/LogLabel
@onready var action_btn := $VBox/ActionBar/ActionBtn
@onready var action_menu := $VBox/ActionMenu
@onready var buttons := $VBox/ActionMenu/Margin/Buttons
var event_popup: Node


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

	# アクションメニュートグル
	action_btn.pressed.connect(_toggle_action_menu)

	# アクションボタン
	buttons.get_node("DevelopBtn").pressed.connect(func(): _do_action("develop"))
	buttons.get_node("HireBtn").pressed.connect(func(): _do_action("hire"))
	buttons.get_node("MarketingBtn").pressed.connect(func(): _do_action("marketing"))
	buttons.get_node("FundraiseBtn").pressed.connect(func(): _do_action("fundraise"))
	buttons.get_node("TeamCareBtn").pressed.connect(func(): _do_action("team_care"))

	event_popup.popup_closed.connect(_on_event_popup_closed)

	# 双六ポップアップ
	var SugorokuPopupScript = load("res://scripts/sugoroku_popup.gd")
	sugoroku_popup = CanvasLayer.new()
	sugoroku_popup.set_script(SugorokuPopupScript)
	add_child(sugoroku_popup)
	sugoroku_popup.popup_closed.connect(_on_sugoroku_closed)

	# 資金調達タイプ選択ポップアップ
	var FundraiseSelectScript = load("res://scripts/fundraise_select_popup.gd")
	fundraise_select_popup = CanvasLayer.new()
	fundraise_select_popup.set_script(FundraiseSelectScript)
	add_child(fundraise_select_popup)
	fundraise_select_popup.type_selected.connect(_on_fundraise_type_selected)
	fundraise_select_popup.cancelled.connect(_on_fundraise_cancelled)

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
	debug_panel.visible = false
	add_child(debug_panel)
	if debug_panel.has_method("set_game_node"):
		debug_panel.set_game_node(self)
	if debug_panel.has_method("on_turn_ended"):
		turn_manager.turn_ended.connect(debug_panel.on_turn_ended)


func _toggle_action_menu() -> void:
	AudioManager.play_sfx("click")
	_menu_open = not _menu_open
	action_menu.visible = _menu_open
	action_btn.text = "閉じる ▼" if _menu_open else "アクション選択 ▲"


func _do_action(action: String) -> void:
	AudioManager.play_sfx("click")
	# メニューを閉じる
	_menu_open = false
	action_menu.visible = false
	action_btn.text = "アクション選択 ▲"
	action_btn.disabled = true

	if action == "fundraise":
		fundraise_select_popup.show_selection()
	else:
		turn_manager.execute_turn(action)


func _on_action_resolved(result_text: String) -> void:
	_add_log(result_text)


func _on_event_triggered(event_data: Dictionary) -> void:
	AudioManager.play_sfx("notification")
	event_popup.show_event(event_data)


func _on_fundraise_type_selected(type_id: String) -> void:
	sugoroku_popup.show_board(type_id)


func _on_fundraise_cancelled() -> void:
	action_btn.disabled = false


func _on_sugoroku_closed(result_text: String) -> void:
	var type_id = sugoroku_popup._selected_type
	var square_idx = sugoroku_popup._target_position
	var square = FundraiseTypes.get_square(type_id, square_idx)
	var type_data = FundraiseTypes.get_type(type_id)
	var log_msg = "🎲 %s: 【%s】→ %s" % [type_data.get("name", ""), square.get("name", ""), result_text]
	_update_ui()
	turn_manager.execute_turn_with_result(log_msg)


func _on_event_popup_closed(_choice_index: int) -> void:
	var effect_text = event_popup.get_effect_text()
	var event_title = event_popup._event_data.get("title", "")
	if event_title != "":
		_add_log("[color=#FFD966]【イベント】%s[/color]" % event_title)
	if effect_text != "":
		_add_log("[color=#FFD966]→ %s[/color]" % effect_text)
	_update_ui()
	turn_manager.finish_after_event(effect_text)


func _on_event_resolved(_effect_text: String) -> void:
	pass


func _on_turn_ended() -> void:
	AudioManager.play_sfx("turn_advance")
	_add_log("[color=#8899AA]— 月末: 固定費 %d万円 / 売上 %d万円 —[/color]" % [GameState.monthly_cost, GameState.revenue])
	_update_ui()
	action_btn.disabled = false


func _on_game_over(reason: String) -> void:
	_add_log("[color=#E85555]%s[/color]" % reason)
	action_btn.disabled = true
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _on_game_clear(reason: String) -> void:
	_add_log("[color=#55CC70]%s[/color]" % reason)
	action_btn.disabled = true
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _update_ui() -> void:
	month_label.text = "%dヶ月目" % (GameState.month + 1)

	# 資金 - 色を残高で変える
	var cash_color: Color
	if GameState.cash <= 200:
		cash_color = Color(0.90, 0.40, 0.35)
	elif GameState.cash <= 500:
		cash_color = Color(0.90, 0.75, 0.30)
	else:
		cash_color = Color(0.55, 0.85, 0.55)
	cash_label.text = "💰 %d万円" % GameState.cash
	cash_label.add_theme_color_override("font_color", cash_color)

	# オフィスビジュアル更新
	office_view.refresh()

	# 資金調達ボタンのクールダウン表示
	var fundraise_btn = buttons.get_node("FundraiseBtn")
	if GameState.fundraise_cooldown > 0:
		fundraise_btn.text = "💵 資金調達 (あと%dヶ月)" % GameState.fundraise_cooldown
		fundraise_btn.disabled = true
	else:
		fundraise_btn.text = "💵 資金調達"
		fundraise_btn.disabled = false


func _add_log(text: String) -> void:
	log_text += text + "\n"
	log_label.text = log_text
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count())
