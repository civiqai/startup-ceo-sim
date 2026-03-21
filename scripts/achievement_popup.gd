extends CanvasLayer
## 実績アンロックポップアップ — 実績達成時の表示 + 実績一覧

signal popup_closed

var _panel: PanelContainer
var _vbox: VBoxContainer
var _queue: Array[Dictionary] = []
var _showing := false


func _ready() -> void:
	layer = 110
	_build_ui()
	_panel.visible = false


## 実績アンロック通知を表示
func show_achievement(achievement: Dictionary) -> void:
	_queue.append(achievement)
	if not _showing:
		_show_next()


## 実績一覧を表示
func show_list(achievements: Array[Dictionary]) -> void:
	_clear()
	_panel.visible = true
	_showing = true

	var title = Label.new()
	title.text = "🏆 実績一覧"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 1, 1))
	_vbox.add_child(title)

	var unlocked_count := 0
	for ach in achievements:
		if ach.get("unlocked", false):
			unlocked_count += 1

	var count_label = Label.new()
	count_label.text = "%d / %d 解除済み" % [unlocked_count, achievements.size()]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	_vbox.add_child(count_label)

	var sep = HSeparator.new()
	_vbox.add_child(sep)

	for ach in achievements:
		var is_unlocked = ach.get("unlocked", false)
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)

		var icon = Label.new()
		icon.text = ach.get("icon", "?") if is_unlocked else "🔒"
		icon.add_theme_font_size_override("font_size", 28)
		hbox.add_child(icon)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var name_label = Label.new()
		name_label.text = ach.get("name", "") if is_unlocked else "???"
		name_label.add_theme_font_size_override("font_size", 22)
		var name_color = Color(1, 1, 1) if is_unlocked else Color(0.45, 0.48, 0.55)
		name_label.add_theme_color_override("font_color", name_color)
		info_vbox.add_child(name_label)

		var desc_label = Label.new()
		desc_label.text = ach.get("description", "") if is_unlocked else "条件を満たすと解放"
		desc_label.add_theme_font_size_override("font_size", 16)
		desc_label.add_theme_color_override("font_color", Color(0.55, 0.58, 0.65))
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		info_vbox.add_child(desc_label)

		if is_unlocked:
			var reward_label = Label.new()
			reward_label.text = "🎁 " + ach.get("reward", "")
			reward_label.add_theme_font_size_override("font_size", 16)
			reward_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
			info_vbox.add_child(reward_label)

		hbox.add_child(info_vbox)
		_vbox.add_child(hbox)

	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func():
		_panel.visible = false
		_showing = false
		popup_closed.emit())
	_vbox.add_child(close_btn)


## 実績アンロック通知を順番に表示
func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		popup_closed.emit()
		return
	_showing = true
	var ach = _queue.pop_front()
	_clear()
	_panel.visible = true

	var icon = Label.new()
	icon.text = ach.get("icon", "🏆")
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 56)
	_vbox.add_child(icon)

	var title = Label.new()
	title.text = "実績解除！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
	_vbox.add_child(title)

	var name_label = Label.new()
	name_label.text = ach.get("name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_vbox.add_child(name_label)

	var desc = Label.new()
	desc.text = ach.get("description", "")
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 18)
	desc.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	_vbox.add_child(desc)

	var reward = Label.new()
	reward.text = "🎁 報酬: " + ach.get("reward", "")
	reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward.add_theme_font_size_override("font_size", 20)
	reward.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	_vbox.add_child(reward)

	# 3秒後自動クローズ or タップ
	var close_btn = Button.new()
	close_btn.text = "OK"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func():
		_panel.visible = false
		_show_next())
	_vbox.add_child(close_btn)

	get_tree().create_timer(4.0).timeout.connect(func():
		if _panel.visible and _showing:
			_panel.visible = false
			_show_next())


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.1
	_panel.anchor_right = 0.9
	_panel.anchor_top = 0.15
	_panel.anchor_bottom = 0.85
	KenneyTheme.apply_panel_style(_panel, "popup")

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_vbox)

	add_child(_panel)


func _clear() -> void:
	for child in _vbox.get_children():
		child.queue_free()
