extends CanvasLayer
## メンバー詳細・昇進ポップアップ
## メンバーの詳細情報を表示し、昇進・解雇アクションを提供する

const TeamMemberRef = preload("res://scripts/team_member.gd")

signal member_promoted(member_index: int, new_role: String)
signal member_fired(member_index: int)
signal popup_closed()

var _is_open := false
var _member_data: Dictionary = {}
var _member_index: int = -1

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _info_label: Label
var _promotion_section: VBoxContainer
var _promotion_title_label: Label
var _promote_button: Button
var _promotion_condition_label: Label
var _fire_button: Button
var _close_button: Button

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
const COLOR_DANGER := Color(0.85, 0.30, 0.25)
const COLOR_DANGER_HOVER := Color(0.95, 0.35, 0.30)
const COLOR_PROMOTE := Color(0.20, 0.50, 0.35)
const COLOR_PROMOTE_HOVER := Color(0.25, 0.60, 0.40)
const COLOR_PROMOTE_DISABLED := Color(0.25, 0.27, 0.30)

# 昇進ルール: 現在の役職 → {next_role, min_months, min_level}
const PROMOTION_RULES := {
	"member": {"next_role": "leader", "min_months": 3, "min_level": 2},
	"leader": {"next_role": "manager", "min_months": 6, "min_level": 3},
	"manager": {"next_role": "cxo", "min_months": 12, "min_level": 4},
}


func _ready() -> void:
	layer = 101  # チーム一覧より前面
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func show_member(member_data: Dictionary, member_index: int) -> void:
	_member_data = member_data
	_member_index = member_index

	var skill_type: String = member_data.get("skill_type", "engineer")
	var member_name: String = member_data.get("member_name", "名無し")
	var skill_level: int = member_data.get("skill_level", 1)
	var role: String = member_data.get("role", "member")
	var personality: String = member_data.get("personality", "diligent")
	var salary: int = member_data.get("salary", 0)
	var months_employed: int = member_data.get("months_employed", 0)

	var icon: String = SKILL_ICONS.get(skill_type, "👤")
	var stars := "★".repeat(skill_level) + "☆".repeat(maxi(5 - skill_level, 0))
	var skill_label_text: String = TeamMemberRef.get_skill_label(skill_type)
	var role_label_text: String = TeamMemberRef.get_role_label(role)
	if role == "cxo":
		role_label_text = TeamMemberRef.get_cxo_title(skill_type)
	var personality_label: String = TeamMemberRef.get_personality_label(personality)

	# タイトル
	_title_label.text = "%s %s" % [icon, member_name]

	# 詳細情報
	var info_lines := PackedStringArray()
	info_lines.append("スキル: %s" % skill_label_text)
	info_lines.append("レベル: %s (Lv.%d)" % [stars, skill_level])
	info_lines.append("性格: %s" % personality_label)
	info_lines.append("役職: %s" % role_label_text)
	info_lines.append("年収: %d万円" % salary)
	info_lines.append("在籍: %dヶ月" % months_employed)
	_info_label.text = "\n".join(info_lines)

	# 昇進セクション更新
	_update_promotion_section(member_data)

	_panel_root.visible = true
	_is_open = true


