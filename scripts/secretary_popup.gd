extends CanvasLayer
## 秘書・あかりの対話ポップアップ
## 画面下部にダイアログボックスとして表示される

signal dialogue_finished
signal tutorial_skipped

const SecretaryData = preload("res://scripts/secretary_data.gd")

# スタイルカラー
const COLOR_OVERLAY := Color(0, 0, 0, 0.4)
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16)
const COLOR_PANEL_BORDER := Color(0.25, 0.35, 0.55)
const COLOR_NAME := Color(0.40, 0.75, 1.0)
const COLOR_TEXT := Color(0.92, 0.93, 0.96)
const COLOR_BTN_BG := Color(0.18, 0.25, 0.42)
const COLOR_BTN_HOVER := Color(0.22, 0.30, 0.50)
const COLOR_SKIP_TEXT := Color(0.55, 0.58, 0.65)

# タイピング速度（文字/秒）
const TYPING_SPEED := 30.0

# 内部状態
var _is_open := false
var _messages: Array = []
var _current_index := 0
var _is_sequence := false
var _tutorial_completed := false
var _shown_advices: Array = []  # 表示済みのアドバイスID
var _month_with_no_users := 0  # ユーザー0が続いた月数
var _advice_cooldowns: Dictionary = {}  # advice_id -> remaining_cooldown（状況別アドバイス用）
var _completed_tutorials: Array[String] = []  # 完了済みチュートリアルステップID

# タイピングエフェクト用
var _full_text := ""
var _visible_chars := 0
var _typing_active := false
var _typing_timer: Timer

# UIノード参照
var _panel_root: Control
var _overlay: ColorRect
var _dialogue_panel: PanelContainer
var _icon_label: Label
var _name_label: Label
var _text_label: Label
var _next_btn: Button
var _skip_btn: Button


func _ready() -> void:
	layer = 105
	_load_state()
	_build_ui()
	_panel_root.visible = false

	# タイピング用タイマー
	_typing_timer = Timer.new()
	_typing_timer.wait_time = 1.0 / TYPING_SPEED
	_typing_timer.timeout.connect(_on_typing_tick)
	add_child(_typing_timer)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	# 下のノードに入力を流さない
	get_viewport().set_input_as_handled()


## チュートリアルが完了済みかどうか
func is_tutorial_completed() -> bool:
	return _tutorial_completed


## メッセージシーケンスを表示（チュートリアル等）
func show_sequence(messages: Array) -> void:
	if messages.is_empty():
		return
	_messages = messages
	_current_index = 0
	_is_sequence = true
	_is_open = true
	_skip_btn.visible = true
	_panel_root.visible = true
	_show_current_message()


## 単一メッセージを表示（状況アドバイス等）
func show_single(message: Dictionary) -> void:
	_messages = [message]
	_current_index = 0
	_is_sequence = false
	_is_open = true
	_skip_btn.visible = false
	_panel_root.visible = true
	_show_current_message()


## ゲーム状態に応じたアドバイスをチェックし、該当すれば表示
## 戻り値: アドバイスを表示した場合 true
func check_and_show_advice(gs) -> bool:
	if not _tutorial_completed:
		return false

	# ユーザー0月数の追跡
	if gs.users == 0:
		_month_with_no_users += 1
	else:
		_month_with_no_users = 0

	var advices = SecretaryData.get_contextual_advices()

	# 優先度降順でソート
	advices.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))

	for advice in advices:
		var advice_id: String = advice.get("id", "")
		# 既に表示済みならスキップ
		if advice_id in _shown_advices:
			continue
		# 条件チェック
		var condition: String = advice.get("condition", "")
		if SecretaryData.check_condition(condition, gs, _month_with_no_users):
			_shown_advices.append(advice_id)
			_save_state()
			show_single(advice)
			return true

	return false


## 複数メッセージを秘書ダイアログとして表示（テキスト文字列の配列）
func show_dialogue(texts: Array) -> void:
	if texts.is_empty():
		return
	var messages: Array = []
	for t in texts:
		messages.append({"icon": "👩‍💼", "name": "秘書・あかり", "text": t})
	if messages.size() == 1:
		show_single(messages[0])
	else:
		show_sequence(messages)


## イベント後にコメンタリーを表示
func show_event_commentary(event_id: String) -> bool:
	if not SecretaryData.EVENT_COMMENTARY.has(event_id):
		return false
	var commentary = SecretaryData.EVENT_COMMENTARY[event_id]
	show_dialogue([commentary["text"]])
	return true


