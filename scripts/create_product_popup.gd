extends CanvasLayer
## プロダクト作成ポップアップ — タイプ・テーマ・技術スタック・ポイント配分

signal product_creation_completed(config: Dictionary)
signal cancelled

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _main_panel: PanelContainer
var _scroll: ScrollContainer
var _content_vbox: VBoxContainer
var _step := 0  # 0=タイプ, 1=テーマ, 2=技術スタック, 3=ポイント配分

# 選択状態
var _selected_type := ""
var _selected_theme := {}
var _selected_stack := {}
var _point_allocation := {"ux": 0, "design": 0, "margin": 0, "awareness": 0}
var _total_points := 10

# ポイント配分UI参照
var _point_labels := {}
var _point_bars := {}
var _remaining_label: Label
var _create_btn: Button

# 定数参照用
var _product_manager: Node


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func set_product_manager(pm: Node) -> void:
	_product_manager = pm


func show_creation() -> void:
	_step = 0
	_selected_type = ""
	_selected_theme = {}
	_selected_stack = {}
	_point_allocation = {"ux": 0, "design": 0, "margin": 0, "awareness": 0}
	_total_points = 10
	_panel_root.visible = true
	_is_open = true
	_render_step()


func hide_popup() -> void:
	_panel_root.visible = false
	_is_open = false


func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 半透明オーバーレイ
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cancel()
	)
	_panel_root.add_child(_overlay)

	# メインパネル
	_main_panel = PanelContainer.new()
	KenneyTheme.apply_panel_style(_main_panel, "popup")
	_main_panel.anchor_left = 0.02
	_main_panel.anchor_right = 0.98
	_main_panel.anchor_top = 0.05
	_main_panel.anchor_bottom = 0.95
	_main_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_main_panel)

	# スクロールコンテナ
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_main_panel.add_child(_scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content_vbox)


func _clear_content() -> void:
	for child in _content_vbox.get_children():
		child.queue_free()
	_point_labels.clear()
	_point_bars.clear()


func _render_step() -> void:
	_clear_content()
	match _step:
		0:
			_render_type_selection()
		1:
			_render_theme_selection()
		2:
			_render_stack_selection()
		3:
			_render_point_allocation()


# =============================================
# Step 0: プロダクトタイプ選択
# =============================================
func _render_type_selection() -> void:
	_add_step_header("Step 1/4: プロダクトタイプ選択", "作りたいプロダクトの種類を選びましょう")

	if not _product_manager:
		return

	for type_id in _product_manager.PRODUCT_TYPES:
		var type_data: Dictionary = _product_manager.PRODUCT_TYPES[type_id]
		var card := _create_type_card(type_id, type_data)
		_content_vbox.add_child(card)

	# キャンセルボタン
	_add_cancel_button()


func _create_type_card(type_id: String, type_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	KenneyTheme.apply_panel_style(panel, "popup")
	panel.custom_minimum_size = Vector2(0, 100)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# タイプ名 + アイコン
	var title := Label.new()
	title.text = "%s %s" % [type_data.get("icon", ""), type_data.get("name", "")]
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title)

	# 説明
	var desc := Label.new()
	desc.text = type_data.get("description", "")
	desc.add_theme_font_size_override("font_size", 24)
	desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.85))
	vbox.add_child(desc)

	# 費用情報
	var cost_label := Label.new()
	cost_label.text = "初期費用: %d万円 / 月額メンテ: %d万円" % [
		type_data.get("init_cost", 0), type_data.get("monthly_maintenance", 0)]
	cost_label.add_theme_font_size_override("font_size", 22)
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	vbox.add_child(cost_label)

	# ボタン化
	var btn := Button.new()
	btn.text = "%s %sを選ぶ" % [type_data.get("icon", ""), type_data.get("name", "")]
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(btn, "blue")
	# 資金不足チェック
	if GameState.cash < type_data.get("init_cost", 0):
		btn.text += "（資金不足）"
		btn.disabled = true
	btn.pressed.connect(_on_type_selected.bind(type_id))
	vbox.add_child(btn)

	return panel


func _on_type_selected(type_id: String) -> void:
	AudioManager.play_sfx("click")
	_selected_type = type_id
	_step = 1
	_render_step()


# =============================================
# Step 1: テーマ選択
# =============================================
func _render_theme_selection() -> void:
	_add_step_header("Step 2/4: テーマ選択", "プロダクトのテーマを選びましょう")
	_add_selection_preview()

	var themes: Array = _product_manager.PRODUCT_THEMES.get(_selected_type, [])
	for theme in themes:
		var btn := _create_theme_button(theme)
		_content_vbox.add_child(btn)

	_add_back_button()


func _create_theme_button(theme: Dictionary) -> Button:
	var bonus_text := _format_bonus(theme.get("bonus", {}))
	var btn := Button.new()
	btn.text = "%s %s  %s" % [theme.get("icon", ""), theme.get("name", ""), bonus_text]
	btn.custom_minimum_size = Vector2(0, 64)
	btn.add_theme_font_size_override("font_size", 28)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	KenneyTheme.apply_button_style(btn, "blue")
	btn.pressed.connect(_on_theme_selected.bind(theme))
	return btn


