extends CanvasLayer
## 双六（投資家ロード）ポップアップ — 3ダイス + タイプ別ボード
## サイコロ3個を振ってボード上の到着マスを決定し、効果を適用する

signal popup_closed(result_text: String)

const FundraiseTypes = preload("res://scripts/fundraise_types.gd")

var _is_open := false
var _result_text := ""
var _selected_type := ""

# Dice state
var _dice_values: Array[int] = [0, 0, 0]  # 3ダイスの最終値
var _rolling := false
var _roll_count := 0
var _dice_confirmed := 0  # 停止済みダイス数 (0→1→2→3)

# Movement
var _target_position := 0
var _move_timer: Timer
var _current_display_pos := 0
var _moves_remaining := 0

# Timers
var _roll_timer: Timer

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _info_label: Label
var _board_container: Control
var _square_nodes: Array[Control] = []
var _token_label: Label
var _dice_container: HBoxContainer  # 3ダイスラベルの親
var _dice_labels: Array[Label] = []  # 3つのダイス表示ラベル
var _sum_label: Label  # 合計表示
var _roll_button: Button
var _effect_label: Label
var _ok_button: Button
var _panel_style: StyleBox

# Board layout
const SQUARE_W := 130
const SQUARE_H := 65
const GAP := 8
const BOARD_COLS := 4

# Dice animation thresholds
const DICE_STOP_TICKS := [12, 16, 20]


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false

	_roll_timer = Timer.new()
	_roll_timer.one_shot = false
	_roll_timer.timeout.connect(_on_roll_tick)
	add_child(_roll_timer)

	_move_timer = Timer.new()
	_move_timer.one_shot = true
	_move_timer.timeout.connect(_on_move_step)
	add_child(_move_timer)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func show_board(type_id: String) -> void:
	_selected_type = type_id
	_result_text = ""
	_rolling = false
	_roll_count = 0
	_dice_confirmed = 0
	_dice_values = [0, 0, 0]
	_moves_remaining = 0
	_current_display_pos = -1  # 初期位置なし

	# タイプ情報でUI更新
	var type_data = FundraiseTypes.get_type(type_id)
	_title_label.text = "%s %s" % [type_data.get("icon", "🎲"), type_data.get("name", "資金調達")]

	# パネルのボーダーカラーをタイプの色に変更
	var type_color: Color = type_data.get("color", Color(0.25, 0.45, 0.30))
	if _panel_style is StyleBoxFlat:
		_panel_style.border_color = type_color

	# ダイス表示リセット
	for i in range(3):
		_dice_labels[i].text = "⬜ ?"
	_sum_label.text = ""
	_sum_label.visible = false

	_roll_button.visible = true
	_roll_button.disabled = false
	_effect_label.visible = false
	_ok_button.visible = false
	_info_label.text = "サイコロを振って投資家ロードを進もう！"

	# ボードを再構築（タイプ別マス）
	_rebuild_board()

	_panel_root.visible = true
	_is_open = true


func get_result_text() -> String:
	return _result_text


# --- Dice Rolling (3d6) ---

func _on_roll_pressed() -> void:
	if _rolling:
		return
	_rolling = true
	_roll_button.disabled = true
	_roll_count = 0
	_dice_confirmed = 0

	# 最終値を先に決定
	for i in range(3):
		_dice_values[i] = randi_range(1, 6)

	_roll_timer.wait_time = 0.05
	_roll_timer.start()
	AudioManager.play_sfx("click")


func _on_roll_tick() -> void:
	_roll_count += 1

	# 各ダイスの更新（未停止のみランダム表示）
	for i in range(3):
		if _dice_confirmed <= i:
			# まだ回転中
			_dice_labels[i].text = "🎲 %d" % randi_range(1, 6)

	# ダイス停止チェック
	for i in range(3):
		if _dice_confirmed == i and _roll_count >= DICE_STOP_TICKS[i]:
			_dice_labels[i].text = "🎲 %d" % _dice_values[i]
			_dice_confirmed += 1
			AudioManager.play_sfx("click")

	# 速度を徐々に落とす
	if _roll_count >= 10:
		_roll_timer.wait_time = 0.08
	if _roll_count >= 15:
		_roll_timer.wait_time = 0.12

	# 全ダイス停止
	if _dice_confirmed >= 3:
		_roll_timer.stop()
		_rolling = false
		_roll_button.visible = false

		var dice_sum = _dice_values[0] + _dice_values[1] + _dice_values[2]
		_sum_label.text = "合計: %d + %d + %d = %d" % [_dice_values[0], _dice_values[1], _dice_values[2], dice_sum]
		_sum_label.visible = true

		_target_position = FundraiseTypes.dice_sum_to_position(_selected_type, dice_sum, GameState)
		_info_label.text = "🎲 %d が出た！" % dice_sum

		# 少し間を置いてから移動開始
		_current_display_pos = -1
		_moves_remaining = _target_position + 1  # 0番マスから target まで
		_move_timer.wait_time = 0.5
		_move_timer.start()