## 状況別アドバイスをチェックし、該当すれば表示（クールダウン付き）
func check_situation_advice(gs) -> bool:
	if not _tutorial_completed:
		return false

	# ユーザー0月数の追跡（既存ロジック維持）
	if gs.users == 0:
		_month_with_no_users += 1
	else:
		_month_with_no_users = 0

	# クールダウン減少
	for key in _advice_cooldowns.keys():
		_advice_cooldowns[key] = maxi(_advice_cooldowns[key] - 1, 0)

	var best_advice = null
	var best_priority := 0

	for advice in SecretaryData.SITUATION_ADVICE:
		var id = advice["id"]
		if _advice_cooldowns.get(id, 0) > 0:
			continue
		if _check_advice_condition(id, gs) and advice["priority"] > best_priority:
			best_advice = advice
			best_priority = advice["priority"]

	if best_advice:
		_advice_cooldowns[best_advice["id"]] = best_advice["cooldown"]
		show_dialogue([best_advice["text"]])
		return true

	# フォールバック: 既存のコンテキストアドバイスもチェック
	return check_and_show_advice(gs)


func _check_advice_condition(id: String, gs) -> bool:
	match id:
		"low_cash":
			return gs.monthly_cost > 0 and gs.cash / gs.monthly_cost <= 3
		"no_product":
			# チュートリアル完了後のみ発火（チュートリアル中はガイドで処理）
			if gs.tutorial_month >= 0:
				return false
			var pm = get_node_or_null("/root/Main/Game/ProductManager")
			return pm != null and pm.selected_product_type == "" and gs.month >= 2
		"high_morale":
			return gs.team_morale >= 80
		"low_morale":
			return gs.team_morale <= 30
		"no_revenue":
			return gs.month >= 6 and gs.revenue <= 0
		"team_growing":
			return gs.team_size >= 5
		"high_debt":
			var pm = get_node_or_null("/root/Main/Game/ProductManager")
			return pm != null and pm.tech_debt >= 60
		"equity_warning":
			return gs.equity_share <= 70.0
		"first_hire_hint":
			# チュートリアル中はガイドで処理
			if gs.tutorial_month >= 0:
				return false
			return gs.month >= 2 and gs.team_size <= 1
		"marketing_unlocked":
			var phase_mgr = get_node_or_null("/root/Main/Game/PhaseManager")
			return phase_mgr != null and phase_mgr.current_phase == 1
	return false


## チュートリアルトリガーに一致するステップのforced_actionを返す
## 戻り値: forced_action文字列（空なら全解放、nullなら該当なし）
func get_tutorial_forced_action(trigger: String):
	for step in SecretaryData.TUTORIAL_STEPS:
		if step["id"] in _completed_tutorials:
			continue
		if step["trigger"] == trigger:
			return step.get("forced_action", "")
	return null


## チュートリアルトリガーに一致するステップがあれば表示
func check_tutorial(gs, trigger: String) -> bool:
	for step in SecretaryData.TUTORIAL_STEPS:
		if step["id"] in _completed_tutorials:
			continue
		if step["trigger"] == trigger:
			_completed_tutorials.append(step["id"])
			show_dialogue(step["messages"])
			return true
	return false


## ニューゲーム時にチュートリアル状態をリセット
func reset() -> void:
	_tutorial_completed = false
	_shown_advices = []
	_month_with_no_users = 0
	_advice_cooldowns = {}
	_completed_tutorials = []
	_save_state()


## チュートリアルを開始（初回のみ）
func start_tutorial_if_needed() -> void:
	if _tutorial_completed:
		return
	var sequence := SecretaryData.get_tutorial_sequence()
	show_sequence(sequence)


# --- 内部メソッド ---

func _show_current_message() -> void:
	if _current_index >= _messages.size():
		_close()
		return

	var msg: Dictionary = _messages[_current_index]
	_icon_label.text = msg.get("icon", "👩‍💼")
	_name_label.text = msg.get("name", "秘書・あかり")
	_full_text = msg.get("text", "")
	_visible_chars = 0
	_text_label.text = ""
	_typing_active = true
	_typing_timer.start()

	# ボタンテキスト更新
	if _is_sequence and _current_index < _messages.size() - 1:
		_next_btn.text = "次へ ▶"
	else:
		_next_btn.text = "閉じる"


func _on_typing_tick() -> void:
	if not _typing_active:
		_typing_timer.stop()
		return
	_visible_chars += 1
	if _visible_chars >= _full_text.length():
		_visible_chars = _full_text.length()
		_typing_active = false
		_typing_timer.stop()
	_text_label.text = _full_text.substr(0, _visible_chars)


func _complete_typing() -> void:
	_typing_active = false
	_typing_timer.stop()
	_visible_chars = _full_text.length()
	_text_label.text = _full_text


func _on_next_pressed() -> void:
	# タイピング中ならまず全文表示
	if _typing_active:
		_complete_typing()
		return

	_current_index += 1
	if _current_index >= _messages.size():
		_close()
	else:
		_show_current_message()


