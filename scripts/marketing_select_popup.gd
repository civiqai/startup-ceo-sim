extends CanvasLayer
## マーケティングチャネル選択ポップアップ
## CanvasLayerで最前面に表示し、チャネルから選択させる

signal channel_selected(channel_id: String)
signal cancelled

const MarketingChannels = preload("res://scripts/marketing_channels.gd")

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _cards_container: VBoxContainer
var _cancel_button: Button
var _title_label: Label
var _info_label: Label

# Panel style colors
const COLOR_PANEL_BG := Color(0.10, 0.12, 0.18)
const COLOR_PANEL_BORDER := Color(0.30, 0.45, 0.25)
const COLOR_CARD_UNAVAILABLE := Color(0.15, 0.15, 0.15)
const COLOR_TITLE_GREEN := Color(0.40, 0.85, 0.55)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_UNLOCK_TEXT := Color(0.85, 0.55, 0.40)
const COLOR_COST_TEXT := Color(0.90, 0.75, 0.30)


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
	_info_label.text = "現在の資金: %d万円" % GameState.cash


func _rebuild_cards() -> void:
	# 既存カードをクリア
	for child in _cards_container.get_children():
		child.queue_free()

	var channels = MarketingChannels.get_all_channels()
	for channel_data in channels:
		var card := _build_card(channel_data)
		_cards_container.add_child(card)


func _build_card(channel_data: Dictionary) -> Button:
	var channel_id: String = channel_data.get("id", "")
	var channel_name: String = channel_data.get("name", "")
	var icon: String = channel_data.get("icon", "")
	var description: String = channel_data.get("description", "")
	var channel_color: Color = channel_data.get("color", Color.WHITE)
	var cost: int = channel_data.get("cost", 0)

	var phase_unlocked := MarketingChannels.is_phase_unlocked(channel_id, GameState)
	var available: bool = phase_unlocked and MarketingChannels.is_available(channel_id, GameState)

	# Button + テキストで構成（ScrollContainer内でスクロールとタップを自動区別）
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 90)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	if available:
		card_style.bg_color = channel_color.darkened(0.7)
	else:
		card_style.bg_color = COLOR_CARD_UNAVAILABLE
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 4
	card_style.border_color = channel_color if available else Color(0.30, 0.30, 0.30)
	card_style.content_margin_left = 16
	card_style.content_margin_top = 10
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 10

	var hover_style := card_style.duplicate()
	if available:
		hover_style.bg_color = channel_color.darkened(0.55)

	btn.add_theme_stylebox_override("normal", card_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", hover_style)
	btn.add_theme_stylebox_override("disabled", card_style)

	# ボタンのテキストを複数行で構成
	var cost_text := "コスト: %d万円" % cost
	if not phase_unlocked:
		var required_phase: int = channel_data.get("phase", 0)
		var phase_names := ["シード期", "アーリー", "シリーズA", "シリーズB", "プレIPO", "IPO"]
		var phase_name: String = phase_names[mini(required_phase, phase_names.size() - 1)]
		cost_text += "  🔒 %sで解放" % phase_name
	elif not available:
		cost_text += "  🔒 資金不足"
	btn.text = "%s %s\n%s\n%s" % [icon, channel_name, description, cost_text]
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE if available else COLOR_TEXT_GRAY)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if not available:
		btn.disabled = true
		btn.modulate = Color(1, 1, 1, 0.5)
	else:
		var cid = channel_id
		btn.pressed.connect(func(): _on_card_pressed(cid))

	return btn


func _on_card_pressed(channel_id: String) -> void:
	if not _is_open:
		return
	_panel_root.visible = false
	_is_open = false
	channel_selected.emit(channel_id)


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
	_title_label.text = "📢 マーケティング"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GREEN)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# 情報ラベル（現在の資金）
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 26)
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
	_cancel_button.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(_cancel_button, "grey")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_button)