func _on_theme_selected(theme: Dictionary) -> void:
	AudioManager.play_sfx("click")
	_selected_theme = theme
	_step = 2
	_render_step()


# =============================================
# Step 2: 技術スタック選択
# =============================================
func _render_stack_selection() -> void:
	_add_step_header("Step 3/4: 技術スタック選択", "開発に使う技術を選びましょう")
	_add_selection_preview()

	for stack in _product_manager.TECH_STACKS:
		var btn := _create_stack_button(stack)
		_content_vbox.add_child(btn)

	_add_back_button()


func _create_stack_button(stack: Dictionary) -> Button:
	var bonus_text := _format_bonus(stack.get("bonus", {}))
	var btn := Button.new()
	btn.text = "%s %s\n%s  %s" % [
		stack.get("icon", ""), stack.get("name", ""),
		stack.get("description", ""), bonus_text]
	btn.custom_minimum_size = Vector2(0, 72)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	KenneyTheme.apply_button_style(btn, "blue")
	btn.pressed.connect(_on_stack_selected.bind(stack))
	return btn


func _on_stack_selected(stack: Dictionary) -> void:
	AudioManager.play_sfx("click")
	_selected_stack = stack
	# ポイント計算
	_total_points = _product_manager.get_allocation_points()
	_point_allocation = {"ux": 0, "design": 0, "margin": 0, "awareness": 0}
	_step = 3
	_render_step()


# =============================================
# Step 3: ポイント配分
# =============================================
func _render_point_allocation() -> void:
	_add_step_header("Step 4/4: 初期ポイント配分", "チーム構成に応じたポイントを各能力に振り分けましょう")
	_add_selection_preview()

	# ボーナスプレビュー
	var bonus_preview := _get_total_bonus()
	if not bonus_preview.is_empty():
		var bonus_label := Label.new()
		bonus_label.text = "テーマ・技術スタックボーナス: %s" % _format_bonus(bonus_preview)
		bonus_label.add_theme_font_size_override("font_size", 22)
		bonus_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		bonus_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_content_vbox.add_child(bonus_label)

	# 残りポイント表示
	_remaining_label = Label.new()
	_remaining_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_remaining_label.add_theme_font_size_override("font_size", 30)
	_remaining_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	_content_vbox.add_child(_remaining_label)

	# パラメータ別配分UI
	var params := [
		{"key": "ux", "label": "🎨 UX", "color": Color(0.3, 0.7, 1.0)},
		{"key": "design", "label": "✏️ デザイン", "color": Color(0.9, 0.5, 0.8)},
		{"key": "margin", "label": "💰 利益率", "color": Color(0.4, 0.9, 0.4)},
		{"key": "awareness", "label": "📢 知名度", "color": Color(1.0, 0.8, 0.3)},
	]

	for p in params:
		var row := _create_point_row(p["key"], p["label"], p["color"])
		_content_vbox.add_child(row)

	_update_point_display()

	# 作成ボタン
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	_content_vbox.add_child(btn_hbox)

	var back_btn := Button.new()
	back_btn.text = "◀ 戻る"
	back_btn.custom_minimum_size = Vector2(0, 56)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(back_btn, "grey")
	back_btn.pressed.connect(_on_back)
	btn_hbox.add_child(back_btn)

	_create_btn = Button.new()
	_create_btn.text = "📦 作成する"
	_create_btn.custom_minimum_size = Vector2(0, 56)
	_create_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_create_btn.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(_create_btn, "blue")
	_create_btn.pressed.connect(_on_create_pressed)
	btn_hbox.add_child(_create_btn)


