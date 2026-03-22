extends CanvasLayer
## 家具詳細・アクションポップアップ
## 配置済み家具をタップした際に詳細情報と操作（移動・売却・アップグレード）を提供する

signal furniture_sold(instance_id: int)
signal furniture_moved(instance_id: int)
signal furniture_upgraded(instance_id: int, new_item_id: String)
signal popup_closed

# --- スタイル定数 ---
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_PANEL_BORDER := Color(0.30, 0.45, 0.55)
const COLOR_TITLE := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_ACCENT := Color(0.35, 0.65, 0.85)
const COLOR_SELL_BTN := Color(0.65, 0.25, 0.25)
const COLOR_MOVE_BTN := Color(0.25, 0.45, 0.65)
const COLOR_UPGRADE_BTN := Color(0.50, 0.40, 0.15)
const COLOR_EFFECT_POSITIVE := Color(0.40, 0.85, 0.45)
const COLOR_EFFECT_NEGATIVE := Color(0.90, 0.35, 0.30)
const COLOR_SEPARATOR := Color(0.30, 0.32, 0.40)

# --- 内部状態 ---
var _is_open := false
var _current_instance_id: int = -1
var _current_item_id: String = ""
var _confirm_mode := false

# --- UI参照 ---
var _panel_root: Control
var _overlay: ColorRect
var _main_panel: PanelContainer
var _content_vbox: VBoxContainer
var _sprite_preview: TextureRect
var _name_label: Label
var _desc_label: Label
var _effects_container: VBoxContainer
var _upgrade_section: VBoxContainer
var _button_row: HBoxContainer
var _confirm_row: VBoxContainer
var _move_button: Button
var _sell_button: Button
var _close_button: Button
var _confirm_yes_button: Button
var _confirm_no_button: Button
var _confirm_label: Label
var _upgrade_button: Button


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

## 家具詳細を表示する
func show_detail(instance_id: int) -> void:
	_current_instance_id = instance_id
	_confirm_mode = false

	# 配置済み家具データを取得
	var placed_list := FurnitureManager.get_placed_furniture()
	var placed_data: Dictionary = {}
	for p in placed_list:
		if p["instance_id"] == instance_id:
			placed_data = p
			break

	if placed_data.is_empty():
		push_warning("FurnitureDetailPopup: instance_id %d が見つかりません" % instance_id)
		return

	_current_item_id = placed_data["id"]
	var item := FurnitureData.get_item(_current_item_id)
	if item.is_empty():
		push_warning("FurnitureDetailPopup: item_id '%s' が見つかりません" % _current_item_id)
		return

	_refresh_ui(item)

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


