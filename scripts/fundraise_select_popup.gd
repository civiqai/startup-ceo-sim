extends CanvasLayer
## 資金調達タイプ選択ポップアップ
## CanvasLayerで最前面に表示し、4種類の調達タイプから選択させる

signal type_selected(type_id: String)
signal cancelled

const FundraiseTypes = preload("res://scripts/fundraise_types.gd")

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _cards_container: VBoxContainer
var _cancel_button: Button
var _title_label: Label
var _info_label: Label

# Variance risk colors
const COLOR_RISK_HIGH := Color(0.90, 0.40, 0.35)
const COLOR_RISK_MEDIUM := Color(0.90, 0.75, 0.30)
const COLOR_RISK_LOW := Color(0.55, 0.85, 0.55)

# Panel style colors
const COLOR_PANEL_BG := Color(0.10, 0.12, 0.18)
const COLOR_PANEL_BORDER := Color(0.25, 0.45, 0.30)
const COLOR_CARD_UNAVAILABLE := Color(0.15, 0.15, 0.15)
const COLOR_TITLE_GOLD := Color(1.0, 0.85, 0.40)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_UNLOCK_TEXT := Color(0.85, 0.55, 0.40)


func _ready() -> void:
	layer = 100  # 最前面
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	# GUI入力（ボタン等）処理後に残った入力を消費して下のノードに流さない
	get_viewport().set_input_as_handled()


func show_selection() -> void:
	_rebuild_cards()
	_update_info()
	_panel_root.visible = true
	_is_open = true


func _update_info() -> void:
	var amount_text := "調達可能額: %d万円" % GameState.max_fundraise_amount
	if GameState.fundraise_cooldown > 0:
		amount_text += "\n⚠ クールダウン中: あと%dヶ月" % GameState.fundraise_cooldown
		_info_label.add_theme_color_override("font_color", COLOR_RISK_MEDIUM)
	else:
		_info_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	_info_label.text = amount_text


func _rebuild_cards() -> void:
	# 既存カードをクリア
	for child in _cards_container.get_children():
		child.queue_free()

	var types = FundraiseTypes.get_all_types()
	for type_data in types:
		var card := _build_card(type_data)
		_cards_container.add_child(card)


func _build_card(type_data: Dictionary) -> PanelContainer:
	var type_id: String = type_data.get("id", "")
	var type_name: String = type_data.get("name", "")
	var icon: String = type_data.get("icon", "")
	var description: String = type_data.get("description", "")
	var type_color: Color = type_data.get("color", Color.WHITE)
	var variance: String = type_data.get("variance", "medium")

	var available := FundraiseTypes.is_available(type_id, GameState)

	# カードのスタイル
	var card_style := StyleBoxFlat.new()
	if available:
		card_style.bg_color = type_color.darkened(0.7)
	else:
		card_style.bg_color = COLOR_CARD_UNAVAILABLE
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 4
	card_style.border_color = type_color if available else Color(0.30, 0.30, 0.30)
	card_style.content_margin_left = 16
	card_style.content_margin_top = 14
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 14

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(0, 90)

	if not available:
		card.modulate = Color(1, 1, 1, 0.4)

	# HBoxContainer: アイコン + テキスト情報
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(hbox)

	# アイコン
	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 36)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(48, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# テキスト情報のVBox
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(text_vbox)

	# タイプ名
	var name_label := Label.new()
	name_label.text = type_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	text_vbox.add_child(name_label)

	# 説明文
	var desc_label := Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_vbox.add_child(desc_label)

	# リスク表示
	var risk_label := Label.new()
	var risk_text: String
	var risk_color: Color
	match variance:
		"high":
			risk_text = "リスク: 高"
			risk_color = COLOR_RISK_HIGH
		"medium":
			risk_text = "リスク: 中"
			risk_color = COLOR_RISK_MEDIUM
		"low":
			risk_text = "リスク: 低"
			risk_color = COLOR_RISK_LOW
		_:
			risk_text = "リスク: —"
			risk_color = COLOR_TEXT_GRAY
	risk_label.text = risk_text
	risk_label.add_theme_font_size_override("font_size", 18)
	risk_label.add_theme_color_override("font_color", risk_color)
	text_vbox.add_child(risk_label)

	# 利用不可の場合はアンロック条件を表示
	if not available:
		var unlock_text := FundraiseTypes.get_unlock_text(type_id)
		if unlock_text != "":
			var unlock_label := Label.new()
			unlock_label.text = "🔒 " + unlock_text
			unlock_label.add_theme_font_size_override("font_size", 16)
			unlock_label.add_theme_color_override("font_color", COLOR_UNLOCK_TEXT)
			unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text_vbox.add_child(unlock_label)

	# インタラクション設定
	if available:
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_on_card_pressed(type_id)
		)
	else:
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return card


func _on_card_pressed(type_id: String) -> void:
	if not _is_open:
		return
	_panel_root.visible = false
	_is_open = false
	type_selected.emit(type_id)


func _on_cancel_pressed() -> void:
	if not _is_open:
		return
	_panel_root.visible = false
	_is_open = false
	cancelled.emit()


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
	_title_label.text = "💵 資金調達"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# 情報ラベル（調達可能額・クールダウン）
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 22)
	_info_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_label)

	# スクロールコンテナ（カード一覧）
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 700)
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
