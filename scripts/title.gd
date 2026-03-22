extends Control

var save_load_popup: Node


func _ready() -> void:
	# スタートボタンにKenneyグリーンスタイルを適用
	KenneyTheme.apply_button_style($SafeArea/VBox/StartButton, "green")
	$SafeArea/VBox/StartButton.pressed.connect(_on_start_pressed)
	AudioManager.play_bgm("title")

	# つづきからボタンを追加（セーブデータがある場合のみ表示）
	var has_any_save := false
	for slot in SaveManager.get_all_slots():
		if SaveManager.has_save(slot):
			has_any_save = true
			break

	var continue_btn := Button.new()
	continue_btn.text = "つづきから"
	continue_btn.custom_minimum_size = Vector2(400, 60)
	continue_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_btn.add_theme_font_size_override("font_size", 26)
	continue_btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(continue_btn, "blue")

	# StartButtonの後に挿入
	var start_idx := $SafeArea/VBox/StartButton.get_index()
	$SafeArea/VBox.add_child(continue_btn)
	$SafeArea/VBox.move_child(continue_btn, start_idx + 1)

	if not has_any_save:
		continue_btn.modulate = Color(1, 1, 1, 0.3)
		continue_btn.disabled = true

	continue_btn.pressed.connect(_on_continue_pressed)

	# セーブ/ロードポップアップ
	var SaveLoadScript = load("res://scripts/save_load_popup.gd")
	save_load_popup = CanvasLayer.new()
	save_load_popup.set_script(SaveLoadScript)
	add_child(save_load_popup)
	save_load_popup.load_completed.connect(_on_load_completed)


func _on_start_pressed() -> void:
	AudioManager.play_sfx("click")
	_show_difficulty_select()


func _show_difficulty_select() -> void:
	var DiffMgr = preload("res://scripts/difficulty_manager.gd")

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	# 中央寄せコンテナ
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	overlay.add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "難易度を選択"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title_label)

	# 難易度ごとのボタン色
	var btn_colors := {"easy": "green", "normal": "blue", "hard": "yellow"}

	for diff_id in DiffMgr.DIFFICULTIES:
		var diff = DiffMgr.DIFFICULTIES[diff_id]
		var btn = Button.new()
		btn.text = "%s %s\n%s" % [diff.get("icon", ""), diff.get("name", ""), diff.get("description", "")]
		btn.custom_minimum_size = Vector2(500, 100)
		btn.add_theme_font_size_override("font_size", 26)
		KenneyTheme.apply_button_style(btn, btn_colors.get(diff_id, "blue"))
		var did = diff_id
		btn.pressed.connect(func():
			overlay.queue_free()
			_start_game_with_difficulty(did))
		vbox.add_child(btn)

	# 戻るボタン
	var close_btn = Button.new()
	close_btn.text = "戻る"
	close_btn.custom_minimum_size = Vector2(500, 70)
	close_btn.add_theme_font_size_override("font_size", 24)
	KenneyTheme.apply_button_style(close_btn, "grey")
	close_btn.pressed.connect(func():
		overlay.queue_free())
	vbox.add_child(close_btn)


func _start_game_with_difficulty(difficulty_id: String) -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	DifficultyManager.set_difficulty(difficulty_id)
	DifficultyManager.apply_initial_params(GameState)
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	save_load_popup.show_popup("load")


func _on_load_completed(_slot: String) -> void:
	get_node("/root/Main").change_scene("res://scenes/game.tscn")
