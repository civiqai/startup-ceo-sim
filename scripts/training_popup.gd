extends CanvasLayer
## 訓練選択ポップアップ
## メンバー詳細から呼び出し、個人訓練/チームイベントを選択させる

const TrainingDataRef = preload("res://scripts/training_data.gd")
const TeamMemberRef = preload("res://scripts/team_member.gd")

signal training_selected(training_id: String, member_index: int)
signal team_training_selected(training_id: String, speaker_index: int)
signal popup_closed()

var _is_open := false
var _member_data: Dictionary = {}
var _member_index: int = -1
var _current_phase: int = 0
var _current_tab: String = "individual"  # "individual" or "team"

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _info_label: Label
var _tab_individual_btn: Button
var _tab_team_btn: Button
var _scroll: ScrollContainer
var _cards_container: VBoxContainer
var _close_button: Button
var _confirm_overlay: Control

# カラー定数
const COLOR_TITLE_GOLD := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_TEXT_ACCENT := Color(0.55, 0.85, 0.70)
const COLOR_COST_TEXT := Color(0.90, 0.75, 0.30)
const COLOR_UNLOCK_TEXT := Color(0.85, 0.55, 0.40)
const COLOR_CARD_BG := Color(0.12, 0.14, 0.22)
const COLOR_CARD_LOCKED := Color(0.15, 0.15, 0.15)


func _ready() -> void:
	layer = 102  # member_detail(101)より前面
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


## 個人訓練を表示（メンバー詳細から呼ばれる）
func show_for_member(member_data: Dictionary, member_index: int, phase: int) -> void:
	_member_data = member_data
	_member_index = member_index
	_current_phase = phase
	_current_tab = "individual"
	_update_tabs()
	_rebuild_cards()
	_update_info()
	_panel_root.visible = true
	_is_open = true


## チームイベントを表示（game.gdから直接呼ぶ用）
func show_team_events(phase: int) -> void:
	_member_data = {}
	_member_index = -1
	_current_phase = phase
	_current_tab = "team"
	_update_tabs()
	_rebuild_cards()
	_update_info()
	_panel_root.visible = true
	_is_open = true


func _update_info() -> void:
	var member_name: String = _member_data.get("member_name", "")
	if member_name != "":
		_info_label.text = "対象: %s / 資金: %d万円" % [member_name, GameState.cash]
	else:
		_info_label.text = "現在の資金: %d万円" % GameState.cash


func _update_tabs() -> void:
	if _current_tab == "individual":
		KenneyTheme.apply_button_style(_tab_individual_btn, "green")
		KenneyTheme.apply_button_style(_tab_team_btn, "grey")
	else:
		KenneyTheme.apply_button_style(_tab_individual_btn, "grey")
		KenneyTheme.apply_button_style(_tab_team_btn, "green")


func _rebuild_cards() -> void:
	# 既存カードをクリア
	for child in _cards_container.get_children():
		child.queue_free()

	var trainings: Array[Dictionary]
	if _current_tab == "individual":
		trainings = TrainingDataRef.get_individual_trainings(_current_phase)
	else:
		trainings = TrainingDataRef.get_team_trainings(_current_phase)

	# フェーズ未解放の訓練も表示（ロック表示）
	for id in TrainingDataRef.TRAININGS:
		var t: Dictionary = TrainingDataRef.TRAININGS[id].duplicate()
		t["id"] = id
		var target: String = t.get("target", "")
		if target != _current_tab:
			continue
		# 既に解放済みリストに含まれているかチェック
		var found := false
		for avail in trainings:
			if avail.get("id", "") == id:
				found = true
				break
		if not found:
			# フェーズ未解放
			t["_locked"] = true
			trainings.append(t)

	for training_data in trainings:
		var card := _build_card(training_data)
		_cards_container.add_child(card)


