extends Control

var save_load_popup: Node


func _ready() -> void:
	# スタートボタンにKenneyグリーンスタイルを適用
	KenneyTheme.apply_button_style($VBox/StartButton, "green")
	$VBox/StartButton.pressed.connect(_on_start_pressed)
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
	var start_idx := $VBox/StartButton.get_index()
	$VBox.add_child(continue_btn)
	$VBox.move_child(continue_btn, start_idx + 1)

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
	# 難易度選択ポップアップ（コードで生成）
	var DiffMgr = preload("res://scripts/difficulty_manager.gd")
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	add_child(overlay)

	var panel = PanelContainer.new()
	panel.anchor_left = 0.05
	panel.anchor_right = 0.95
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	KenneyTheme.apply_panel_style(panel, "popup")
	overlay.add_child(panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)

	var title_label = Label.new()
	title_label.text = "難易度を選択"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	vbox.add_child(title_label)

	# 難易度ボタン
	for diff_id in DiffMgr.DIFFICULTIES:
		var diff = DiffMgr.DIFFICULTIES[diff_id]
		var btn = Button.new()
		btn.text = "%s %s — %s" % [diff.get("icon", ""), diff.get("name", ""), diff.get("description", "")]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		var did = diff_id
		btn.pressed.connect(func():
			overlay.queue_free()
			_start_game_with_difficulty(did, ""))
		vbox.add_child(btn)

	# チャレンジモードセクション
	var sep = HSeparator.new()
	vbox.add_child(sep)

	var challenge_title = Label.new()
	challenge_title.text = "🎯 チャレンジモード"
	challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_title.add_theme_font_size_override("font_size", 24)
	challenge_title.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	vbox.add_child(challenge_title)

	for ch_id in DiffMgr.CHALLENGES:
		var ch = DiffMgr.CHALLENGES[ch_id]
		var btn = Button.new()
		btn.text = "%s %s — %s" % [ch.get("icon", ""), ch.get("name", ""), ch.get("description", "")]
		btn.custom_minimum_size = Vector2(0, 56)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(0.90, 0.80, 0.50))
		var cid = ch_id
		btn.pressed.connect(func():
			overlay.queue_free()
			_start_game_with_difficulty("normal", cid))
		vbox.add_child(btn)

	# デイリーチャレンジ
	var daily_btn = Button.new()
	daily_btn.text = "📅 デイリーチャレンジ（今日のシード値で挑戦）"
	daily_btn.custom_minimum_size = Vector2(0, 56)
	daily_btn.add_theme_font_size_override("font_size", 20)
	daily_btn.add_theme_color_override("font_color", Color(0.60, 0.85, 0.90))
	daily_btn.pressed.connect(func():
		overlay.queue_free()
		_start_daily_challenge())
	vbox.add_child(daily_btn)

	# 閉じるボタン
	var close_btn = Button.new()
	close_btn.text = "戻る"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 22)
	KenneyTheme.apply_button_style(close_btn, "red")
	close_btn.pressed.connect(func():
		overlay.queue_free())
	vbox.add_child(close_btn)


func _start_game_with_difficulty(difficulty_id: String, challenge_id: String) -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	DifficultyManager.set_difficulty(difficulty_id)
	DifficultyManager.set_challenge(challenge_id)
	DifficultyManager.apply_initial_params(GameState)
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _start_daily_challenge() -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	DifficultyManager.setup_daily_challenge()
	DifficultyManager.apply_initial_params(GameState)
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _on_continue_pressed() -> void:
	AudioManager.play_sfx("click")
	save_load_popup.show_popup("load")


func _on_load_completed(_slot: String) -> void:
	get_node("/root/Main").change_scene("res://scenes/game.tscn")
