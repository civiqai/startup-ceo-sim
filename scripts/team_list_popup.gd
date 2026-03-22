extends CanvasLayer
## チーム一覧ポップアップ
## チームメンバーのリストをスクロール表示し、タップで詳細画面を開く

const TeamMemberRef = preload("res://scripts/team_member.gd")

signal member_selected(member_index: int)
signal popup_closed()

var _is_open := false
var _members: Array = []

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _scroll: ScrollContainer
var _list_container: VBoxContainer
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
const COLOR_CARD_BG := Color(0.14, 0.16, 0.22)
const COLOR_CARD_BORDER := Color(0.28, 0.32, 0.40)


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func show_team(members: Array) -> void:
	_members = members
	_title_label.text = "👥 チーム一覧 (%d人)" % members.size()
	_rebuild_list()
	_panel_root.visible = true
	_is_open = true


func _rebuild_list() -> void:
	# 既存カードをクリア
	for child in _list_container.get_children():
		child.queue_free()

	for i in range(_members.size()):
		var member = _members[i]
		var card := _build_member_card(member, i)
		_list_container.add_child(card)


func _build_member_card(member_data: Dictionary, index: int) -> PanelContainer:
	var skill_type: String = member_data.get("skill_type", "engineer")
	var member_name: String = member_data.get("member_name", "名無し")
	var skill_level: int = member_data.get("skill_level", 1)
	var role: String = member_data.get("role", "member")

	var icon: String = SKILL_ICONS.get(skill_type, "👤")
	var stars := "★".repeat(skill_level) + "☆".repeat(maxi(5 - skill_level, 0))
	var skill_label_text: String = TeamMemberRef.get_skill_label(skill_type)
	var role_label_text: String = TeamMemberRef.get_role_label(role)
	# CxOの場合は具体的なタイトルを表示
	if role == "cxo":
		role_label_text = TeamMemberRef.get_cxo_title(skill_type)

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = COLOR_CARD_BG
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 1
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card_style.border_color = COLOR_CARD_BORDER
	card_style.content_margin_left = 16
	card_style.content_margin_top = 12
	card_style.content_margin_right = 16
	card_style.content_margin_bottom = 12

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)
	card.custom_minimum_size = Vector2(0, 80)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	# タップで詳細画面を開く
	var captured_index := index
	card.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			AudioManager.play_sfx("click")
			member_selected.emit(captured_index)
	)

	# HBox: アイコン + テキスト情報
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(hbox)

	# アイコン
	var icon_label := Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 40)
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(48, 0)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(icon_label)

	# テキスト情報のVBox
	var text_vbox := VBoxContainer.new()
	text_vbox.add_theme_constant_override("separation", 4)
	text_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_vbox)

	# 名前 + 星
	var name_label := Label.new()
	name_label.text = "%s %s" % [member_name, stars]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(name_label)

	# スキル / 役職
	var detail_label := Label.new()
	detail_label.text = "%s / %s" % [skill_label_text, role_label_text]
	detail_label.add_theme_font_size_override("font_size", 24)
	detail_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_vbox.add_child(detail_label)

	# 右矢印（詳細へ）
	var arrow_label := Label.new()
	arrow_label.text = "＞"
	arrow_label.add_theme_font_size_override("font_size", 28)
	arrow_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	arrow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(arrow_label)

	return card


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

	# タイトル
	_title_label = Label.new()
	_title_label.text = "👥 チーム一覧"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE_GOLD)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# スクロールコンテナ（メンバー一覧）
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0, 700)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)

	_list_container = VBoxContainer.new()
	_list_container.add_theme_constant_override("separation", 10)
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list_container)

	# 閉じるボタン（Kenney UIスタイル）
	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 56)
	_close_button.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)