## ポップアップを閉じる
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_confirm_mode = false
	_panel_root.visible = false
	popup_closed.emit()


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
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# メインパネル
	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(480, 0)
	KenneyTheme.apply_panel_style(_main_panel, "popup")
	center.add_child(_main_panel)

	# スクロール対応コンテナ
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_theme_constant_override("scroll_deadzone", 0)
	_main_panel.add_child(scroll)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 12)
	_content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_vbox.custom_minimum_size = Vector2(440, 0)
	scroll.add_child(_content_vbox)

	# --- スプライトプレビュー ---
	var sprite_center := CenterContainer.new()
	sprite_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.add_child(sprite_center)

	_sprite_preview = TextureRect.new()
	_sprite_preview.custom_minimum_size = Vector2(96, 96)
	_sprite_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite_center.add_child(_sprite_preview)

	# --- 名前ラベル ---
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", COLOR_TITLE)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.add_child(_name_label)

	# --- 説明ラベル ---
	_desc_label = Label.new()
	_desc_label.add_theme_font_size_override("font_size", 14)
	_desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.add_child(_desc_label)

	# --- 区切り線 ---
	_content_vbox.add_child(_make_separator())

	# --- 効果セクション ---
	_effects_container = VBoxContainer.new()
	_effects_container.add_theme_constant_override("separation", 6)
	_effects_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.add_child(_effects_container)

	# --- 区切り線 ---
	_content_vbox.add_child(_make_separator())

	# --- アップグレードセクション ---
	_upgrade_section = VBoxContainer.new()
	_upgrade_section.add_theme_constant_override("separation", 8)
	_upgrade_section.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content_vbox.add_child(_upgrade_section)

	# --- アクションボタン行 ---
	_button_row = HBoxContainer.new()
	_button_row.add_theme_constant_override("separation", 10)
	_content_vbox.add_child(_button_row)

	_move_button = _make_action_button("移動", COLOR_MOVE_BTN)
	_move_button.pressed.connect(_on_move_pressed)
	_button_row.add_child(_move_button)

	_sell_button = _make_action_button("売却", COLOR_SELL_BTN)
	_sell_button.pressed.connect(_on_sell_pressed)
	_button_row.add_child(_sell_button)

	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 48)
	_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_close_button.add_theme_font_size_override("font_size", 18)
	_close_button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(_on_close_pressed)
	_button_row.add_child(_close_button)

	# --- 売却確認行（初期非表示） ---
	_confirm_row = VBoxContainer.new()
	_confirm_row.add_theme_constant_override("separation", 8)
	_confirm_row.visible = false
	_content_vbox.add_child(_confirm_row)

	_confirm_label = Label.new()
	_confirm_label.add_theme_font_size_override("font_size", 16)
	_confirm_label.add_theme_color_override("font_color", COLOR_EFFECT_NEGATIVE)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_confirm_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_row.add_child(_confirm_label)

	var confirm_btn_row := HBoxContainer.new()
	confirm_btn_row.add_theme_constant_override("separation", 10)
	_confirm_row.add_child(confirm_btn_row)

	_confirm_yes_button = _make_action_button("売却する", COLOR_SELL_BTN)
	_confirm_yes_button.pressed.connect(_on_confirm_sell)
	confirm_btn_row.add_child(_confirm_yes_button)

	_confirm_no_button = Button.new()
	_confirm_no_button.text = "キャンセル"
	_confirm_no_button.custom_minimum_size = Vector2(0, 48)
	_confirm_no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm_no_button.add_theme_font_size_override("font_size", 18)
	_confirm_no_button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(_confirm_no_button, "grey")
	_confirm_no_button.pressed.connect(_on_cancel_sell)
	confirm_btn_row.add_child(_confirm_no_button)


# ==========================================================
#  UI更新
# ==========================================================

func _refresh_ui(item: Dictionary) -> void:
	var effects: Dictionary = item.get("effects", {})
	var cost: int = item.get("cost", 0)
	var refund := int(cost * FurnitureManager.SELL_REFUND_RATE)

	# スプライト
	var sprite_path: String = item.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		_sprite_preview.texture = load(sprite_path)
		_sprite_preview.visible = true
	else:
		_sprite_preview.visible = false

	# 名前（カテゴリアイコン付き）
	var category: String = item.get("category", "")
	var cat_data: Dictionary = FurnitureData.CATEGORIES.get(category, {})
	var cat_icon: String = cat_data.get("icon", "")
	_name_label.text = "%s %s" % [cat_icon, item.get("name", "不明")]

	# 説明
	_desc_label.text = item.get("description", "")

	# 効果セクション再構築
	_rebuild_effects_display(effects)

	# アップグレードセクション再構築
	_rebuild_upgrade_section(item)

	# 売却ボタンのテキスト更新
	_sell_button.text = "売却 (%d万円)" % refund

	# 確認モードをリセット
	_confirm_mode = false
	_button_row.visible = true
	_confirm_row.visible = false
	_confirm_label.text = "本当に売却しますか？（%d万円返金）" % refund


## 効果表示を構築する
func _rebuild_effects_display(effects: Dictionary) -> void:
	for child in _effects_container.get_children():
		child.queue_free()

	# セクションタイトル
	_effects_container.add_child(_make_effects_title_box())

	if effects.is_empty():
		var no_effect := Label.new()
		no_effect.text = "  効果なし"
		no_effect.add_theme_font_size_override("font_size", 16)
		no_effect.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		no_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_effects_container.add_child(no_effect)
		return

	for effect_type in effects:
		var value: int = effects[effect_type]
		_effects_container.add_child(_make_effect_row(effect_type, value))


## 効果セクションのタイトルボックスを作成
func _make_effects_title_box() -> PanelContainer:
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

	var title_label := Label.new()
	title_label.text = "効果"
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(title_label)

	return panel