# --- Board Movement ---

func _on_move_step() -> void:
	if _moves_remaining <= 0:
		_on_movement_complete()
		return

	_current_display_pos += 1
	_moves_remaining -= 1
	_update_board_display()
	AudioManager.play_sfx("click")

	if _moves_remaining > 0:
		_move_timer.wait_time = 0.25
		_move_timer.start()
	else:
		# 最後のマスに到着 — 少し間を置いて効果表示
		_move_timer.wait_time = 0.5
		_move_timer.start()


func _on_movement_complete() -> void:
	var type_data = FundraiseTypes.get_type(_selected_type)
	_result_text = FundraiseTypes.apply_effect(_selected_type, _target_position, GameState)

	# 資金調達トラッキング更新
	GameState.fundraise_cooldown = type_data.get("cooldown", 2)
	GameState.fundraise_count += 1
	GameState.state_changed.emit()

	var square = FundraiseTypes.get_square(_selected_type, _target_position)
	_info_label.text = "【%s】に到着！" % square["name"]
	_effect_label.text = _result_text
	_effect_label.visible = true
	_ok_button.visible = true
	AudioManager.play_sfx("notification")


func _on_ok_pressed() -> void:
	if not _is_open:
		return
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit(_result_text)


# --- Board Display ---

func _rebuild_board() -> void:
	# 既存のマスノードを削除
	for node in _square_nodes:
		node.queue_free()
	_square_nodes.clear()

	# トークンが既にある場合は一旦非表示
	if _token_label:
		_token_label.visible = false

	# 矢印等の既存子ノードも削除（トークン以外）
	var children_to_remove: Array[Node] = []
	for child in _board_container.get_children():
		if child != _token_label:
			children_to_remove.append(child)
	for child in children_to_remove:
		child.queue_free()

	# 新しいマスを生成
	var squares = FundraiseTypes.get_squares(_selected_type)
	var square_count = squares.size()

	for i in range(square_count):
		var square_data = squares[i]
		var pos = _get_square_position(i, square_count)

		var square_ctrl = Control.new()
		square_ctrl.position = pos
		square_ctrl.size = Vector2(SQUARE_W, SQUARE_H)
		_board_container.add_child(square_ctrl)

		var bg = ColorRect.new()
		bg.name = "Bg"
		bg.size = Vector2(SQUARE_W, SQUARE_H)
		bg.color = square_data.get("color", Color(0.3, 0.3, 0.3)).darkened(0.55)
		square_ctrl.add_child(bg)

		var lbl = Label.new()
		lbl.text = "%s %s" % [square_data.get("icon", ""), square_data.get("name", "")]
		lbl.position = Vector2(0, 0)
		lbl.size = Vector2(SQUARE_W, SQUARE_H)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		square_ctrl.add_child(lbl)

		_square_nodes.append(square_ctrl)

	# 矢印を追加
	_add_arrows(square_count)

	# トークンを最前面に移動
	if _token_label:
		_board_container.move_child(_token_label, _board_container.get_child_count() - 1)


func _update_board_display() -> void:
	var squares = FundraiseTypes.get_squares(_selected_type)

	for i in range(_square_nodes.size()):
		var node = _square_nodes[i]
		var square = squares[i]
		var bg: ColorRect = node.get_node("Bg")

		if i == _current_display_pos:
			bg.color = square.get("color", Color(0.4, 0.4, 0.4))
			node.modulate = Color(1.0, 1.0, 1.0, 1.0)
		else:
			bg.color = square.get("color", Color(0.4, 0.4, 0.4)).darkened(0.55)
			node.modulate = Color(0.65, 0.65, 0.65, 1.0)

	# トークン位置更新
	if _current_display_pos >= 0 and _current_display_pos < _square_nodes.size():
		var target = _square_nodes[_current_display_pos]
		_token_label.position = target.position + Vector2(SQUARE_W / 2.0 - 10, -18)
		_token_label.visible = true
	else:
		_token_label.visible = false


