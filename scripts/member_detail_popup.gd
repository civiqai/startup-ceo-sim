extends CanvasLayer
## メンバー詳細ポップアップ（タブ形式）
## ステータスタブ / 強化タブ / アクションタブで構成

const TeamMemberRef = preload("res://scripts/team_member.gd")
const TrainingData = preload("res://scripts/training_data.gd")

signal member_promoted(member_index: int, new_role: String)
signal member_fired(member_index: int)
signal training_requested(member_index: int)
signal popup_closed()

var _is_open := false
var _member_data: Dictionary = {}
var _member_index: int = -1
var _current_tab: String = "status"
var _opened_from_tilemap := false

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _main_panel: PanelContainer
var _title_label: Label
var _tab_container: HBoxContainer
var _tab_buttons: Dictionary = {}
var _tab_contents: Dictionary = {}
var _content_area: Control
var _close_button: Button

# --- ステータスタブ ---
var _status_scroll: ScrollContainer
var _status_vbox: VBoxContainer

# --- 強化タブ ---
var _enhance_scroll: ScrollContainer
var _enhance_vbox: VBoxContainer
var _promotion_section: VBoxContainer
var _promotion_title_label: Label
var _promote_button: Button
var _promotion_condition_label: Label
var _training_section: VBoxContainer
var _training_title_label: Label
var _training_status_label: Label
var _training_btn: Button
var _exp_label: Label

# --- アクションタブ ---
var _action_scroll: ScrollContainer
var _action_vbox: VBoxContainer
var _fire_button: Button
var _fire_confirm_section: VBoxContainer

# スキルタイプ別アイコン
const SKILL_ICONS := {
	"engineer": "🔧",
	"designer": "🎨",
	"marketer": "📢",
	"bizdev": "💼",
	"pm": "📋",
}

# カラー定数
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_PANEL_BORDER := Color(0.30, 0.45, 0.55)
const COLOR_TITLE_GOLD := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_TEXT_ACCENT := Color(0.55, 0.85, 0.70)
const COLOR_ACCENT_BLUE := Color(0.35, 0.65, 0.85)
const COLOR_DANGER := Color(0.85, 0.30, 0.25)
const COLOR_SEPARATOR := Color(0.30, 0.32, 0.40)

const COLOR_TAB_ACTIVE := Color(0.25, 0.35, 0.55)
const COLOR_TAB_INACTIVE := Color(0.12, 0.14, 0.20)

# 昇進ルール
const PROMOTION_RULES := {
	"member": {"next_role": "leader", "min_months": 3, "min_level": 2},
	"leader": {"next_role": "manager", "min_months": 6, "min_level": 3},
	"manager": {"next_role": "cxo", "min_months": 12, "min_level": 4},
}

# タブ定義
const TABS := [
	{"id": "status", "icon": "📊", "label": "ステータス"},
	{"id": "enhance", "icon": "⬆", "label": "強化"},
	{"id": "action", "icon": "⚙", "label": "アクション"},
]


func _ready() -> void:
	layer = 101
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


# ==========================================================
#  公開メソッド
# ==========================================================

func show_member(member_data: Dictionary, member_index: int, from_tilemap: bool = false) -> void:
	_member_data = member_data
	_member_index = member_index
	_opened_from_tilemap = from_tilemap

	# タイトル
	var skill_type: String = member_data.get("skill_type", "engineer")
	var member_name: String = member_data.get("member_name", "名無し")
	var icon: String = SKILL_ICONS.get(skill_type, "👤")
	_title_label.text = "%s %s" % [icon, member_name]

	# 各タブの内容を更新
	_refresh_status_tab(member_data)
	_refresh_enhance_tab(member_data)
	_refresh_action_tab(member_data)

	# ステータスタブを初期表示
	_switch_tab("status")

	_panel_root.visible = true
	_is_open = true

	# パネル登場アニメーション
	_main_panel.scale = Vector2(0.8, 0.8)
	_main_panel.modulate.a = 0.0
	_main_panel.pivot_offset = _main_panel.size / 2.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_main_panel, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_main_panel, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_panel_root.visible = false
	popup_closed.emit()