func _build_card(training_data: Dictionary) -> PanelContainer:
	var training_id: String = training_data.get("id", "")
	var training_name: String = training_data.get("name", "")
	var icon: String = training_data.get("icon", "")
	var description: String = training_data.get("description", "")
	var cost: int = training_data.get("cost", 0)
	var exp_amount: int = training_data.get("exp", 0)
	var morale: int = training_data.get("morale", 0)
	var absent_turns: int = training_data.get("absent_turns", 0)
	var min_members: int = training_data.get("min_members", 0)
	var is_locked: bool = training_data.get("_locked", false)
	var min_phase: int = training_data.get("min_phase", 0)
	var target: String = training_data.get("target", "individual")

	var can_afford := GameState.cash >= cost
	var has_enough_members := true
	if min_members > 0:
		has_enough_members = TeamManager.members.size() >= min_members

	# カードのスタイル
	var card_style := StyleBoxFlat.new()
	if is_locked:
		card_style.bg_color = COLOR_CARD_LOCKED
	else:
		card_style.bg_color = COLOR_CARD_BG
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.content_margin_left = 14
	card_style.content_margin_top = 12
	card_style.content_margin_right = 14
	card_style.content_margin_bottom = 12

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)

	if is_locked:
		card.modulate = Color(1, 1, 1, 0.4)

	# HBoxContainer: 左に情報、右にボタン
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	# 左側: 訓練情報
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 4)
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)

	# 訓練名 + コスト
	var name_label := Label.new()
	name_label.text = "%s %s（%d万円）" % [icon, training_name, cost]
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(name_label)

	# 説明
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 16)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_vbox.add_child(desc_label)

	# 効果テキスト
	var effect_parts := PackedStringArray()
	effect_parts.append("EXP +%d" % exp_amount)
	if morale != 0:
		if morale > 0:
			effect_parts.append("士気 +%d" % morale)
		else:
			effect_parts.append("士気 %d" % morale)
	if absent_turns > 0:
		effect_parts.append("%dターン不在" % absent_turns)

	var effect_label := Label.new()
	effect_label.text = " / ".join(effect_parts)
	effect_label.add_theme_font_size_override("font_size", 16)
	effect_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	left_vbox.add_child(effect_label)

	# ロック表示
	if is_locked:
		var lock_label := Label.new()
		lock_label.text = "🔒 フェーズ%d以降で解放" % min_phase
		lock_label.add_theme_font_size_override("font_size", 16)
		lock_label.add_theme_color_override("font_color", COLOR_UNLOCK_TEXT)
		left_vbox.add_child(lock_label)
	elif not has_enough_members:
		var need_label := Label.new()
		need_label.text = "⚠ %d人以上必要" % min_members
		need_label.add_theme_font_size_override("font_size", 16)
		need_label.add_theme_color_override("font_color", COLOR_UNLOCK_TEXT)
		left_vbox.add_child(need_label)

	# 右側: ボタン
	if not is_locked:
		var action_btn := Button.new()
		if target == "individual":
			action_btn.text = "送る"
		else:
			action_btn.text = "開催する"
		action_btn.custom_minimum_size = Vector2(100, 48)
		action_btn.add_theme_font_size_override("font_size", 20)

		var disabled := not can_afford or not has_enough_members
		action_btn.disabled = disabled
		if disabled:
			KenneyTheme.apply_button_style(action_btn, "grey")
		else:
			KenneyTheme.apply_button_style(action_btn, "green")
			var tid := training_id
			var tdata := training_data.duplicate()
			action_btn.pressed.connect(func(): _on_action_pressed(tid, tdata))

		hbox.add_child(action_btn)

	return card


func _on_action_pressed(training_id: String, training_data: Dictionary) -> void:
	if not _is_open:
		return
	var target: String = training_data.get("target", "individual")
	if target == "individual":
		_show_confirm_dialog(training_id, training_data)
	else:
		# チームイベント
		if training_id == "company_conference":
			_show_speaker_select(training_id, training_data)
		else:
			_show_team_confirm_dialog(training_id, training_data)


func _show_confirm_dialog(training_id: String, training_data: Dictionary) -> void:
	var member_name: String = _member_data.get("member_name", "メンバー")
	var training_name: String = training_data.get("name", "")
	var cost: int = training_data.get("cost", 0)
	var absent_turns: int = training_data.get("absent_turns", 0)

	var message: String
	if absent_turns > 0:
		message = "%sを%sに送りますか？（%d万円・%dターン不在）" % [member_name, training_name, cost, absent_turns]
	else:
		message = "%sを%sに送りますか？（%d万円）" % [member_name, training_name, cost]

	_show_confirm_popup(message, func():
		_panel_root.visible = false
		_is_open = false
		training_selected.emit(training_id, _member_index)
	)


