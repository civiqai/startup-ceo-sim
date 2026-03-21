extends CanvasLayer
## 採用ポップアップ — 採用チャネル選択 + 候補者3人から選択

signal hire_completed(member_data: Dictionary, channel: String, total_cost: int)
signal hire_cancelled()

var _is_open := false
var _current_channel := "referral"  # referral, agent, scout
var _candidates: Array = []  # 現在表示中の候補者データ
var _avatar_textures: Dictionary = {}  # index -> TextureRect (アバター画像差し替え用)

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _channel_container: HBoxContainer
var _channel_buttons: Dictionary = {}  # channel_id -> Button
var _candidates_container: VBoxContainer
var _cancel_button: Button
var _scroll: ScrollContainer

# スタイル定数
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_PANEL_BORDER := Color(0.30, 0.45, 0.55)
const COLOR_TITLE := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_ACCENT := Color(0.35, 0.65, 0.85)
const COLOR_HIRE_BTN := Color(0.18, 0.48, 0.32)
const COLOR_HIRE_BTN_HOVER := Color(0.22, 0.55, 0.38)
const COLOR_CHANNEL_ACTIVE := Color(0.25, 0.50, 0.70)
const COLOR_CHANNEL_INACTIVE := Color(0.18, 0.20, 0.26)

# チャネル定義
const CHANNELS := {
	"referral": {
		"name": "リファラル",
		"fee_rate": 0.1,
		"level_min": 1,
		"level_max": 4,
		"description": "手数料10%",
		"unlock_condition": "",
		"unlock_text": "",
	},
	"agent": {
		"name": "エージェント",
		"fee_rate": 0.3,
		"level_min": 1,
		"level_max": 5,
		"description": "手数料30%",
		"unlock_condition": "team_size_3",
		"unlock_text": "🔒 チーム3人以上で解放",
	},
	"scout": {
		"name": "スカウト",
		"fee_rate": 0.5,
		"level_min": 3,
		"level_max": 5,
		"description": "手数料50% 高品質",
		"unlock_condition": "reputation_50",
		"unlock_text": "🔒 評判50以上で解放",
	},
}

# スキルタイプ別カラー（アバター背景用）
const SKILL_COLORS := {
	"engineer": Color(0.25, 0.50, 0.80),
	"designer": Color(0.75, 0.40, 0.60),
	"marketer": Color(0.80, 0.55, 0.20),
	"bizdev": Color(0.40, 0.65, 0.40),
	"pm": Color(0.55, 0.45, 0.75),
}

# ロック中チャネルのグレー色
const COLOR_CHANNEL_LOCKED := Color(0.12, 0.13, 0.17)
const COLOR_TEXT_LOCKED := Color(0.45, 0.45, 0.50)

# スキルタイプ絵文字
const SKILL_EMOJI := {
	"engineer": "🔧",
	"designer": "🎨",
	"marketer": "📢",
	"bizdev": "💼",
	"pm": "📋",
}

# スキルタイプ日本語名
const SKILL_NAMES := {
	"engineer": "エンジニア",
	"designer": "デザイナー",
	"marketer": "マーケター",
	"bizdev": "BizDev",
	"pm": "PM",
}

# パーソナリティ日本語名
const PERSONALITY_NAMES := {
	"diligent": "勤勉",
	"creative": "クリエイティブ",
	"mood_maker": "ムードメーカー",
	"analytical": "分析的",
	"leader": "リーダー気質",
}

# 候補者名プール
const FIRST_NAMES := [
	"太郎", "花子", "一郎", "美咲", "翔太",
	"遥", "大輝", "さくら", "健太", "優子",
	"拓海", "結衣", "蓮", "陽菜", "悠真",
	"凛", "奏太", "葵", "颯", "琴音",
	"駿", "彩花", "和也", "麻衣", "智也",
	"真由", "直樹", "愛", "哲也", "恵",
]

const LAST_NAMES := [
	"田中", "鈴木", "佐藤", "高橋", "伊藤",
	"渡辺", "山本", "中村", "小林", "加藤",
	"吉田", "山田", "松本", "井上", "木村",
	"林", "斎藤", "清水", "山口", "森",
]


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


## 候補者を表示してポップアップを開く
func show_candidates(candidates: Array) -> void:
	_candidates = candidates
	_current_channel = "referral"
	_regenerate_candidates()
	_update_channel_buttons()
	_panel_root.visible = true
	_is_open = true


