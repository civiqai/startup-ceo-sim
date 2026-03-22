extends CanvasLayer
## イベントポップアップ（モーダル表示）
## CanvasLayerで最前面に表示し、_inputでグローバルに入力を捕捉する

signal popup_closed(choice_index: int)

var _event_data: Dictionary = {}
var _effect_text: String = ""
var _waiting_for_ok := false
var _is_open := false

var _panel_root: Control
var _overlay: ColorRect
var _center: CenterContainer
var _panel: PanelContainer
var _vbox: VBoxContainer
var _title_label: Label
var _desc_label: Label
var _effect_label: Label
var _ok_button: Button
var _choices_container: VBoxContainer


func _ready() -> void:
	layer = 100  # 最前面
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	# GUI入力（ボタン等）処理後に残った入力を消費して下のノードに流さない
	get_viewport().set_input_as_handled()


func show_event(event_data: Dictionary) -> void:
	_event_data = event_data
	_effect_text = ""
	_waiting_for_ok = false

	var category_labels := {0: "経営", 1: "チーム", 2: "プロダクト", 3: "市場", 4: "？？？"}
	var cat_idx = event_data.get("category", 4)
	var cat_text = category_labels.get(cat_idx, "？？？")

	_title_label.text = "【%s】%s" % [cat_text, event_data.get("title", "")]
	_desc_label.text = event_data.get("description", "")

	var choices: Array = event_data.get("choices", [])

	# 選択肢ボタンをクリア
	for child in _choices_container.get_children():
		child.queue_free()

	if choices.size() > 0:
		_ok_button.visible = false
		_choices_container.visible = true
		_effect_label.visible = false

		for i in range(choices.size()):
			var btn = Button.new()
			btn.text = choices[i].get("label", "選択肢%d" % (i + 1))
			btn.custom_minimum_size = Vector2(0, 64)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.add_theme_font_size_override("font_size", 28)
			btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
			var idx = i
			btn.pressed.connect(func(): _on_choice_pressed(idx))
			_choices_container.add_child(btn)
	else:
		_ok_button.visible = true
		_choices_container.visible = false
		_effect_label.visible = true
		_waiting_for_ok = true

		var event_manager = _get_event_manager()
		if event_manager:
			_effect_text = event_manager.apply_event_effect(event_data)
		_effect_label.text = _effect_text

	_panel_root.visible = true
	_is_open = true


func _on_choice_pressed(index: int) -> void:
	var choices: Array = _event_data.get("choices", [])
	if index < choices.size():
		var event_manager = _get_event_manager()
		if event_manager:
			_effect_text = event_manager.apply_choice_effect(choices[index])

		_effect_label.text = _effect_text
		_effect_label.visible = true
		_choices_container.visible = false
		_ok_button.visible = true
		_waiting_for_ok = true


func _on_ok_pressed() -> void:
	if not _is_open:
		return
	_panel_root.visible = false
	_is_open = false
	_waiting_for_ok = false
	popup_closed.emit(0)


func _on_overlay_clicked() -> void:
	if _waiting_for_ok:
		_on_ok_pressed()


func _get_event_manager():
	# GameノードのTurnManagerの子としてEventManagerがある
	var game_node = get_parent()
	if game_node:
		var tm = game_node.get_node_or_null("TurnManager")
		if tm:
			for child in tm.get_children():
				if child.has_method("apply_event_effect"):
					return child
	return null


func get_effect_text() -> String:
	return _effect_text


## UIをコードで構築（.tscnに依存しない）
func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 暗いオーバーレイ
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.7)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			_on_overlay_clicked()
	)
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	_center = CenterContainer.new()
	_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(_center)

	# パネル（Kenney UIテクスチャ使用）
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
	KenneyTheme.apply_panel_style(_panel, "popup")
	_center.add_child(_panel)

	# VBoxContainer
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 18)
	_panel.add_child(_vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40, 1.0))
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_title_label)

	# 区切り線
	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40, 1.0))
	_vbox.add_child(sep)

	# 説明文
	_desc_label = Label.new()
	_desc_label.add_theme_color_override("font_color", Color(0.85, 0.87, 0.92, 1.0))
	_desc_label.add_theme_font_size_override("font_size", 28)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_desc_label)

	# 効果テキスト
	_effect_label = Label.new()
	_effect_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70, 1.0))
	_effect_label.add_theme_font_size_override("font_size", 28)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vbox.add_child(_effect_label)

	# 選択肢コンテナ
	_choices_container = VBoxContainer.new()
	_choices_container.add_theme_constant_override("separation", 10)
	_vbox.add_child(_choices_container)

	# OKボタン
	_ok_button = Button.new()
	_ok_button.text = "OK"
	_ok_button.custom_minimum_size = Vector2(0, 60)
	_ok_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_ok_button.add_theme_font_size_override("font_size", 30)
	_ok_button.pressed.connect(_on_ok_pressed)
	_vbox.add_child(_ok_button)