# ==========================================================
#  タブ切り替え
# ==========================================================

func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	for tid in _tab_contents:
		_tab_contents[tid].visible = tid == tab_id
	_update_tab_button_styles()


func _update_tab_button_styles() -> void:
	for tid in _tab_buttons:
		var btn: Button = _tab_buttons[tid]
		var is_active: bool = tid == _current_tab

		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_TAB_ACTIVE if is_active else COLOR_TAB_INACTIVE
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 0 if is_active else 8
		style.corner_radius_bottom_right = 0 if is_active else 8
		style.content_margin_left = 6
		style.content_margin_right = 6
		style.content_margin_top = 8
		style.content_margin_bottom = 8

		var hover_style := style.duplicate()
		hover_style.bg_color = COLOR_TAB_ACTIVE.lightened(0.1) if is_active else COLOR_TAB_INACTIVE.lightened(0.15)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE if is_active else COLOR_TEXT_GRAY)


# ==========================================================
#  ステータスタブ更新
# ==========================================================

func _refresh_status_tab(data: Dictionary) -> void:
	for child in _status_vbox.get_children():
		child.queue_free()

	var skill_type: String = data.get("skill_type", "engineer")
	var skill_level: int = data.get("skill_level", 1)
	var role: String = data.get("role", "member")
	var personality: String = data.get("personality", "diligent")
	var salary: int = data.get("salary", 0)
	var months_employed: int = data.get("months_employed", 0)
	var experience: int = data.get("experience", 0)
	var stamina: float = data.get("stamina", 100.0)
	var turnover_risk: float = data.get("turnover_risk", 0.0)

	var skill_label_text: String = TeamMemberRef.get_skill_label(skill_type)
	var role_label_text: String = TeamMemberRef.get_role_label(role)
	if role == "cxo":
		role_label_text = TeamMemberRef.get_cxo_title(skill_type)
	var personality_label: String = TeamMemberRef.get_personality_label(personality)
	var stars := "★".repeat(skill_level) + "☆".repeat(maxi(5 - skill_level, 0))

	# 基本情報セクション
	_status_vbox.add_child(_make_section_title("基本情報"))

	_status_vbox.add_child(_make_stat_row("役職", role_label_text, "👔"))
	_status_vbox.add_child(_make_stat_row("スキル", skill_label_text, SKILL_ICONS.get(skill_type, "👤")))
	_status_vbox.add_child(_make_stat_row("レベル", "%s (Lv.%d)" % [stars, skill_level], "⭐"))
	_status_vbox.add_child(_make_stat_row("性格", personality_label, "🧠"))

	_status_vbox.add_child(_make_separator())

	# パラメータセクション
	_status_vbox.add_child(_make_section_title("パラメータ"))

	# EXPバー
	var exp_text: String
	if skill_level >= 5:
		exp_text = "%d（MAX）" % experience
	else:
		var next_level := skill_level + 1
		var required: int = TeamMemberRef.EXP_TABLE.get(next_level, 99999)
		exp_text = "%d / %d" % [experience, required]
	_status_vbox.add_child(_make_stat_row("経験値", exp_text, "📈"))

	# EXPプログレスバー
	if skill_level < 5:
		var next_level := skill_level + 1
		var required: int = TeamMemberRef.EXP_TABLE.get(next_level, 99999)
		var prev_required: int = TeamMemberRef.EXP_TABLE.get(skill_level, 0)
		var progress: float = float(experience - prev_required) / float(maxi(required - prev_required, 1))
		progress = clampf(progress, 0.0, 1.0)
		_status_vbox.add_child(_make_progress_bar(progress, COLOR_ACCENT_BLUE))

	_status_vbox.add_child(_make_stat_row("年収", "%d万円" % salary, "💰"))
	_status_vbox.add_child(_make_stat_row("在籍期間", "%dヶ月" % months_employed, "📅"))

	_status_vbox.add_child(_make_separator())

	# コンディションセクション
	_status_vbox.add_child(_make_section_title("コンディション"))

	# スタミナバー
	var stamina_text: String = "%d / 100" % int(stamina)
	var stamina_color: Color
	if stamina >= 60:
		stamina_color = Color(0.40, 0.85, 0.45)
	elif stamina >= 30:
		stamina_color = Color(0.90, 0.75, 0.30)
	else:
		stamina_color = Color(0.90, 0.35, 0.30)
	_status_vbox.add_child(_make_stat_row("スタミナ", stamina_text, "💪"))
	_status_vbox.add_child(_make_progress_bar(stamina / 100.0, stamina_color))

	# 転職リスク
	if turnover_risk > 0.0:
		var risk_label: String
		var risk_color: Color
		if turnover_risk <= 0.05:
			risk_label = "安定"
			risk_color = Color(0.40, 0.85, 0.45)
		elif turnover_risk <= 0.10:
			risk_label = "そわそわ"
			risk_color = Color(0.90, 0.75, 0.30)
		else:
			risk_label = "転職サイト見てる…"
			risk_color = Color(0.90, 0.35, 0.30)
		var risk_row := _make_stat_row("転職リスク", risk_label, "💭")
		# 値ラベルの色を変更
		var value_lbl: Label = risk_row.get_child(risk_row.get_child_count() - 1)
		value_lbl.add_theme_color_override("font_color", risk_color)
		_status_vbox.add_child(risk_row)
	else:
		_status_vbox.add_child(_make_stat_row("転職リスク", "安定", "😊"))

	# 性格効果の説明
	_status_vbox.add_child(_make_separator())
	_status_vbox.add_child(_make_section_title("性格効果"))
	var effect: Dictionary = TeamMemberRef.get_personality_effect(personality)
	var effect_desc := _get_personality_effect_description(personality, effect)
	var effect_label := Label.new()
	effect_label.text = effect_desc
	effect_label.add_theme_font_size_override("font_size", 22)
	effect_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_vbox.add_child(effect_label)