## 効果行（アイコン + 名前 + 値）を作成
func _make_effect_row(effect_type: String, value: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon_label := Label.new()
	icon_label.text = OfficeBuffManager.get_effect_icon(effect_type)
	icon_label.add_theme_font_size_override("font_size", 16)
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = OfficeBuffManager.get_effect_display_name(effect_type)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var value_label := Label.new()
	var sign_str := "+" if value >= 0 else ""
	value_label.text = "%s%d" % [sign_str, value]
	value_label.add_theme_font_size_override("font_size", 16)
	if value >= 0:
		value_label.add_theme_color_override("font_color", COLOR_EFFECT_POSITIVE)
	else:
		value_label.add_theme_color_override("font_color", COLOR_EFFECT_NEGATIVE)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)

	return row


## アップグレードセクションを構築する
func _rebuild_upgrade_section(item: Dictionary) -> void:
	for child in _upgrade_section.get_children():
		child.queue_free()

	var upgrade_to: String = item.get("upgrade_to", "")
	if upgrade_to == "":
		_upgrade_section.visible = false
		return

	var upgrade_item := FurnitureData.get_item(upgrade_to)
	if upgrade_item.is_empty():
		_upgrade_section.visible = false
		return

	_upgrade_section.visible = true

	# ヘッダ
	var header := Label.new()
	header.text = "⬆ アップグレード可能"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.85, 0.75, 0.30))
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_section.add_child(header)

	# 次のティア名
	var next_name := Label.new()
	next_name.text = "→ %s" % upgrade_item.get("name", "")
	next_name.add_theme_font_size_override("font_size", 16)
	next_name.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	next_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_section.add_child(next_name)

	# 効果比較
	var current_effects: Dictionary = item.get("effects", {})
	var new_effects: Dictionary = upgrade_item.get("effects", {})
	_upgrade_section.add_child(_build_effects_comparison(current_effects, new_effects))

	# アップグレードコスト = 新アイテム全額 - 旧アイテム売却返金
	var current_cost: int = item.get("cost", 0)
	var new_cost: int = upgrade_item.get("cost", 0)
	var upgrade_cost := maxi(new_cost - int(current_cost * FurnitureManager.SELL_REFUND_RATE), 0)

	# アップグレードボタン
	_upgrade_button = Button.new()
	_upgrade_button.text = "アップグレード (%d万円)" % upgrade_cost
	_upgrade_button.custom_minimum_size = Vector2(0, 48)
	_upgrade_button.add_theme_font_size_override("font_size", 18)
	_upgrade_button.add_theme_color_override("font_color", COLOR_TEXT_WHITE)

	var can_afford := GameState.cash >= upgrade_cost
	if can_afford:
		_apply_stylebox_to_button(_upgrade_button, COLOR_UPGRADE_BTN)
	else:
		KenneyTheme.apply_button_style(_upgrade_button, "grey")
		_upgrade_button.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		_upgrade_button.disabled = true

	_upgrade_button.pressed.connect(
		_on_upgrade_pressed.bind(_current_instance_id, upgrade_to, upgrade_cost)
	)
	_upgrade_section.add_child(_upgrade_button)


## 効果の比較表示（現在 → アップグレード後）
func _build_effects_comparison(current: Dictionary, upgraded: Dictionary) -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 全効果タイプを集める
	var all_types: Array[String] = []
	for t in current:
		if not all_types.has(t):
			all_types.append(t)
	for t in upgraded:
		if not all_types.has(t):
			all_types.append(t)

	for effect_type in all_types:
		var cur_val: int = current.get(effect_type, 0)
		var new_val: int = upgraded.get(effect_type, 0)
		var icon: String = OfficeBuffManager.get_effect_icon(effect_type)
		var ename: String = OfficeBuffManager.get_effect_display_name(effect_type)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var icon_lbl := Label.new()
		icon_lbl.text = icon
		icon_lbl.add_theme_font_size_override("font_size", 14)
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = ename
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var arrow_lbl := Label.new()
		var cur_sign := "+" if cur_val >= 0 else ""
		var new_sign := "+" if new_val >= 0 else ""
		arrow_lbl.text = "%s%d → %s%d" % [cur_sign, cur_val, new_sign, new_val]
		arrow_lbl.add_theme_font_size_override("font_size", 14)
		if new_val > cur_val:
			arrow_lbl.add_theme_color_override("font_color", COLOR_EFFECT_POSITIVE)
		elif new_val < cur_val:
			arrow_lbl.add_theme_color_override("font_color", COLOR_EFFECT_NEGATIVE)
		else:
			arrow_lbl.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
		arrow_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		arrow_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(arrow_lbl)

		vbox.add_child(row)

	return vbox


