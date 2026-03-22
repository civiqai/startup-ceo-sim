extends CanvasLayer
## フェーズ昇格お祝いポップアップ
## 紙吹雪アニメーション付きでフェーズ昇格を祝福する

signal popup_closed

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _center_panel: PanelContainer
var _icon_label: Label
var _title_label: Label
var _phase_name_label: Label
var _desc_label: Label
var _unlock_label: Label
var _close_button: Button
var _confetti_container: Control
var _auto_close_timer: Timer

# 紙吹雪の色
const CONFETTI_COLORS := [
	Color(1.0, 0.85, 0.40),   # ゴールド
	Color(0.95, 0.40, 0.40),  # 赤
	Color(0.40, 0.80, 0.95),  # 水色
	Color(0.60, 0.95, 0.45),  # 黄緑
	Color(0.85, 0.50, 0.95),  # 紫
	Color(1.0, 0.60, 0.30),   # オレンジ
	Color(0.95, 0.95, 0.40),  # 黄色
]

const COLOR_TITLE_GOLD := Color(1.0, 0.85, 0.40)
const COLOR_TEXT_GRAY := Color(0.75, 0.77, 0.82)
const COLOR_UNLOCK_GREEN := Color(0.55, 0.90, 0.55)


func _ready() -> void:
	layer = 110
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton and event.pressed:
		_close()
	get_viewport().set_input_as_handled()


## フェーズ昇格データを受け取って表示
func show_phase(phase_data: Dictionary) -> void:
	var icon: String = phase_data.get("icon", "🎉")
	var phase_name: String = phase_data.get("name", "")
	var description: String = phase_data.get("description", "")
	var unlocks: Array = phase_data.get("unlocks", [])

	_icon_label.text = icon
	_title_label.text = "フェーズ昇格！"
	_phase_name_label.text = "%s %s" % [icon, phase_name]
	_desc_label.text = description

	# アンロック情報
	if unlocks.size() > 0:
		var unlock_names := []
		var action_labels := {
			"develop": "開発",
			"hire": "採用",
			"marketing": "マーケティング",
			"fundraise": "資金調達",
			"team_care": "チームケア",
		}
		for u in unlocks:
			unlock_names.append(action_labels.get(u, u))
		_unlock_label.text = "🔓 解放: %s" % "、".join(unlock_names)
		_unlock_label.visible = true
	else:
		_unlock_label.visible = false

	_panel_root.visible = true
	_is_open = true

	# パネル登場アニメーション
	_center_panel.scale = Vector2.ZERO
	_center_panel.pivot_offset = _center_panel.size / 2.0
	var tween := create_tween()
	tween.tween_property(_center_panel, "scale", Vector2.ONE, 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# アイコンパルスアニメーション
	_start_icon_pulse()

	# 紙吹雪を生成
	_spawn_confetti(30)

	# 自動クローズタイマー（5秒）
	_auto_close_timer.start(5.0)


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_auto_close_timer.stop()

	var tween := create_tween()
	tween.tween_property(_panel_root, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(func():
		_panel_root.visible = false
		_panel_root.modulate = Color(1, 1, 1, 1)
		for child in _confetti_container.get_children():
			child.queue_free()
		popup_closed.emit()
	)


func _start_icon_pulse() -> void:
	if not _is_open:
		return
	var tween := create_tween().set_loops()
	_icon_label.pivot_offset = _icon_label.size / 2.0
	tween.tween_property(_icon_label, "scale", Vector2(1.2, 1.2), 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_icon_label, "scale", Vector2.ONE, 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


func _spawn_confetti(count: int) -> void:
	for child in _confetti_container.get_children():
		child.queue_free()

	var viewport_size := Vector2(720, 1280)
	if get_viewport():
		viewport_size = get_viewport().get_visible_rect().size

	for i in count:
		var confetti := ColorRect.new()
		var w := randf_range(8, 16)
		var h := randf_range(12, 24)
		confetti.custom_minimum_size = Vector2(w, h)
		confetti.size = Vector2(w, h)
		confetti.color = CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()]

		var start_x := randf_range(20, viewport_size.x - 20)
		var start_y := randf_range(-50, -10)
		confetti.position = Vector2(start_x, start_y)
		confetti.rotation = randf_range(0, TAU)

		_confetti_container.add_child(confetti)

		var duration := randf_range(2.0, 3.5)
		var delay := randf_range(0.0, 0.5)
		var end_y := viewport_size.y + 50
		var drift_x := randf_range(-80, 80)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(confetti, "position:y", end_y, duration)\
			.set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(confetti, "position:x", start_x + drift_x, duration)\
			.set_delay(delay).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(confetti, "rotation", confetti.rotation + randf_range(TAU, TAU * 3), duration)\
			.set_delay(delay)
		tween.tween_property(confetti, "modulate:a", 0.0, duration * 0.4)\
			.set_delay(delay + duration * 0.6)


## UIをコードで構築
func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 暗いオーバーレイ
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.75)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_close()
	)
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	# メインパネル
	_center_panel = PanelContainer.new()
	_center_panel.custom_minimum_size = Vector2(580, 0)
	KenneyTheme.apply_panel_style(_center_panel, "popup")
	center.add_child(_center_panel)

	# メインVBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_center_panel.add_child(vbox)

	# アイコン（大きな絵文字）
	_icon_label = Label.new()
	_icon_label.text = "🎉"
	_icon_label.add_theme_font_size_override("font_size", 76)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_icon_label)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "フェーズ昇格！"
	_title_label.add_theme_font_size_override("font_size", 38)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# フェーズ名
	_phase_name_label = Label.new()
	_phase_name_label.text = ""
	_phase_name_label.add_theme_font_size_override("font_size", 32)
	_phase_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_phase_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_phase_name_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.40, 0.35, 0.20))
	vbox.add_child(sep)

	# 説明文
	_desc_label = Label.new()
	_desc_label.text = ""
	_desc_label.add_theme_font_size_override("font_size", 26)
	_desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	# アンロック情報
	_unlock_label = Label.new()
	_unlock_label.text = ""
	_unlock_label.add_theme_font_size_override("font_size", 28)
	_unlock_label.add_theme_color_override("font_color", COLOR_UNLOCK_GREEN)
	_unlock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_unlock_label)

	# スペーサー
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# 閉じるボタン
	_close_button = Button.new()
	_close_button.text = "さらなる成長へ！"
	_close_button.custom_minimum_size = Vector2(0, 56)
	_close_button.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(_close_button, "yellow")
	_close_button.pressed.connect(_close)
	vbox.add_child(_close_button)

	# 紙吹雪コンテナ（最前面）
	_confetti_container = Control.new()
	_confetti_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_confetti_container)

	# 自動クローズタイマー
	_auto_close_timer = Timer.new()
	_auto_close_timer.one_shot = true
	_auto_close_timer.timeout.connect(_close)
	add_child(_auto_close_timer)