# ==========================================================
#  強化タブ更新
# ==========================================================

func _refresh_enhance_tab(data: Dictionary) -> void:
	for child in _enhance_vbox.get_children():
		child.queue_free()

	# --- 訓練セクション ---
	var training_section := VBoxContainer.new()
	training_section.add_theme_constant_override("separation", 8)
	_enhance_vbox.add_child(training_section)

	training_section.add_child(_make_section_title("訓練"))

	var experience: int = data.get("experience", 0)
	var training: String = data.get("training", "")
	var training_remaining: int = data.get("training_remaining", 0)
	var skill_level: int = data.get("skill_level", 1)

	# 経験値表示
	_exp_label = Label.new()
	_exp_label.add_theme_font_size_override("font_size", 22)
	_exp_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	_exp_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var next_level := skill_level + 1
	var exp_table: Dictionary = TeamMemberRef.EXP_TABLE
	if skill_level >= 5:
		_exp_label.text = "EXP: %d（最大レベル）" % experience
	else:
		var required: int = exp_table.get(next_level, 99999)
		var remaining := maxi(required - experience, 0)
		_exp_label.text = "EXP: %d / %d（Lv.%dまであと%d）" % [experience, required, next_level, remaining]
	training_section.add_child(_exp_label)

	# 訓練中ステータス
	_training_status_label = Label.new()
	_training_status_label.add_theme_font_size_override("font_size", 22)
	_training_status_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
	_training_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_training_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_training_status_label.visible = false
	training_section.add_child(_training_status_label)

	# 訓練に送るボタン
	_training_btn = Button.new()
	_training_btn.text = "訓練に送る"
	_training_btn.custom_minimum_size = Vector2(0, 52)
	_training_btn.add_theme_font_size_override("font_size", 26)
	_training_btn.pressed.connect(_on_training_btn_pressed)
	training_section.add_child(_training_btn)

	if training != "" and training_remaining > 0:
		var training_data := TrainingData.get_training(training)
		var training_name: String = training_data.get("name", training)
		var training_icon: String = training_data.get("icon", "")
		_training_status_label.text = "訓練中: %s %s（残り%dターン）" % [training_icon, training_name, training_remaining]
		_training_status_label.visible = true
		_training_btn.disabled = true
		KenneyTheme.apply_button_style(_training_btn, "grey")
	else:
		_training_status_label.visible = false
		_training_btn.disabled = false
		KenneyTheme.apply_button_style(_training_btn, "blue")

	_enhance_vbox.add_child(_make_separator())

	# --- 昇進セクション ---
	var promo_section := VBoxContainer.new()
	promo_section.add_theme_constant_override("separation", 8)
	_enhance_vbox.add_child(promo_section)

	promo_section.add_child(_make_section_title("昇進"))

	var role: String = data.get("role", "member")
	var months_employed: int = data.get("months_employed", 0)
	var skill_type: String = data.get("skill_type", "engineer")

	var rule: Dictionary = PROMOTION_RULES.get(role, {})

	if rule.is_empty():
		# CxOは昇進不可
		var max_label := Label.new()
		max_label.text = "最高役職に到達しています"
		max_label.add_theme_font_size_override("font_size", 22)
		max_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		max_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		promo_section.add_child(max_label)
	else:
		var next_role: String = rule["next_role"]
		var min_months: int = rule["min_months"]
		var min_level: int = rule["min_level"]

		var next_role_label: String = TeamMemberRef.get_role_label(next_role)
		if next_role == "cxo":
			next_role_label = TeamMemberRef.get_cxo_title(skill_type)

		# 条件チェック
		var meets_months := months_employed >= min_months
		var meets_level := skill_level >= min_level
		var meets_cxo_constraint := true
		if next_role == "cxo":
			var cxo_exists = data.get("cxo_exists_for_skill", false)
			meets_cxo_constraint = not cxo_exists
		var can_promote := meets_months and meets_level and meets_cxo_constraint

		# 昇進ボタン
		_promote_button = Button.new()
		_promote_button.text = "%sに昇進" % next_role_label
		_promote_button.custom_minimum_size = Vector2(0, 52)
		_promote_button.add_theme_font_size_override("font_size", 26)
		_promote_button.disabled = not can_promote
		_promote_button.pressed.connect(_on_promote_pressed)

		if can_promote:
			KenneyTheme.apply_button_style(_promote_button, "green")
		else:
			KenneyTheme.apply_button_style(_promote_button, "grey")
		promo_section.add_child(_promote_button)

		# 条件テキスト
		_promotion_condition_label = Label.new()
		_promotion_condition_label.add_theme_font_size_override("font_size", 20)
		_promotion_condition_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		_promotion_condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_promotion_condition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var conditions := PackedStringArray()
		var months_mark := "✅" if meets_months else "❌"
		conditions.append("%s 在籍%dヶ月以上 (現在: %dヶ月)" % [months_mark, min_months, months_employed])
		var level_mark := "✅" if meets_level else "❌"
		conditions.append("%s レベル%d以上 (現在: Lv.%d)" % [level_mark, min_level, skill_level])
		if next_role == "cxo" and not meets_cxo_constraint:
			conditions.append("❌ 同スキルのCxOが既に存在します")
		_promotion_condition_label.text = "\n".join(conditions)
		promo_section.add_child(_promotion_condition_label)


