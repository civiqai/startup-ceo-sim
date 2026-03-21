extends CanvasLayer
## セーブ/ロード ポップアップUI
## CanvasLayerで最前面に表示し、スロット選択でセーブ/ロードを行う

signal save_completed(slot: String)
signal load_completed(slot: String)
signal popup_closed

var _is_open := false
var _mode := "save"  # "save" or "load"
var _panel_root: Control
var _overlay: ColorRect
var _cards_container: VBoxContainer
var _cancel_button: Button
var _title_label: Label

# 上書き確認用
var _confirm_overlay: Control
var _confirm_slot := ""

# スタイル定数
const COLOR_PANEL_BG := Color(0.10, 0.12, 0.18)
const COLOR_PANEL_BORDER := Color(0.25, 0.40, 0.65)
const COLOR_TITLE_SAVE := Color(1.0, 0.85, 0.40)
const COLOR_TITLE_LOAD := Color(0.55, 0.85, 0.70)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_TEXT_DIM := Color(0.40, 0.42, 0.48)
const COLOR_CARD_EMPTY := Color(0.13, 0.14, 0.18)
const COLOR_CARD_FILLED := Color(0.12, 0.18, 0.28)
const COLOR_CARD_AUTO := Color(0.18, 0.15, 0.12)
const COLOR_SLOT_LABEL := Color(0.70, 0.80, 1.0)
const COLOR_AUTO_LABEL := Color(0.90, 0.75, 0.40)

const SLOT_NAMES := {
	"slot_1": "スロット 1",
	"slot_2": "スロット 2",
	"slot_3": "スロット 3",
	"auto_save": "オートセーブ",
}


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


## ポップアップを表示する
## mode: "save" or "load"
func show_popup(mode: String) -> void:
	_mode = mode
	if _mode == "save":
		_title_label.text = "💾 セーブ"
		_title_label.add_theme_color_override("font_color", COLOR_TITLE_SAVE)
	else:
		_title_label.text = "📂 ロード"
		_title_label.add_theme_color_override("font_color", COLOR_TITLE_LOAD)
	_rebuild_cards()
	_panel_root.visible = true
	_is_open = true


## カード一覧を再構築
func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()

	var slots = SaveManager.get_all_slots()
	for slot in slots:
		var card := _build_slot_card(slot)
		_cards_container.add_child(card)


## スロットカードを構築
func _build_slot_card(slot: String) -> PanelContainer:
	var info = SaveManager.get_save_info(slot)
	var has_data = not info.is_empty()
	var is_auto = (slot == "auto_save")

	# セーブモードではオートセーブは読み取り専用
	var is_disabled := (_mode == "save" and is_auto) or (_mode == "load" and not has_data)

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	if is_auto:
		card_style.bg_color = COLOR_CARD_AUTO if has_data else COLOR_CARD_EMPTY
	elif has_data:
		card_style.bg_color = COLOR_CARD_FILLED
	else:
		card_style.bg_color = COLOR_CARD_EMPTY
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	if is_auto:
		card_style.border_color = COLOR_AUTO_LABEL if has_data else Color(0.30, 0.28, 0.25)
	elif has_data:
		card_style.border_color = Color(0.30, 0.50, 0.80)
	else:
		card_style.border_color = Color(0.25, 0.27, 0.32)
	card_style.content_margin_left = 16
	card_style.content_margin_top = 14
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 14

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(0, 90)

	if is_disabled:
		card.modulate = Color(1, 1, 1, 0.4)

	# コンテンツ
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	# スロット名
	var slot_label := Label.new()
	slot_label.text = SLOT_NAMES.get(slot, slot)
	slot_label.add_theme_font_size_override("font_size", 24)
	if is_auto:
		slot_label.add_theme_color_override("font_color", COLOR_AUTO_LABEL)
	else:
		slot_label.add_theme_color_override("font_color", COLOR_SLOT_LABEL)
	vbox.add_child(slot_label)

	if has_data:
		# データ情報行
		var info_hbox := HBoxContainer.new()
		info_hbox.add_theme_constant_override("separation", 20)
		vbox.add_child(info_hbox)

		var month_label := Label.new()
		month_label.text = "📅 %dヶ月目" % info["month"]
		month_label.add_theme_font_size_override("font_size", 20)
		month_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		info_hbox.add_child(month_label)

		var cash_label := Label.new()
		cash_label.text = "💰 %d万円" % info["cash"]
		cash_label.add_theme_font_size_override("font_size", 20)
		cash_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		info_hbox.add_child(cash_label)

		var team_label := Label.new()
		team_label.text = "👥 %d人" % info["team_size"]
		team_label.add_theme_font_size_override("font_size", 20)
		team_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		info_hbox.add_child(team_label)

		# タイムスタンプ
		var ts_label := Label.new()
		var ts: String = info.get("timestamp", "")
		# "2026-03-21T12:00:00" → "2026/03/21 12:00" に整形
		if ts.length() >= 16:
			ts = ts.left(10).replace("-", "/") + " " + ts.substr(11, 5)
		ts_label.text = ts
		ts_label.add_theme_font_size_override("font_size", 18)
		ts_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		vbox.add_child(ts_label)
	else:
		var empty_label := Label.new()
		empty_label.text = "空きスロット"
		empty_label.add_theme_font_size_override("font_size", 20)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		vbox.add_child(empty_label)

	# インタラクション
	if not is_disabled:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_slot_pressed(slot)
		)
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return card


## スロットがタップされたときの処理
func _on_slot_pressed(slot: String) -> void:
	if not _is_open:
		return

	if _mode == "save":
		# 既存データがある場合は上書き確認
		if SaveManager.has_save(slot):
			_show_confirm(slot)
		else:
			_do_save(slot)
	else:
		_do_load(slot)