# ==========================================================
#  UIヘルパー
# ==========================================================

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", COLOR_SEPARATOR)
	return sep


func _make_action_button(text: String, bg_color: Color) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	_apply_stylebox_to_button(btn, bg_color)
	return btn


## ボタンにStyleBoxFlatを適用する
func _apply_stylebox_to_button(btn: Button, bg_color: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", sb)

	var hover_sb := sb.duplicate()
	hover_sb.bg_color = bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("hover", hover_sb)

	var pressed_sb := sb.duplicate()
	pressed_sb.bg_color = bg_color.darkened(0.15)
	btn.add_theme_stylebox_override("pressed", pressed_sb)


# ==========================================================
#  イベントハンドラ
# ==========================================================

func _on_move_pressed() -> void:
	if not _is_open or _confirm_mode:
		return
	AudioManager.play_sfx("click")
	var inst_id := _current_instance_id
	close()
	furniture_moved.emit(inst_id)


func _on_sell_pressed() -> void:
	if not _is_open or _confirm_mode:
		return
	AudioManager.play_sfx("click")
	_confirm_mode = true
	_button_row.visible = false
	_confirm_row.visible = true


func _on_confirm_sell() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("cash")
	var inst_id := _current_instance_id
	FurnitureManager.sell_furniture(inst_id)
	_is_open = false
	_confirm_mode = false
	_panel_root.visible = false
	furniture_sold.emit(inst_id)


func _on_cancel_sell() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	_confirm_mode = false
	_button_row.visible = true
	_confirm_row.visible = false


## アップグレード処理
## 手順: sell_furniture（返金）→ purchase_item（全額支払い）→ place_furniture（同じ位置）
## 実質コスト = new_cost - old_cost * SELL_REFUND_RATE
func _on_upgrade_pressed(instance_id: int, new_item_id: String, upgrade_cost: int) -> void:
	if not _is_open or _confirm_mode:
		return

	if GameState.cash < upgrade_cost:
		AudioManager.play_sfx("click")
		return

	AudioManager.play_sfx("success")

	# 現在の配置位置を保存
	var placed_list := FurnitureManager.get_placed_furniture()
	var grid_pos := Vector2i.ZERO
	for p in placed_list:
		if p["instance_id"] == instance_id:
			grid_pos = p["grid_position"]
			break

	# 旧家具を売却（返金される: old_cost * SELL_REFUND_RATE）
	var refund := FurnitureManager.sell_furniture(instance_id)
	if refund == 0:
		# sell失敗 — instance_idが見つからない等
		return

	# 新家具を購入（全額支払い: new_cost）
	var purchased := FurnitureManager.purchase_item(new_item_id)
	if not purchased:
		# 資金不足で購入失敗 — 返金は既に行われているので状態は一貫している
		# ただし旧家具は失われた状態。UIで事前チェック済みなので通常到達しない
		push_warning("FurnitureDetailPopup: アップグレード購入失敗 (資金不足)")
		_is_open = false
		_panel_root.visible = false
		popup_closed.emit()
		return

	# 新家具を同じ位置に配置
	var new_inst_id := FurnitureManager.place_furniture(new_item_id, grid_pos)
	if new_inst_id == -1:
		# 配置失敗（サイズ変更でグリッドに収まらない等）
		# 新アイテムはインベントリに残る（プレイヤーが手動配置可能）
		push_warning("FurnitureDetailPopup: アップグレード配置失敗 (サイズ不適合)")

	_is_open = false
	_panel_root.visible = false
	furniture_upgraded.emit(instance_id, new_item_id)


func _on_close_pressed() -> void:
	if not _is_open:
		return
	AudioManager.play_sfx("click")
	close()