# ==========================================================
#  アクションタブ更新
# ==========================================================

func _refresh_action_tab(data: Dictionary) -> void:
	for child in _action_vbox.get_children():
		child.queue_free()

	_action_vbox.add_child(_make_section_title("メンバーアクション"))

	# 解雇セクション
	var fire_section := VBoxContainer.new()
	fire_section.add_theme_constant_override("separation", 10)
	_action_vbox.add_child(fire_section)

	var warning_label := Label.new()
	warning_label.text = "このメンバーをチームから外します。\nこの操作は取り消せません。"
	warning_label.add_theme_font_size_override("font_size", 22)
	warning_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	warning_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fire_section.add_child(warning_label)

	# 解雇ボタン
	_fire_button = Button.new()
	_fire_button.text = "解雇する"
	_fire_button.custom_minimum_size = Vector2(0, 52)
	_fire_button.add_theme_font_size_override("font_size", 26)
	KenneyTheme.apply_button_style(_fire_button, "red")
	_fire_button.pressed.connect(_on_fire_pressed)
	fire_section.add_child(_fire_button)

	# 確認セクション（初期非表示）
	_fire_confirm_section = VBoxContainer.new()
	_fire_confirm_section.add_theme_constant_override("separation", 8)
	_fire_confirm_section.visible = false
	fire_section.add_child(_fire_confirm_section)

	var confirm_label := Label.new()
	var member_name: String = data.get("member_name", "")
	confirm_label.text = "本当に %s を解雇しますか？" % member_name
	confirm_label.add_theme_font_size_override("font_size", 22)
	confirm_label.add_theme_color_override("font_color", Color(0.90, 0.35, 0.30))
	confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fire_confirm_section.add_child(confirm_label)

	var confirm_row := HBoxContainer.new()
	confirm_row.add_theme_constant_override("separation", 10)
	_fire_confirm_section.add_child(confirm_row)

	var confirm_yes := Button.new()
	confirm_yes.text = "解雇する"
	confirm_yes.custom_minimum_size = Vector2(0, 48)
	confirm_yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_yes.add_theme_font_size_override("font_size", 24)
	KenneyTheme.apply_button_style(confirm_yes, "red")
	confirm_yes.pressed.connect(_on_fire_confirmed)
	confirm_row.add_child(confirm_yes)

	var confirm_no := Button.new()
	confirm_no.text = "キャンセル"
	confirm_no.custom_minimum_size = Vector2(0, 48)
	confirm_no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_no.add_theme_font_size_override("font_size", 24)
	KenneyTheme.apply_button_style(confirm_no, "grey")
	confirm_no.pressed.connect(_on_fire_cancelled)
	confirm_row.add_child(confirm_no)