func _create_point_row(key: String, label_text: String, bar_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.custom_minimum_size = Vector2(0, 48)

	# ラベル
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	label.add_theme_font_size_override("font_size", 26)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(label)

	# マイナスボタン
	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(48, 48)
	minus_btn.add_theme_font_size_override("font_size", 30)
	KenneyTheme.apply_button_style(minus_btn, "red")
	minus_btn.pressed.connect(_on_point_change.bind(key, -1))
	row.add_child(minus_btn)

	# バー表示用コンテナ
	var bar_container := PanelContainer.new()
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.custom_minimum_size = Vector2(0, 36)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	bar_container.add_theme_stylebox_override("panel", bar_bg)
	row.add_child(bar_container)

	var bar := ColorRect.new()
	bar.color = bar_color
	bar.custom_minimum_size = Vector2(0, 28)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar_container.add_child(bar)
	_point_bars[key] = {"bar": bar, "container": bar_container}

	# 数値ラベル
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(40, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 28)
	value_label.add_theme_color_override("font_color", Color(1, 1, 1))
	row.add_child(value_label)
	_point_labels[key] = value_label

	# プラスボタン
	var plus_btn := Button.new()
	plus_btn.text = "＋"
	plus_btn.custom_minimum_size = Vector2(48, 48)
	plus_btn.add_theme_font_size_override("font_size", 30)
	KenneyTheme.apply_button_style(plus_btn, "green")
	plus_btn.pressed.connect(_on_point_change.bind(key, 1))
	row.add_child(plus_btn)

	return row


func _on_point_change(key: String, delta: int) -> void:
	AudioManager.play_sfx("click")
	var new_val: int = _point_allocation[key] + delta
	if new_val < 0:
		return
	if new_val > 20:
		return
	var used := _get_used_points()
	if delta > 0 and used >= _total_points:
		return
	_point_allocation[key] = new_val
	_update_point_display()


func _get_used_points() -> int:
	var total := 0
	for key in _point_allocation:
		total += _point_allocation[key]
	return total


func _update_point_display() -> void:
	var used := _get_used_points()
	var remaining := _total_points - used
	if _remaining_label:
		_remaining_label.text = "配分ポイント: %d / %d（残り %d）" % [used, _total_points, remaining]
		if remaining == 0:
			_remaining_label.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
		else:
			_remaining_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))

	for key in _point_allocation:
		if _point_labels.has(key):
			_point_labels[key].text = str(_point_allocation[key])
		if _point_bars.has(key):
			var bar_data: Dictionary = _point_bars[key]
			var bar: ColorRect = bar_data["bar"]
			var container: PanelContainer = bar_data["container"]
			# バーの幅を割合で設定（最大20）
			var ratio: float = _point_allocation[key] / 20.0
			bar.custom_minimum_size.x = container.size.x * ratio


func _on_create_pressed() -> void:
	AudioManager.play_sfx("click")
	var bonus := _get_total_bonus()
	var config := {
		"type": _selected_type,
		"theme": _selected_theme,
		"tech_stack": _selected_stack,
		"initial_ux": _point_allocation["ux"] + bonus.get("ux", 0),
		"initial_design": _point_allocation["design"] + bonus.get("design", 0),
		"initial_margin": _point_allocation["margin"] + bonus.get("margin", 0),
		"initial_awareness": _point_allocation["awareness"] + bonus.get("awareness", 0),
	}
	hide_popup()
	product_creation_completed.emit(config)


# =============================================
# 共通UIヘルパー
# =============================================
func _add_step_header(title: String, subtitle: String) -> void:
	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_content_vbox.add_child(title_label)

	var sub_label := Label.new()
	sub_label.text = subtitle
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.add_theme_font_size_override("font_size", 24)
	sub_label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.80))
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content_vbox.add_child(sub_label)

	# セパレータ
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_content_vbox.add_child(sep)


func _add_selection_preview() -> void:
	var parts: Array[String] = []
	if _selected_type != "":
		var type_data: Dictionary = _product_manager.PRODUCT_TYPES.get(_selected_type, {})
		parts.append("%s %s" % [type_data.get("icon", ""), type_data.get("name", "")])
	if not _selected_theme.is_empty():
		parts.append("%s %s" % [_selected_theme.get("icon", ""), _selected_theme.get("name", "")])
	if not _selected_stack.is_empty():
		parts.append("%s %s" % [_selected_stack.get("icon", ""), _selected_stack.get("name", "")])

	if parts.is_empty():
		return

	var preview := Label.new()
	preview.text = "選択中: " + " > ".join(parts)
	preview.add_theme_font_size_override("font_size", 22)
	preview.add_theme_color_override("font_color", Color(0.5, 0.80, 1.0))
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD
	_content_vbox.add_child(preview)


func _add_cancel_button() -> void:
	var btn := Button.new()
	btn.text = "✕ キャンセル"
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(btn, "grey")
	btn.pressed.connect(_on_cancel)
	_content_vbox.add_child(btn)


func _add_back_button() -> void:
	var btn := Button.new()
	btn.text = "◀ 戻る"
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(btn, "grey")
	btn.pressed.connect(_on_back)
	_content_vbox.add_child(btn)


func _on_back() -> void:
	AudioManager.play_sfx("click")
	if _step > 0:
		_step -= 1
		_render_step()


func _on_cancel() -> void:
	AudioManager.play_sfx("click")
	hide_popup()
	cancelled.emit()


func _format_bonus(bonus: Dictionary) -> String:
	var parts: Array[String] = []
	var labels := {"ux": "UX", "design": "デザイン", "margin": "利益率", "awareness": "知名度"}
	for key in bonus:
		if labels.has(key):
			parts.append("%s+%d" % [labels[key], bonus[key]])
	if parts.is_empty():
		return ""
	return "(%s)" % ", ".join(parts)


func _get_total_bonus() -> Dictionary:
	var bonus := {}
	# テーマボーナス
	var theme_bonus: Dictionary = _selected_theme.get("bonus", {})
	for key in theme_bonus:
		bonus[key] = bonus.get(key, 0) + theme_bonus[key]
	# 技術スタックボーナス
	var stack_bonus: Dictionary = _selected_stack.get("bonus", {})
	for key in stack_bonus:
		bonus[key] = bonus.get(key, 0) + stack_bonus[key]
	return bonus
