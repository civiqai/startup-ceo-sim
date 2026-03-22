extends CanvasLayer
## 月別ログ履歴ポップアップ

signal popup_closed

var _is_open := false
var _panel_root: Control
var _scroll: ScrollContainer
var _log_container: VBoxContainer
var _close_btn: Button
var _history_data: Array = []

const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_MONTH_HEADER := Color(0.35, 0.65, 0.85)


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func show_history(data: Array) -> void:
	_history_data = data
	_rebuild_content()
	_panel_root.visible = true
	_is_open = true


func _rebuild_content() -> void:
	for child in _log_container.get_children():
		child.queue_free()

	if _history_data.is_empty():
		var empty_label := Label.new()
		empty_label.text = "まだ経営ログがありません。\nアクションを実行すると記録されます。"
		empty_label.add_theme_font_size_override("font_size", 22)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_log_container.add_child(empty_label)
		return

	# 新しい月から表示（逆順）
	for i in range(_history_data.size() - 1, -1, -1):
		var entry: Dictionary = _history_data[i]
		var month_num: int = entry.get("month", 0)

		# 月ヘッダー
		var header := Label.new()
		header.text = "━━ %dヶ月目 ━━" % (month_num + 1)
		header.add_theme_font_size_override("font_size", 24)
		header.add_theme_color_override("font_color", COLOR_MONTH_HEADER)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_log_container.add_child(header)

		# パラメータサマリー
		var summary := Label.new()
		summary.text = "💰%d万 📱%s人 💹%d万/月 👥%d人" % [
			entry.get("cash", 0),
			_format_number(entry.get("users", 0)),
			entry.get("revenue", 0),
			entry.get("team_size", 1),
		]
		summary.add_theme_font_size_override("font_size", 18)
		summary.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		_log_container.add_child(summary)

		# イベントログ
		var events: Array = entry.get("events", [])
		for evt in events:
			var evt_label := Label.new()
			evt_label.text = "  " + str(evt)
			evt_label.add_theme_font_size_override("font_size", 20)
			evt_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
			evt_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			_log_container.add_child(evt_label)

		# 区切り
		var sep := HSeparator.new()
		sep.add_theme_color_override("separator_color", Color(0.20, 0.22, 0.28))
		_log_container.add_child(sep)


func _format_number(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 100000000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)


func _on_close() -> void:
	AudioManager.play_sfx("click")
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = 0.03
	panel.anchor_bottom = 0.97
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	KenneyTheme.apply_panel_style(panel, "popup")
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "📋 経営ログ"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_log_container = VBoxContainer.new()
	_log_container.add_theme_constant_override("separation", 4)
	_log_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_log_container)

	_close_btn = Button.new()
	_close_btn.text = "閉じる"
	_close_btn.custom_minimum_size = Vector2(0, 48)
	_close_btn.add_theme_font_size_override("font_size", 26)
	KenneyTheme.apply_button_style(_close_btn, "grey")
	_close_btn.pressed.connect(_on_close)
	vbox.add_child(_close_btn)