# ==========================================================
#  UIヘルパー
# ==========================================================

func _make_section_title(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.20, 0.8)
	sb.border_color = COLOR_PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)

	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", COLOR_ACCENT_BLUE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)

	return panel


func _make_stat_row(label_text: String, value_text: String, icon: String = "") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if icon != "":
		var icon_label := Label.new()
		icon_label.text = icon
		icon_label.add_theme_font_size_override("font_size", 22)
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_label.custom_minimum_size = Vector2(30, 0)
		row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = label_text
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.custom_minimum_size = Vector2(130, 0)
	row.add_child(name_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.add_theme_font_size_override("font_size", 22)
	value_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)

	return row


func _make_progress_bar(ratio: float, bar_color: Color) -> PanelContainer:
	var outer := PanelContainer.new()
	outer.custom_minimum_size = Vector2(0, 16)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var outer_sb := StyleBoxFlat.new()
	outer_sb.bg_color = Color(0.15, 0.17, 0.22)
	outer_sb.set_corner_radius_all(4)
	outer_sb.content_margin_left = 2
	outer_sb.content_margin_right = 2
	outer_sb.content_margin_top = 2
	outer_sb.content_margin_bottom = 2
	outer.add_theme_stylebox_override("panel", outer_sb)

	var inner := ColorRect.new()
	inner.color = bar_color
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.custom_minimum_size = Vector2(0, 10)
	outer.add_child(inner)

	# サイズはdeferred で設定（親サイズ確定後）
	outer.resized.connect(func():
		var avail_w: float = outer.size.x - 4  # padding分引く
		inner.size = Vector2(avail_w * clampf(ratio, 0.0, 1.0), 10)
		inner.position = Vector2(2, 2)
	)

	return outer


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", COLOR_SEPARATOR)
	return sep