## チャネルのアンロック状態を確認
func _is_channel_unlocked(channel_id: String) -> bool:
	var ch = CHANNELS.get(channel_id, {})
	var condition = ch.get("unlock_condition", "")
	if condition == "":
		return true
	match condition:
		"team_size_3":
			return GameState.team_size >= 3
		"reputation_50":
			return GameState.reputation >= 50
	return false


## 指定チャネルのレベル範囲でランダム候補者3人を生成
func generate_candidates_for_channel(channel: String) -> Array:
	# チュートリアル月0: PM確定候補
	if GameState.tutorial_month == 0:
		return _generate_tutorial_pm_candidates()

	var channel_data: Dictionary = CHANNELS.get(channel, CHANNELS["agent"])
	var level_min: int = channel_data["level_min"]
	var level_max: int = channel_data["level_max"]

	var skill_types := ["engineer", "designer", "marketer", "bizdev", "pm"]
	var personalities := ["diligent", "creative", "mood_maker", "analytical", "leader"]

	var result: Array = []
	for i in range(3):
		var skill_type: String = skill_types[randi() % skill_types.size()]
		var personality: String = personalities[randi() % personalities.size()]
		var level: int = randi_range(level_min, level_max)
		var first: String = FIRST_NAMES[randi() % FIRST_NAMES.size()]
		var last: String = LAST_NAMES[randi() % LAST_NAMES.size()]
		var full_name: String = last + " " + first

		# 給与計算（TeamMemberのロジックに準拠）
		var base_salaries := {
			"engineer": 400,
			"designer": 350,
			"marketer": 350,
			"bizdev": 400,
			"pm": 450,
		}
		var base_salary: int = base_salaries.get(skill_type, 400)
		var salary: int = base_salary + level * 100

		var avatar_id: int = randi_range(1, 70)
		var candidate := {
			"name": full_name,
			"skill_type": skill_type,
			"skill_level": level,
			"personality": personality,
			"salary": salary,
			"channel": channel,
			"avatar_id": avatar_id,
		}
		result.append(candidate)

	return result


## チュートリアル月0: PM確定候補を3人生成
func _generate_tutorial_pm_candidates() -> Array:
	var result: Array = []
	var personalities := ["diligent", "creative", "mood_maker", "analytical", "leader"]
	for i in range(3):
		var first: String = FIRST_NAMES[randi() % FIRST_NAMES.size()]
		var last: String = LAST_NAMES[randi() % LAST_NAMES.size()]
		var personality: String = personalities[randi() % personalities.size()]
		var level: int = randi_range(2, 3)  # チュートリアルなので少し良い
		var salary: int = 450 + level * 100  # PM base
		result.append({
			"name": last + " " + first,
			"skill_type": "pm",
			"skill_level": level,
			"personality": personality,
			"salary": salary,
			"channel": "referral",
			"avatar_id": randi_range(1, 70),
		})
	return result


func _regenerate_candidates() -> void:
	_candidates = generate_candidates_for_channel(_current_channel)
	_rebuild_candidate_cards()


func _update_channel_buttons() -> void:
	for channel_id in _channel_buttons:
		var btn: Button = _channel_buttons[channel_id]
		var is_active = (channel_id == _current_channel)
		var is_unlocked = _is_channel_unlocked(channel_id)
		var ch_data: Dictionary = CHANNELS[channel_id]
		var style := StyleBoxFlat.new()
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6

		if not is_unlocked:
			# ロック中: グレーアウト + 解放条件テキスト
			style.bg_color = COLOR_CHANNEL_LOCKED
			style.border_width_bottom = 0
			btn.add_theme_color_override("font_color", COLOR_TEXT_LOCKED)
			btn.text = "%s\n%s" % [ch_data["name"], ch_data["unlock_text"]]
			btn.disabled = true
		elif is_active:
			style.bg_color = COLOR_CHANNEL_ACTIVE
			style.border_width_bottom = 3
			style.border_color = Color(0.40, 0.75, 0.95)
			btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
			btn.text = "%s\n%s" % [ch_data["name"], ch_data["description"]]
			btn.disabled = false
		else:
			style.bg_color = COLOR_CHANNEL_INACTIVE
			style.border_width_bottom = 0
			btn.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
			btn.text = "%s\n%s" % [ch_data["name"], ch_data["description"]]
			btn.disabled = false

		btn.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate()
		hover_style.bg_color = style.bg_color.lightened(0.1)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		# disabled style も設定（ロック中のグレー表示用）
		var disabled_style := style.duplicate()
		btn.add_theme_stylebox_override("disabled", disabled_style)