## セーブ実行
func _do_save(slot: String) -> void:
	var success := SaveManager.save_game(slot)
	if success:
		_close()
		save_completed.emit(slot)


## ロード実行
func _do_load(slot: String) -> void:
	var success := SaveManager.load_game(slot)
	if success:
		_close()
		load_completed.emit(slot)


## 上書き確認ダイアログを表示
func _show_confirm(slot: String) -> void:
	_confirm_slot = slot
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_confirm_overlay)

	# 暗いオーバーレイ
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(bg)

	# 確認パネル
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.13, 0.20)
	confirm_style.border_width_left = 2
	confirm_style.border_width_top = 2
	confirm_style.border_width_right = 2
	confirm_style.border_width_bottom = 2
	confirm_style.border_color = Color(0.85, 0.55, 0.30)
	confirm_style.corner_radius_top_left = 12
	confirm_style.corner_radius_top_right = 12
	confirm_style.corner_radius_bottom_left = 12
	confirm_style.corner_radius_bottom_right = 12
	confirm_style.content_margin_left = 30
	confirm_style.content_margin_top = 24
	confirm_style.content_margin_right = 30
	confirm_style.content_margin_bottom = 24

	var confirm_panel := PanelContainer.new()
	confirm_panel.custom_minimum_size = Vector2(500, 0)
	confirm_panel.add_theme_stylebox_override("panel", confirm_style)
	center.add_child(confirm_panel)

	var cvbox := VBoxContainer.new()
	cvbox.add_theme_constant_override("separation", 20)
	confirm_panel.add_child(cvbox)

	var msg := Label.new()
	msg.text = "上書きしますか？"
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cvbox.add_child(msg)

	var slot_info = SaveManager.get_save_info(slot)
	if not slot_info.is_empty():
		var detail := Label.new()
		detail.text = "%s: %dヶ月目 / 💰%d万円" % [
			SLOT_NAMES.get(slot, slot),
			slot_info.get("month", 0),
			slot_info.get("cash", 0),
		]
		detail.add_theme_font_size_override("font_size", 20)
		detail.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cvbox.add_child(detail)

	# ボタン行
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 16)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cvbox.add_child(btn_hbox)

	# キャンセルボタン
	var cancel_btn_style := StyleBoxFlat.new()
	cancel_btn_style.bg_color = Color(0.20, 0.22, 0.28)
	cancel_btn_style.corner_radius_top_left = 8
	cancel_btn_style.corner_radius_top_right = 8
	cancel_btn_style.corner_radius_bottom_left = 8
	cancel_btn_style.corner_radius_bottom_right = 8
	cancel_btn_style.content_margin_left = 20
	cancel_btn_style.content_margin_top = 10
	cancel_btn_style.content_margin_right = 20
	cancel_btn_style.content_margin_bottom = 10

	var no_btn := Button.new()
	no_btn.text = "やめる"
	no_btn.add_theme_font_size_override("font_size", 22)
	no_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	no_btn.add_theme_stylebox_override("normal", cancel_btn_style)
	no_btn.add_theme_stylebox_override("hover", cancel_btn_style)
	no_btn.add_theme_stylebox_override("pressed", cancel_btn_style)
	no_btn.pressed.connect(func():
		if _confirm_overlay:
			_confirm_overlay.queue_free()
			_confirm_overlay = null
	)
	btn_hbox.add_child(no_btn)

	# 上書きボタン
	var overwrite_btn_style := StyleBoxFlat.new()
	overwrite_btn_style.bg_color = Color(0.80, 0.45, 0.25)
	overwrite_btn_style.corner_radius_top_left = 8
	overwrite_btn_style.corner_radius_top_right = 8
	overwrite_btn_style.corner_radius_bottom_left = 8
	overwrite_btn_style.corner_radius_bottom_right = 8
	overwrite_btn_style.content_margin_left = 20
	overwrite_btn_style.content_margin_top = 10
	overwrite_btn_style.content_margin_right = 20
	overwrite_btn_style.content_margin_bottom = 10

	var yes_btn := Button.new()
	yes_btn.text = "上書きする"
	yes_btn.add_theme_font_size_override("font_size", 22)
	yes_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	yes_btn.add_theme_stylebox_override("normal", overwrite_btn_style)
	yes_btn.add_theme_stylebox_override("hover", overwrite_btn_style)
	yes_btn.add_theme_stylebox_override("pressed", overwrite_btn_style)
	yes_btn.pressed.connect(func():
		if _confirm_overlay:
			_confirm_overlay.queue_free()
			_confirm_overlay = null
		_do_save(_confirm_slot)
	)
	btn_hbox.add_child(yes_btn)


## ポップアップを閉じる
func _close() -> void:
	if _confirm_overlay:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


func _on_cancel_pressed() -> void:
	if not _is_open:
		return
	_close()


## UIをコードで構築
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
	_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_on_cancel_pressed()
	)
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
	_title_label.text = "💾 セーブ"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_SAVE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# スクロールコンテナ（カード一覧）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 600)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_cards_container = VBoxContainer.new()
	_cards_container.add_theme_constant_override("separation", 12)
	_cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards_container)

	# キャンセルボタン（Kenney UIスタイル）
	_cancel_button = Button.new()
	_cancel_button.text = "戻る"
	_cancel_button.custom_minimum_size = Vector2(0, 56)
	_cancel_button.add_theme_font_size_override("font_size", 24)
	_cancel_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_cancel_button, "grey")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_button)