func _on_panel_tapped(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# タイピング中ならタップで全文表示
		if _typing_active:
			_complete_typing()


func _on_skip_pressed() -> void:
	_typing_active = false
	_typing_timer.stop()
	_panel_root.visible = false
	_is_open = false
	_messages = []
	_current_index = 0
	# チュートリアルスキップ時は完了扱い
	_tutorial_completed = true
	GameState.tutorial_month = -1
	_save_state()
	tutorial_skipped.emit()
	dialogue_finished.emit()


func _close() -> void:
	_typing_active = false
	_typing_timer.stop()
	_panel_root.visible = false
	_is_open = false

	# シーケンス完了時（チュートリアル完了判定）
	if _is_sequence:
		# チュートリアルガイドモード中は tutorial_month で管理
		if GameState.tutorial_month < 0:
			_tutorial_completed = true
		_save_state()

	_messages = []
	_current_index = 0
	dialogue_finished.emit()


# --- 永続化 ---

func _save_state() -> void:
	var data := {
		"tutorial_completed": _tutorial_completed,
		"shown_advices": _shown_advices,
	}
	var file := FileAccess.open("user://secretary_state.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func _load_state() -> void:
	if not FileAccess.file_exists("user://secretary_state.json"):
		return
	var file := FileAccess.open("user://secretary_state.json", FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		return
	var data = json.data
	if data is Dictionary:
		_tutorial_completed = data.get("tutorial_completed", false)
		var advices = data.get("shown_advices", [])
		_shown_advices = []
		for a in advices:
			_shown_advices.append(str(a))


# --- UI構築 ---

func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 半透明オーバーレイ（他ポップアップより薄め）
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = COLOR_OVERLAY
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_overlay)

	# 下部に配置するダイアログパネル（Kenney UIテクスチャ使用）
	_dialogue_panel = PanelContainer.new()
	KenneyTheme.apply_panel_style(_dialogue_panel, "popup")
	# 画面下部に固定: full width, 200px height
	_dialogue_panel.anchor_left = 0.0
	_dialogue_panel.anchor_right = 1.0
	_dialogue_panel.anchor_top = 1.0
	_dialogue_panel.anchor_bottom = 1.0
	_dialogue_panel.offset_left = 0
	_dialogue_panel.offset_right = 0
	_dialogue_panel.offset_top = -200
	_dialogue_panel.offset_bottom = 0
	_dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dialogue_panel.gui_input.connect(_on_panel_tapped)
	_panel_root.add_child(_dialogue_panel)

	# パネル内レイアウト: HBox（アイコン列 + テキスト列）
	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 16)
	_dialogue_panel.add_child(main_hbox)

	# --- 左側: アイコン + 名前 ---
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.custom_minimum_size = Vector2(64, 0)
	left_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_hbox.add_child(left_vbox)

	_icon_label = Label.new()
	_icon_label.text = "👩‍💼"
	_icon_label.add_theme_font_size_override("font_size", 48)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(_icon_label)

	_name_label = Label.new()
	_name_label.text = "秘書・あかり"
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", COLOR_NAME)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(_name_label)

	# --- 右側: テキスト + ボタン ---
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 10)
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(right_vbox)

	# テキストラベル
	_text_label = Label.new()
	_text_label.text = ""
	_text_label.add_theme_font_size_override("font_size", 22)
	_text_label.add_theme_color_override("font_color", COLOR_TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	right_vbox.add_child(_text_label)

	# ボタン行: 右寄せ
	var btn_hbox := HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	btn_hbox.add_theme_constant_override("separation", 12)
	right_vbox.add_child(btn_hbox)

	# 「次へ」ボタン（Kenney UIスタイル）
	_next_btn = Button.new()
	_next_btn.text = "次へ ▶"
	_next_btn.add_theme_font_size_override("font_size", 20)
	_next_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_next_btn, "blue")
	_next_btn.pressed.connect(_on_next_pressed)
	btn_hbox.add_child(_next_btn)

	# 「スキップ」ボタン（チュートリアル用、右上に配置）
	_skip_btn = Button.new()
	_skip_btn.text = "スキップ"
	_skip_btn.add_theme_font_size_override("font_size", 16)
	_skip_btn.add_theme_color_override("font_color", COLOR_SKIP_TEXT)
	_skip_btn.flat = true
	_skip_btn.visible = false
	_skip_btn.pressed.connect(_on_skip_pressed)
	# 右上に絶対配置
	_skip_btn.anchor_left = 1.0
	_skip_btn.anchor_right = 1.0
	_skip_btn.anchor_top = 0.0
	_skip_btn.anchor_bottom = 0.0
	_skip_btn.offset_left = -100
	_skip_btn.offset_right = -8
	_skip_btn.offset_top = 8
	_skip_btn.offset_bottom = 40
	_panel_root.add_child(_skip_btn)