func _rebuild_candidate_cards() -> void:
	# 既存カードをクリア
	_avatar_textures.clear()
	for child in _candidates_container.get_children():
		child.queue_free()

	var channel_data: Dictionary = CHANNELS.get(_current_channel, CHANNELS["agent"])
	var fee_rate: float = channel_data["fee_rate"]

	for i in range(_candidates.size()):
		var candidate: Dictionary = _candidates[i]
		var card := _build_candidate_card(candidate, fee_rate, i)
		_candidates_container.add_child(card)


func _build_candidate_card(candidate: Dictionary, fee_rate: float, index: int) -> PanelContainer:
	var skill_type: String = candidate["skill_type"]
	var level: int = candidate["skill_level"]
	var personality: String = candidate["personality"]
	var salary: int = candidate["salary"]
	var cand_name: String = candidate["name"]
	var hire_fee: int = int(salary * fee_rate)

	var emoji: String = SKILL_EMOJI.get(skill_type, "❓")
	var skill_name: String = SKILL_NAMES.get(skill_type, skill_type)
	var personality_name: String = PERSONALITY_NAMES.get(personality, personality)
	var stars := "★".repeat(level)

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.12, 0.14, 0.20)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	card_style.border_color = COLOR_ACCENT
	card_style.content_margin_left = 16
	card_style.content_margin_top = 14
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 14

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 8)
	card.add_child(outer_vbox)

	# 上部: アバター + 情報のHBoxContainer
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(hbox)

	# アバター（画像 + フォールバックのイニシャル）
	var avatar_id: int = candidate.get("avatar_id", 0)
	var avatar_container := PanelContainer.new()
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = SKILL_COLORS.get(skill_type, Color(0.3, 0.3, 0.3))
	avatar_style.corner_radius_top_left = 28
	avatar_style.corner_radius_top_right = 28
	avatar_style.corner_radius_bottom_left = 28
	avatar_style.corner_radius_bottom_right = 28
	avatar_container.add_theme_stylebox_override("panel", avatar_style)
	avatar_container.custom_minimum_size = Vector2(56, 56)
	avatar_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	avatar_container.clip_contents = true
	hbox.add_child(avatar_container)

	# 固定サイズ用の内部コンテナ
	var avatar_sizer := Control.new()
	avatar_sizer.custom_minimum_size = Vector2(56, 56)
	avatar_sizer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	avatar_sizer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	avatar_container.add_child(avatar_sizer)

	# イニシャル（フォールバック表示）
	var initial_label := Label.new()
	initial_label.text = cand_name.left(1)
	initial_label.add_theme_font_size_override("font_size", 28)
	initial_label.add_theme_color_override("font_color", Color(1, 1, 1))
	initial_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_sizer.add_child(initial_label)

	# アバター画像（取得後にイニシャルの上に重ねる）
	var avatar_tex_rect := TextureRect.new()
	avatar_tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	avatar_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	avatar_tex_rect.visible = false
	avatar_sizer.add_child(avatar_tex_rect)
	_avatar_textures[index] = avatar_tex_rect

	# AvatarLoaderで画像を非同期取得
	if avatar_id > 0:
		AvatarLoader.get_avatar(avatar_id, func(tex: Variant) -> void:
			if is_instance_valid(avatar_tex_rect) and tex != null:
				avatar_tex_rect.texture = tex
				avatar_tex_rect.visible = true
				initial_label.visible = false
		)

	# 右側: テキスト情報
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# 1行目: 絵文字 + 名前 + レベル
	var name_label := Label.new()
	name_label.text = "%s %s  Lv.%s" % [emoji, cand_name, stars]
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	vbox.add_child(name_label)

	# 2行目: スキルタイプ / パーソナリティ
	var detail_label := Label.new()
	detail_label.text = "%s / %s" % [skill_name, personality_name]
	detail_label.add_theme_font_size_override("font_size", 20)
	detail_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	vbox.add_child(detail_label)

	# 3行目: 年収 / 採用費
	var cost_label := Label.new()
	cost_label.text = "年収: %d万円 / 採用費: %d万円" % [salary, hire_fee]
	cost_label.add_theme_font_size_override("font_size", 20)
	cost_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	vbox.add_child(cost_label)

	# 採用するボタン
	var hire_btn_style := StyleBoxFlat.new()
	hire_btn_style.bg_color = COLOR_HIRE_BTN
	hire_btn_style.corner_radius_top_left = 8
	hire_btn_style.corner_radius_top_right = 8
	hire_btn_style.corner_radius_bottom_left = 8
	hire_btn_style.corner_radius_bottom_right = 8
	hire_btn_style.content_margin_top = 6
	hire_btn_style.content_margin_bottom = 6

	var hire_btn_hover := hire_btn_style.duplicate()
	hire_btn_hover.bg_color = COLOR_HIRE_BTN_HOVER

	var hire_btn := Button.new()
	hire_btn.text = "採用する"
	hire_btn.custom_minimum_size = Vector2(0, 48)
	hire_btn.add_theme_font_size_override("font_size", 22)
	hire_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	hire_btn.add_theme_stylebox_override("normal", hire_btn_style)
	hire_btn.add_theme_stylebox_override("hover", hire_btn_hover)
	hire_btn.add_theme_stylebox_override("pressed", hire_btn_hover)
	hire_btn.pressed.connect(_on_hire_pressed.bind(index))
	outer_vbox.add_child(hire_btn)

	return card


