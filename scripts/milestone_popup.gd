extends CanvasLayer
## マイルストーン達成お祝いポップアップ
## 紙吹雪アニメーション付きの祝福オーバーレイを表示する

signal popup_closed

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _center_panel: PanelContainer
var _icon_label: Label
var _title_label: Label
var _desc_label: Label
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

# スタイル定数
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16)
const COLOR_PANEL_BORDER := Color(1.0, 0.85, 0.40, 0.6)
const COLOR_TITLE_GOLD := Color(1.0, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.75, 0.77, 0.82)


func _ready() -> void:
	layer = 110  # 他のポップアップより前面
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	# タップで閉じる
	if event is InputEventMouseButton and event.pressed:
		_close()
	get_viewport().set_input_as_handled()


## マイルストーンデータを受け取って表示
func show_milestone(milestone_data: Dictionary) -> void:
	_icon_label.text = milestone_data.get("icon", "🎉")
	_title_label.text = milestone_data.get("title", "マイルストーン達成！")
	_desc_label.text = milestone_data.get("description", "")

	_panel_root.visible = true
	_is_open = true

	# パネル登場アニメーション（バウンス付きスケール）
	_center_panel.scale = Vector2.ZERO
	_center_panel.pivot_offset = _center_panel.size / 2.0
	var tween := create_tween()
	tween.tween_property(_center_panel, "scale", Vector2.ONE, 0.4)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# アイコンパルスアニメーション（ループ）
	_start_icon_pulse()

	# 紙吹雪を生成
	_spawn_confetti(25)

	# 自動クローズタイマー（4秒）
	_auto_close_timer.start(4.0)


func _close() -> void:
	if not _is_open:
		return
	_is_open = false
	_auto_close_timer.stop()

	# フェードアウト
	var tween := create_tween()
	tween.tween_property(_panel_root, "modulate", Color(1, 1, 1, 0), 0.25)
	tween.tween_callback(func():
		_panel_root.visible = false
		_panel_root.modulate = Color(1, 1, 1, 1)
		# 紙吹雪をクリア
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
	# 紙吹雪をクリア
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

		# ランダムなX位置、画面上部からスタート
		var start_x := randf_range(20, viewport_size.x - 20)
		var start_y := randf_range(-50, -10)
		confetti.position = Vector2(start_x, start_y)

		# ランダムな回転
		confetti.rotation = randf_range(0, TAU)

		_confetti_container.add_child(confetti)

		# 落下アニメーション
		var duration := randf_range(2.0, 3.0)
		var delay := randf_range(0.0, 0.5)
		var end_y := viewport_size.y + 50
		var drift_x := randf_range(-80, 80)

		var tween := create_tween()
		tween.set_parallel(true)
		# Y方向: 落下
		tween.tween_property(confetti, "position:y", end_y, duration)\
			.set_delay(delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		# X方向: 横揺れ
		tween.tween_property(confetti, "position:x", start_x + drift_x, duration)\
			.set_delay(delay).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		# 回転
		tween.tween_property(confetti, "rotation", confetti.rotation + randf_range(TAU, TAU * 3), duration)\
			.set_delay(delay)
		# フェードアウト（後半）
		tween.tween_property(confetti, "modulate:a", 0.0, duration * 0.4)\
			.set_delay(delay + duration * 0.6)


## UIをコードで構築（.tscnに依存しない）
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

	# 紙吹雪コンテナ（パネルの後ろに配置すると見えにくいので前面に）
	# → パネルより先に追加し、パネルが上に来るようにする
	# → 実際には紙吹雪はパネルの上に表示したいので後で追加
	# まずパネルを配置

	# 中央配置コンテナ
	# メインパネル（Kenney UIテクスチャ使用）
	_center_panel = PanelContainer.new()
	_center_panel.custom_minimum_size = Vector2(560, 0)
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
	_icon_label.add_theme_font_size_override("font_size", 68)
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_icon_label)

	# タイトル（ゴールド太字）
	_title_label = Label.new()
	_title_label.text = "マイルストーン達成！"
	_title_label.add_theme_font_size_override("font_size", 36)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_label)

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

	# スペーサー
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# 閉じるボタン（Kenney UIスタイル - ゴールド→黄色）
	_close_button = Button.new()
	_close_button.text = "素晴らしい！"
	_close_button.custom_minimum_size = Vector2(0, 56)
	_close_button.add_theme_font_size_override("font_size", 28)
	_close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_close_button, "yellow")
	_close_button.pressed.connect(_close)
	vbox.add_child(_close_button)

	# 紙吹雪コンテナ（最前面に配置）
	_confetti_container = Control.new()
	_confetti_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confetti_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_confetti_container)

	# 自動クローズタイマー
	_auto_close_timer = Timer.new()
	_auto_close_timer.one_shot = true
	_auto_close_timer.timeout.connect(_close)
	add_child(_auto_close_timer)
