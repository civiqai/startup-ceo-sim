extends Control
## ゲーム結果画面 — エンディング分岐対応

@onready var result_icon := $SafeArea/VBox/ResultIcon
@onready var result_title := $SafeArea/VBox/ResultTitle
@onready var stats_label := $SafeArea/VBox/StatsLabel

var ending_data: Dictionary = {}


func _ready() -> void:
	$SafeArea/VBox/RetryButton.pressed.connect(_on_retry)
	$SafeArea/VBox/TitleButton.pressed.connect(_on_title)

	# エンディング判定
	var EndingManager = preload("res://scripts/ending_manager.gd")
	var em = EndingManager.new()

	# GameStateから結果取得
	if GameState.valuation >= GameState.IPO_THRESHOLD:
		ending_data = em.get_ending("ipo")
	elif GameState.cash <= 0:
		ending_data = em.get_ending("bankruptcy")
	else:
		# 特殊エンディング（game.gdから渡されたIDがあればそれを使う）
		var forced_ending = GameState.get_meta("forced_ending", "")
		if forced_ending != "":
			ending_data = em.get_ending(forced_ending)
		else:
			ending_data = em.get_ending("voluntary")

	# シェアボタンを追加（RetryButtonの前に挿入）
	var share_btn = Button.new()
	share_btn.name = "ShareBtn"
	share_btn.text = "📱 SNSでシェア"
	share_btn.custom_minimum_size = Vector2(0, 56)
	share_btn.add_theme_font_size_override("font_size", 26)
	share_btn.add_theme_color_override("font_color", Color(1, 1, 1))
	KenneyTheme.apply_button_style(share_btn, "blue")
	share_btn.pressed.connect(_on_share)
	var retry_idx = $SafeArea/VBox/RetryButton.get_index()
	$SafeArea/VBox.add_child(share_btn)
	$SafeArea/VBox.move_child(share_btn, retry_idx)

	_show_ending()
	em.queue_free()

	stats_label.text = """経過: %dヶ月
最終資金: %d万円
ユーザー数: %s人
チーム: %d人
UX: %d / デザイン: %d / 利益率: %d / 知名度: %d
時価総額: %s万円
ランク: %s""" % [
		GameState.month,
		GameState.cash,
		_format_number(GameState.users),
		GameState.team_size,
		GameState.product_ux,
		GameState.product_design,
		GameState.product_margin,
		GameState.product_awareness,
		_format_number(GameState.valuation),
		ending_data.get("rank", "-"),
	]


func _show_ending() -> void:
	result_icon.text = ending_data.get("icon", "?")
	result_title.text = ending_data.get("title", "ゲーム終了")
	var color: Color = ending_data.get("color", Color(1, 1, 1))
	result_title.add_theme_color_override("font_color", color)
	stats_label.add_theme_color_override("font_color", color.lightened(0.3))

	# エピローグを追加表示
	var epilogue = ending_data.get("epilogue", "")
	if epilogue != "":
		# EpilogueLabel がなければ動的に追加
		if not has_node("SafeArea/VBox/EpilogueLabel"):
			var epilogue_label = Label.new()
			epilogue_label.name = "EpilogueLabel"
			epilogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			epilogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			epilogue_label.add_theme_font_size_override("font_size", 24)
			epilogue_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
			# StatsLabelの後に挿入
			var idx = $SafeArea/VBox/StatsLabel.get_index() + 1
			$SafeArea/VBox.add_child(epilogue_label)
			$SafeArea/VBox.move_child(epilogue_label, idx)
		$SafeArea/VBox/EpilogueLabel.text = epilogue

	# BGM選択
	var rank = ending_data.get("rank", "D")
	if rank in ["S", "A"]:
		AudioManager.play_bgm("win")
	else:
		AudioManager.play_bgm("lose")


func _format_number(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 100000000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)


func _on_share() -> void:
	AudioManager.play_sfx("click")
	var ending_name = ending_data.get("name", ending_data.get("title", "ゲーム終了"))
	var rank = ending_data.get("rank", "-")
	var text := "🎮 IT社長物語をプレイ！\n"
	text += "結果: %s (ランク%s)\n" % [ending_name, rank]
	text += "%dヶ月で時価総額%s万円を達成！\n" % [GameState.month, _format_number(GameState.valuation)]
	text += "チーム%d人 / ユーザー%s人\n" % [GameState.team_size, _format_number(GameState.users)]
	text += "#IT社長物語 #スタートアップシミュレーション"
	var encoded = text.uri_encode()
	OS.shell_open("https://twitter.com/intent/tweet?text=" + encoded)


func _on_retry() -> void:
	AudioManager.play_sfx("click")
	GameState.reset()
	get_node("/root/Main").change_scene("res://scenes/game.tscn")


func _on_title() -> void:
	AudioManager.play_sfx("click")
	get_node("/root/Main").change_scene("res://scenes/title.tscn")