func _on_channel_pressed(channel_id: String) -> void:
	if channel_id == _current_channel:
		return
	if not _is_channel_unlocked(channel_id):
		return
	AudioManager.play_sfx("click")
	_current_channel = channel_id
	_update_channel_buttons()
	_regenerate_candidates()


func _on_hire_pressed(index: int) -> void:
	if not _is_open or index >= _candidates.size():
		return
	AudioManager.play_sfx("click")

	var candidate: Dictionary = _candidates[index]
	var channel_data: Dictionary = CHANNELS.get(_current_channel, CHANNELS["agent"])
	var fee_rate: float = channel_data["fee_rate"]
	var hire_fee: int = int(candidate["salary"] * fee_rate)

	_panel_root.visible = false
	_is_open = false
	hire_completed.emit(candidate, _current_channel, hire_fee)


func _on_cancel_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	_panel_root.visible = false
	_is_open = false
	hire_cancelled.emit()


## UIをコードで構築
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

	# 中央配置コンテナ
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# メインパネル（Kenney UIテクスチャ使用）
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	# メインVBox
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "👥 人材を採用"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# チャネル選択セクション
	var channel_section_label := Label.new()
	channel_section_label.text = "【採用チャネル選択】"
	channel_section_label.add_theme_font_size_override("font_size", 20)
	channel_section_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	channel_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(channel_section_label)

	# チャネルボタン
	_channel_container = HBoxContainer.new()
	_channel_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_channel_container.add_theme_constant_override("separation", 10)
	vbox.add_child(_channel_container)

	_channel_buttons.clear()
	var channel_order := ["referral", "agent", "scout"]
	for channel_id in channel_order:
		var ch_data: Dictionary = CHANNELS[channel_id]
		var btn := Button.new()
		btn.text = "%s\n%s" % [ch_data["name"], ch_data["description"]]
		btn.custom_minimum_size = Vector2(180, 56)
		btn.add_theme_font_size_override("font_size", 18)
		btn.pressed.connect(_on_channel_pressed.bind(channel_id))
		_channel_container.add_child(btn)
		_channel_buttons[channel_id] = btn

	# 候補者スクロールエリア
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 680)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_candidates_container = VBoxContainer.new()
	_candidates_container.add_theme_constant_override("separation", 12)
	_candidates_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_candidates_container)

	# キャンセルボタン（Kenney UIスタイル）
	_cancel_button = Button.new()
	_cancel_button.text = "キャンセル"
	_cancel_button.custom_minimum_size = Vector2(0, 56)
	_cancel_button.add_theme_font_size_override("font_size", 24)
	_cancel_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_cancel_button, "grey")
	_cancel_button.pressed.connect(_on_cancel_pressed)
	vbox.add_child(_cancel_button)