func _get_personality_effect_description(personality_key: String, effect: Dictionary) -> String:
	if effect.is_empty():
		return "効果なし"
	var etype: String = effect.get("type", "")
	var value = effect.get("value", 0)
	match etype:
		"productivity":
			return "勤勉: 生産性 +%d%%" % int(value * 100)
		"product_power":
			return "クリエイティブ: プロダクト力上昇 +%d%%" % int(value * 100)
		"morale":
			return "ムードメーカー: 毎ターン士気 +%d" % int(value)
		"reputation":
			return "分析的: 評判上昇 +%d%%" % int(value * 100)
		"team_productivity":
			return "リーダー気質: チーム全体の生産性 +%d%%" % int(value * 100)
		_:
			return "%s: %s" % [personality_key, str(value)]


# ==========================================================
#  イベントハンドラ
# ==========================================================

func _on_training_btn_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	training_requested.emit(_member_index)


func _on_promote_pressed() -> void:
	if not _is_open:
		return
	var role: String = _member_data.get("role", "member")
	var rule: Dictionary = PROMOTION_RULES.get(role, {})
	if rule.is_empty():
		return
	AudioManager.play_sfx("click")
	var next_role: String = rule["next_role"]
	_panel_root.visible = false
	_is_open = false
	member_promoted.emit(_member_index, next_role)


func _on_fire_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	# 確認モードを表示
	_fire_button.visible = false
	_fire_confirm_section.visible = true


func _on_fire_confirmed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	_panel_root.visible = false
	_is_open = false
	member_fired.emit(_member_index)


func _on_fire_cancelled() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	_fire_button.visible = true
	_fire_confirm_section.visible = false


func _on_close_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	close()


# ==========================================================
#  UI構築
# ==========================================================

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
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# メインパネル
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(660, 850)
	KenneyTheme.apply_panel_style(_main_panel, "popup")
	center.add_child(_main_panel)

	# メインVBox
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_main_panel.add_child(main_vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "👤 メンバー"
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(_title_label)

	# タブボタン行
	_tab_container = HBoxContainer.new()
	_tab_container.add_theme_constant_override("separation", 4)
	main_vbox.add_child(_tab_container)

	for tab_def in TABS:
		var tid: String = tab_def["id"]
		var btn := Button.new()
		btn.text = "%s %s" % [tab_def["icon"], tab_def["label"]]
		btn.custom_minimum_size = Vector2(0, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		var captured_id = tid
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_switch_tab(captured_id)
		)
		_tab_container.add_child(btn)
		_tab_buttons[tid] = btn

	# 区切り線
	var tab_sep := HSeparator.new()
	tab_sep.add_theme_color_override("separator_color", COLOR_TAB_ACTIVE)
	main_vbox.add_child(tab_sep)

	# コンテンツエリア
	_content_area = Control.new()
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_vbox.add_child(_content_area)

	# --- ステータスタブ ---
	_status_scroll = ScrollContainer.new()
	_status_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_status_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_status_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_child(_status_scroll)

	_status_vbox = VBoxContainer.new()
	_status_vbox.add_theme_constant_override("separation", 8)
	_status_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_scroll.add_child(_status_vbox)
	_tab_contents["status"] = _status_scroll

	# --- 強化タブ ---
	_enhance_scroll = ScrollContainer.new()
	_enhance_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_enhance_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_enhance_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_child(_enhance_scroll)

	_enhance_vbox = VBoxContainer.new()
	_enhance_vbox.add_theme_constant_override("separation", 8)
	_enhance_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enhance_scroll.add_child(_enhance_vbox)
	_tab_contents["enhance"] = _enhance_scroll

	# --- アクションタブ ---
	_action_scroll = ScrollContainer.new()
	_action_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.add_child(_action_scroll)

	_action_vbox = VBoxContainer.new()
	_action_vbox.add_theme_constant_override("separation", 8)
	_action_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.add_child(_action_vbox)
	_tab_contents["action"] = _action_scroll

	# 閉じるボタン
	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 52)
	_close_button.add_theme_font_size_override("font_size", 26)
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(_on_close_pressed)
	main_vbox.add_child(_close_button)