func _show_team_confirm_dialog(training_id: String, training_data: Dictionary) -> void:
	var training_name: String = training_data.get("name", "")
	var cost: int = training_data.get("cost", 0)
	var message := "%sを開催しますか？（%d万円）" % [training_name, cost]

	_show_confirm_popup(message, func():
		_panel_root.visible = false
		_is_open = false
		team_training_selected.emit(training_id, -1)
	)


func _show_speaker_select(training_id: String, training_data: Dictionary) -> void:
	# 登壇者選択サブ画面
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_confirm_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "🏛️ 登壇者を選択"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.add_theme_constant_override("separation", 8)
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list_vbox)

	for i in range(TeamManager.members.size()):
		var m = TeamManager.members[i]
		if m.is_in_training():
			continue
		var btn := Button.new()
		var skill_label: String = TeamMemberRef.get_skill_label(m.skill_type)
		btn.text = "%s（%s Lv.%d）" % [m.member_name, skill_label, m.skill_level]
		btn.custom_minimum_size = Vector2(0, 48)
		btn.add_theme_font_size_override("font_size", 20)
		KenneyTheme.apply_button_style(btn, "blue")
		var idx := i
		var tid := training_id
		btn.pressed.connect(func():
			_confirm_overlay.queue_free()
			_confirm_overlay = null
			_panel_root.visible = false
			_is_open = false
			team_training_selected.emit(tid, idx)
		)
		list_vbox.add_child(btn)

	# キャンセルボタン
	var cancel_btn := Button.new()
	cancel_btn.text = "戻る"
	cancel_btn.custom_minimum_size = Vector2(0, 48)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	KenneyTheme.apply_button_style(cancel_btn, "grey")
	cancel_btn.pressed.connect(func():
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	)
	vbox.add_child(cancel_btn)


func _show_confirm_popup(message: String, on_confirm: Callable) -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_confirm_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var msg_label := Label.new()
	msg_label.text = message
	msg_label.add_theme_font_size_override("font_size", 22)
	msg_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "はい"
	yes_btn.custom_minimum_size = Vector2(0, 48)
	yes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes_btn.add_theme_font_size_override("font_size", 22)
	KenneyTheme.apply_button_style(yes_btn, "green")
	yes_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_confirm_overlay.queue_free()
		_confirm_overlay = null
		on_confirm.call()
	)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "いいえ"
	no_btn.custom_minimum_size = Vector2(0, 48)
	no_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no_btn.add_theme_font_size_override("font_size", 22)
	KenneyTheme.apply_button_style(no_btn, "grey")
	no_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	)
	btn_row.add_child(no_btn)


func _on_tab_individual_pressed() -> void:
	if _current_tab == "individual":
		return
	AudioManager.play_sfx("click")
	_current_tab = "individual"
	_update_tabs()
	_rebuild_cards()


func _on_tab_team_pressed() -> void:
	if _current_tab == "team":
		return
	AudioManager.play_sfx("click")
	_current_tab = "team"
	_update_tabs()
	_rebuild_cards()


func _on_close_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


## UIをコードで構築（.tscnに依存しない）
func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 暗いオーバーレイ
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.8)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# メインパネル（Kenney UIテクスチャ使用）
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	# メインVBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "🎓 訓練メニュー"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# 情報ラベル
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 22)
	_info_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_label)

	# タブ切替ボタン
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	vbox.add_child(tab_row)

	_tab_individual_btn = Button.new()
	_tab_individual_btn.text = "個人訓練"
	_tab_individual_btn.custom_minimum_size = Vector2(0, 44)
	_tab_individual_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_individual_btn.add_theme_font_size_override("font_size", 20)
	_tab_individual_btn.pressed.connect(_on_tab_individual_pressed)
	tab_row.add_child(_tab_individual_btn)

	_tab_team_btn = Button.new()
	_tab_team_btn.text = "チームイベント"
	_tab_team_btn.custom_minimum_size = Vector2(0, 44)
	_tab_team_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_team_btn.add_theme_font_size_override("font_size", 20)
	_tab_team_btn.pressed.connect(_on_tab_team_pressed)
	tab_row.add_child(_tab_team_btn)

	# スクロールコンテナ（カード一覧）
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 600)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 10)
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_cards_container)

	# 閉じるボタン
	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 52)
	_close_button.add_theme_font_size_override("font_size", 22)
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)