## 昇進セクションの表示を更新する
func _update_promotion_section(member_data: Dictionary) -> void:
	var role: String = member_data.get("role", "member")
	var skill_level: int = member_data.get("skill_level", 1)
	var months_employed: int = member_data.get("months_employed", 0)
	var skill_type: String = member_data.get("skill_type", "engineer")

	var rule: Dictionary = PROMOTION_RULES.get(role, {})

	if rule.is_empty():
		# CxOは昇進不可
		_promotion_section.visible = false
		return

	_promotion_section.visible = true
	_promotion_title_label.text = "【昇進】"

	var next_role: String = rule["next_role"]
	var min_months: int = rule["min_months"]
	var min_level: int = rule["min_level"]

	# 次の役職名
	var next_role_label: String = TeamMemberRef.get_role_label(next_role)
	if next_role == "cxo":
		next_role_label = TeamMemberRef.get_cxo_title(skill_type)

	# 条件チェック
	var meets_months := months_employed >= min_months
	var meets_level := skill_level >= min_level
	var meets_cxo_constraint := true

	# CxO制約: 同じスキルタイプのCxOが既にいないか
	if next_role == "cxo":
		var cxo_exists = member_data.get("cxo_exists_for_skill", false)
		meets_cxo_constraint = not cxo_exists

	var can_promote := meets_months and meets_level and meets_cxo_constraint

	_promote_button.text = "%sに昇進" % next_role_label
	_promote_button.disabled = not can_promote

	# ボタンのスタイルを状態に応じて変更（Kenney UIスタイル）
	if can_promote:
		KenneyTheme.apply_button_style(_promote_button, "green")
		_promote_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	else:
		KenneyTheme.apply_button_style(_promote_button, "grey")
		_promote_button.add_theme_color_override("font_color", COLOR_TEXT_GRAY)

	# 条件テキスト
	var conditions := PackedStringArray()
	var months_mark := "✅" if meets_months else "❌"
	conditions.append("%s 在籍%dヶ月以上 (現在: %dヶ月)" % [months_mark, min_months, months_employed])
	var level_mark := "✅" if meets_level else "❌"
	conditions.append("%s レベル%d以上 (現在: Lv.%d)" % [level_mark, min_level, skill_level])
	if next_role == "cxo" and not meets_cxo_constraint:
		conditions.append("❌ 同スキルのCxOが既に存在します")
	_promotion_condition_label.text = "\n".join(conditions)


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
	_panel_root.visible = false
	_is_open = false
	member_fired.emit(_member_index)


func _on_close_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


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
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# タイトル（メンバー名）
	_title_label = Label.new()
	_title_label.text = "👤 メンバー"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep1)

	# 詳細情報ラベル
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 22)
	_info_label.add_theme_color_override("font_color", COLOR_TEXT_ACCENT)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_label)

	# 区切り線
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep2)

	# 昇進セクション
	_promotion_section = VBoxContainer.new()
	_promotion_section.add_theme_constant_override("separation", 8)
	vbox.add_child(_promotion_section)

	_promotion_title_label = Label.new()
	_promotion_title_label.text = "【昇進】"
	_promotion_title_label.add_theme_font_size_override("font_size", 24)
	_promotion_title_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	_promotion_section.add_child(_promotion_title_label)

	# 昇進ボタン
	_promote_button = Button.new()
	_promote_button.text = "昇進"
	_promote_button.custom_minimum_size = Vector2(0, 52)
	_promote_button.add_theme_font_size_override("font_size", 22)
	_promote_button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	_promote_button.pressed.connect(_on_promote_pressed)
	_promotion_section.add_child(_promote_button)

	# 昇進条件ラベル
	_promotion_condition_label = Label.new()
	_promotion_condition_label.add_theme_font_size_override("font_size", 18)
	_promotion_condition_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	_promotion_condition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promotion_section.add_child(_promotion_condition_label)

	# 区切り線
	var sep3 := HSeparator.new()
	sep3.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep3)

	# ボタン行（解雇 + 閉じる）
	var button_row := HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 12)
	vbox.add_child(button_row)

	# 解雇ボタン（Kenney 赤スタイル）
	_fire_button = Button.new()
	_fire_button.text = "解雇する"
	_fire_button.custom_minimum_size = Vector2(0, 52)
	_fire_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fire_button.add_theme_font_size_override("font_size", 22)
	_fire_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_fire_button, "red")
	_fire_button.pressed.connect(_on_fire_pressed)
	button_row.add_child(_fire_button)

	# 閉じるボタン（Kenney グレースタイル）
	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 52)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.add_theme_font_size_override("font_size", 22)
	_close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(_on_close_pressed)
	button_row.add_child(_close_button)