func _get_square_position(index: int, total: int) -> Vector2:
	# Snake layout:
	#   [0] → [1] → [2] → [3]
	#                         ↓
	#   [7] ← [6] ← [5] ← [4]
	var col: int
	var row: int
	if index < BOARD_COLS:
		row = 0
		col = index
	else:
		row = 1
		col = (total - 1) - index
	return Vector2(col * (SQUARE_W + GAP), row * (SQUARE_H + GAP + 16))


# --- UI Construction ---

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
	_panel_root.add_child(_overlay)

	# 中央配置
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# パネル（Kenney UIテクスチャ使用）
	_panel_style = KenneyTheme.make_popup_panel_style()

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", _panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "🎲 投資家ロード"
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.25, 0.40, 0.30))
	vbox.add_child(sep)

	# 説明テキスト
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
	_info_label.add_theme_font_size_override("font_size", 22)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_label)

	# ボードエリア
	var board_width = BOARD_COLS * SQUARE_W + (BOARD_COLS - 1) * GAP
	var board_height = 2 * SQUARE_H + GAP + 16 + 20  # +20 for token space
	_board_container = Control.new()
	_board_container.custom_minimum_size = Vector2(board_width, board_height)
	vbox.add_child(_board_container)

	# プレイヤートークン（▼マーカー）— ボードコンテナに常駐
	_token_label = Label.new()
	_token_label.text = "▼"
	_token_label.add_theme_font_size_override("font_size", 18)
	_token_label.add_theme_color_override("font_color", Color(1.0, 0.30, 0.25))
	_token_label.visible = false
	_board_container.add_child(_token_label)

	# 3ダイス表示エリア
	_dice_container = HBoxContainer.new()
	_dice_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_dice_container.add_theme_constant_override("separation", 16)
	vbox.add_child(_dice_container)

	_dice_labels.clear()
	for i in range(3):
		var dice_lbl = Label.new()
		dice_lbl.text = "⬜ ?"
		dice_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		dice_lbl.add_theme_font_size_override("font_size", 40)
		dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dice_lbl.custom_minimum_size = Vector2(100, 0)
		_dice_container.add_child(dice_lbl)
		_dice_labels.append(dice_lbl)

	# 合計表示
	_sum_label = Label.new()
	_sum_label.text = ""
	_sum_label.add_theme_color_override("font_color", Color(0.95, 0.90, 0.55))
	_sum_label.add_theme_font_size_override("font_size", 28)
	_sum_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sum_label.visible = false
	vbox.add_child(_sum_label)

	# サイコロを振るボタン（Kenney グリーンスタイル）
	_roll_button = Button.new()
	_roll_button.text = "🎲 サイコロを振る"
	_roll_button.custom_minimum_size = Vector2(0, 58)
	_roll_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_roll_button.add_theme_font_size_override("font_size", 26)
	KenneyTheme.apply_button_style(_roll_button, "green")
	_roll_button.pressed.connect(_on_roll_pressed)
	vbox.add_child(_roll_button)

	# 効果テキスト
	_effect_label = Label.new()
	_effect_label.add_theme_color_override("font_color", Color(0.50, 0.85, 0.65))
	_effect_label.add_theme_font_size_override("font_size", 26)
	_effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_effect_label.visible = false
	vbox.add_child(_effect_label)

	# OKボタン
	_ok_button = Button.new()
	_ok_button.text = "OK"
	_ok_button.custom_minimum_size = Vector2(0, 54)
	_ok_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	_ok_button.add_theme_font_size_override("font_size", 26)
	_ok_button.pressed.connect(_on_ok_pressed)
	_ok_button.visible = false
	vbox.add_child(_ok_button)


func _add_arrows(square_count: int) -> void:
	var arrow_color = Color(0.45, 0.50, 0.55, 0.8)
	# 隣接マス間の中点に矢印を配置
	var connections := [
		[0, 1, "→"], [1, 2, "→"], [2, 3, "→"],
		[3, 4, "↓"],
		[4, 5, "←"], [5, 6, "←"], [6, 7, "←"],
		[7, 0, "↑"],
	]
	for conn in connections:
		if conn[0] >= square_count or conn[1] >= square_count:
			continue
		var from_center = _get_square_position(conn[0], square_count) + Vector2(SQUARE_W, SQUARE_H) / 2.0
		var to_center = _get_square_position(conn[1], square_count) + Vector2(SQUARE_W, SQUARE_H) / 2.0
		var mid = (from_center + to_center) / 2.0

		var arrow = Label.new()
		arrow.text = conn[2]
		arrow.add_theme_font_size_override("font_size", 16)
		arrow.add_theme_color_override("font_color", arrow_color)
		arrow.position = mid - Vector2(5, 10)
		_board_container.add_child(arrow)
