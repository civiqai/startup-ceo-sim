extends CanvasLayer
## 家具ショップポップアップ — カテゴリ別に家具を閲覧・購入できる
## FurnitureData / FurnitureManager autoload と連携

signal furniture_purchased(item_id: String)
signal placement_requested(item_id: String)
signal popup_closed()

var _is_open := false
var _current_category := ""
var _confirm_item_id := ""

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _cash_label: Label
var _category_container: HBoxContainer
var _category_buttons: Dictionary = {}  # category_id -> Button
var _scroll: ScrollContainer
var _items_container: VBoxContainer
var _close_button: Button
var _confirm_overlay: Control = null

# スタイル定数
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_PANEL_BORDER := Color(0.30, 0.45, 0.55)
const COLOR_TITLE := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_ACCENT := Color(0.35, 0.65, 0.85)
const COLOR_BUY_BTN := Color(0.18, 0.48, 0.32)
const COLOR_BUY_BTN_HOVER := Color(0.22, 0.55, 0.38)
const COLOR_CATEGORY_ACTIVE := Color(0.25, 0.50, 0.70)
const COLOR_CATEGORY_INACTIVE := Color(0.18, 0.20, 0.26)
const COLOR_LOCKED := Color(0.12, 0.13, 0.17)
const COLOR_LOCKED_TEXT := Color(0.45, 0.45, 0.50)
const COLOR_COST_RED := Color(0.90, 0.40, 0.35)
const COLOR_PLACED := Color(0.55, 0.85, 0.55)

# フェーズ名
const PHASE_NAMES := {
	0: "ガレージ期",
	1: "シード期",
	2: "アーリー期",
	3: "シリーズA期",
	4: "グロース期",
	5: "レイター期",
}


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


## ショップを開く
func show_shop() -> void:
	var categories = FurnitureData.get_all_categories()
	if categories.size() > 0:
		_current_category = categories[0].get("id", "")
	_update_cash_display()
	_rebuild_category_buttons()
	_refresh_items()
	_panel_root.visible = true
	_is_open = true


## ショップを閉じる
func close() -> void:
	if not _is_open:
		return
	_dismiss_confirm()
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


## 現在のカテゴリのアイテム一覧を再構築
func _refresh_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	if _current_category == "":
		return

	var items = FurnitureData.get_items_by_category(_current_category)
	for item in items:
		var card := _build_item_card(item)
		_items_container.add_child(card)

	# アイテムがない場合
	if items.size() == 0:
		var empty_label := Label.new()
		empty_label.text = "このカテゴリには家具がありません"
		empty_label.add_theme_font_size_override("font_size", 24)
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_container.add_child(empty_label)


## アイテムカードを1つ構築
func _build_item_card(item: Dictionary) -> PanelContainer:
	var item_id: String = item.get("id", "")
	var item_name: String = item.get("name", "")
	var item_icon: String = item.get("icon", "")
	var item_cost: int = item.get("cost", 0)
	var item_desc: String = item.get("description", "")
	var effects: Dictionary = item.get("effects", {})
	var required_phase: int = item.get("required_phase", 0)
	var upgrade_from: String = item.get("upgrade_from", "")
	var texture_path: String = item.get("texture", "")

	var current_phase: int = GameState.current_phase
	var is_locked: bool = current_phase < required_phase
	var can_afford: bool = GameState.cash >= item_cost
	var placed_count: int = FurnitureManager.get_placed_count(item_id)
	var can_purchase: bool = FurnitureManager.can_purchase(item_id)

	# アップグレード判定
	var is_upgrade := upgrade_from != ""
	var has_base := false
	var upgrade_cost := item_cost
	if is_upgrade:
		has_base = FurnitureManager.get_placed_count(upgrade_from) > 0
		if has_base:
			var base_item = FurnitureData.get_item(upgrade_from)
			var base_cost: int = base_item.get("cost", 0) if base_item else 0
			upgrade_cost = maxi(item_cost - base_cost, 0)
			can_afford = GameState.cash >= upgrade_cost

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	if is_locked:
		card_style.bg_color = COLOR_LOCKED
	else:
		card_style.bg_color = Color(0.12, 0.14, 0.20)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	if is_locked:
		card_style.border_color = Color(0.25, 0.25, 0.30)
	else:
		card_style.border_color = COLOR_ACCENT
	card_style.content_margin_left = 14
	card_style.content_margin_top = 12
	card_style.content_margin_right = 14
	card_style.content_margin_bottom = 12

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", card_style)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 6)
	card.add_child(outer_vbox)

	# 上部: プレビュー + 情報
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(hbox)

	# 家具プレビュー (TextureRect or アイコンフォールバック)
	var preview_container := PanelContainer.new()
	var preview_style := StyleBoxFlat.new()
	preview_style.bg_color = Color(0.15, 0.17, 0.24) if not is_locked else Color(0.10, 0.10, 0.13)
	preview_style.corner_radius_top_left = 8
	preview_style.corner_radius_top_right = 8
	preview_style.corner_radius_bottom_left = 8
	preview_style.corner_radius_bottom_right = 8
	preview_style.content_margin_left = 4
	preview_style.content_margin_right = 4
	preview_style.content_margin_top = 4
	preview_style.content_margin_bottom = 4
	preview_container.add_theme_stylebox_override("panel", preview_style)
	preview_container.custom_minimum_size = Vector2(56, 56)
	preview_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(preview_container)

	# テクスチャ画像を試行、なければアイコンテキスト
	var has_texture := false
	if texture_path != "" and ResourceLoader.exists(texture_path):
		var tex := load(texture_path) as Texture2D
		if tex:
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = Vector2(48, 48)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if is_locked:
				tex_rect.modulate = Color(0.4, 0.4, 0.4)
			preview_container.add_child(tex_rect)
			has_texture = true

	if not has_texture:
		var icon_label := Label.new()
		icon_label.text = item_icon if item_icon != "" else "🪑"
		icon_label.add_theme_font_size_override("font_size", 36)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.custom_minimum_size = Vector2(48, 48)
		if is_locked:
			icon_label.modulate = Color(0.5, 0.5, 0.5)
		preview_container.add_child(icon_label)

	# 右側: テキスト情報
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# 1行目: 名前 + コスト + 所持数
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE if not is_locked else COLOR_LOCKED_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_hbox.add_child(name_label)

	if placed_count > 0 and not is_locked:
		var count_label := Label.new()
		count_label.text = "(所持: %d)" % placed_count
		count_label.add_theme_font_size_override("font_size", 20)
		count_label.add_theme_color_override("font_color", COLOR_PLACED)
		name_hbox.add_child(count_label)

	# コスト表示
	var display_cost := upgrade_cost if (is_upgrade and has_base) else item_cost
	var cost_label := Label.new()
	if is_upgrade and has_base:
		cost_label.text = "⬆ %d万円" % display_cost
	else:
		cost_label.text = "%d万円" % display_cost
	cost_label.add_theme_font_size_override("font_size", 22)
	if is_locked:
		cost_label.add_theme_color_override("font_color", COLOR_LOCKED_TEXT)
	elif not can_afford:
		cost_label.add_theme_color_override("font_color", COLOR_COST_RED)
	else:
		cost_label.add_theme_color_override("font_color", COLOR_ACCENT)
	name_hbox.add_child(cost_label)

	# 2行目: エフェクト要約
	var effects_text := _format_effects(effects)
	if effects_text != "":
		var effects_label := Label.new()
		effects_label.text = effects_text
		effects_label.add_theme_font_size_override("font_size", 20)
		effects_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY if not is_locked else COLOR_LOCKED_TEXT)
		effects_label.clip_text = true
		info_vbox.add_child(effects_label)

	# 3行目: 説明 (1行に制限)
	if item_desc != "":
		var desc_label := Label.new()
		desc_label.text = item_desc
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58) if not is_locked else COLOR_LOCKED_TEXT)
		desc_label.clip_text = true
		desc_label.custom_minimum_size = Vector2(0, 0)
		info_vbox.add_child(desc_label)

	# ボタン or ステータスラベル
	if is_locked:
		var lock_label := Label.new()
		var phase_name: String = PHASE_NAMES.get(required_phase, "Phase %d" % required_phase)
		lock_label.text = "🔒 %sで解放" % phase_name
		lock_label.add_theme_font_size_override("font_size", 20)
		lock_label.add_theme_color_override("font_color", COLOR_LOCKED_TEXT)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		outer_vbox.add_child(lock_label)
	elif not can_purchase and placed_count > 0:
		# 既に配置済みで追加購入不可
		var placed_label := Label.new()
		placed_label.text = "✅ 配置済み"
		placed_label.add_theme_font_size_override("font_size", 22)
		placed_label.add_theme_color_override("font_color", COLOR_PLACED)
		placed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		outer_vbox.add_child(placed_label)
	else:
		# 購入ボタン
		var buy_btn := _create_buy_button(item_id, is_upgrade and has_base, can_afford, display_cost)
		outer_vbox.add_child(buy_btn)

	return card


## 購入ボタンを作成
func _create_buy_button(item_id: String, is_upgrade: bool, can_afford: bool, cost: int) -> Button:
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = COLOR_BUY_BTN if can_afford else Color(0.20, 0.22, 0.28)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_top = 6
	btn_style.content_margin_bottom = 6

	var btn_hover := btn_style.duplicate()
	if can_afford:
		btn_hover.bg_color = COLOR_BUY_BTN_HOVER

	var btn := Button.new()
	if is_upgrade:
		btn.text = "⬆ アップグレード (%d万円)" % cost
	else:
		btn.text = "購入する (%d万円)" % cost
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE if can_afford else COLOR_LOCKED_TEXT)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)
	btn.add_theme_stylebox_override("disabled", btn_style)

	if not can_afford:
		btn.disabled = true
	else:
		var iid = item_id
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_show_purchase_confirm(iid)
		)

	return btn


## 購入確認オーバーレイを表示
func _show_purchase_confirm(item_id: String) -> void:
	_dismiss_confirm()
	_confirm_item_id = item_id

	var item = FurnitureData.get_item(item_id)
	if not item:
		return

	var item_name: String = item.get("name", "")
	var item_icon: String = item.get("icon", "")
	var item_cost: int = item.get("cost", 0)
	var item_desc: String = item.get("description", "")
	var effects: Dictionary = item.get("effects", {})
	var upgrade_from: String = item.get("upgrade_from", "")

	# アップグレードコスト計算
	var display_cost := item_cost
	if upgrade_from != "":
		var has_base := FurnitureManager.get_placed_count(upgrade_from) > 0
		if has_base:
			var base_item = FurnitureData.get_item(upgrade_from)
			var base_cost: int = base_item.get("cost", 0) if base_item else 0
			display_cost = maxi(item_cost - base_cost, 0)

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_confirm_overlay)

	# 暗い背景
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(bg)

	# 中央配置
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	# タイトル
	var title := Label.new()
	title.text = "購入確認"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# アイテム名 + アイコン
	var name_label := Label.new()
	name_label.text = "%s %s" % [item_icon, item_name]
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 説明
	if item_desc != "":
		var desc_label := Label.new()
		desc_label.text = item_desc
		desc_label.add_theme_font_size_override("font_size", 22)
		desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

	# 全エフェクト詳細
	if effects.size() > 0:
		var effects_panel := PanelContainer.new()
		var eff_style := StyleBoxFlat.new()
		eff_style.bg_color = Color(0.10, 0.14, 0.22)
		eff_style.corner_radius_top_left = 8
		eff_style.corner_radius_top_right = 8
		eff_style.corner_radius_bottom_left = 8
		eff_style.corner_radius_bottom_right = 8
		eff_style.content_margin_left = 14
		eff_style.content_margin_right = 14
		eff_style.content_margin_top = 10
		eff_style.content_margin_bottom = 10
		effects_panel.add_theme_stylebox_override("panel", eff_style)

		var eff_vbox := VBoxContainer.new()
		eff_vbox.add_theme_constant_override("separation", 4)

		var eff_title := Label.new()
		eff_title.text = "効果"
		eff_title.add_theme_font_size_override("font_size", 22)
		eff_title.add_theme_color_override("font_color", COLOR_ACCENT)
		eff_vbox.add_child(eff_title)

		for effect_type in effects:
			var value: int = effects[effect_type]
			var icon_str: String = OfficeBuffManager.get_effect_icon(effect_type)
			var display_name: String = OfficeBuffManager.get_effect_display_name(effect_type)
			var sign: String = "+" if value > 0 else ""
			var eff_label := Label.new()
			eff_label.text = "%s %s: %s%s" % [icon_str, display_name, sign, str(value)]
			eff_label.add_theme_font_size_override("font_size", 22)
			eff_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
			eff_vbox.add_child(eff_label)

		effects_panel.add_child(eff_vbox)
		vbox.add_child(effects_panel)

	# コスト表示
	var cost_info := Label.new()
	cost_info.text = "💰 %d万円 → 残り %d万円" % [display_cost, GameState.cash - display_cost]
	cost_info.add_theme_font_size_override("font_size", 24)
	cost_info.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	cost_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_info)

	# ボタン: 購入する + キャンセル
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	# 購入ボタン
	var buy_btn := Button.new()
	buy_btn.text = "購入する (%d万円)" % display_cost
	buy_btn.custom_minimum_size = Vector2(280, 52)
	buy_btn.add_theme_font_size_override("font_size", 24)
	buy_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(buy_btn, "green")
	var iid = item_id
	buy_btn.pressed.connect(func():
		AudioManager.play_sfx("cash")
		_on_buy_confirmed(iid)
	)
	btn_hbox.add_child(buy_btn)

	# キャンセルボタン
	var cancel_btn := Button.new()
	cancel_btn.text = "キャンセル"
	cancel_btn.custom_minimum_size = Vector2(180, 52)
	cancel_btn.add_theme_font_size_override("font_size", 24)
	KenneyTheme.apply_button_style(cancel_btn, "grey")
	cancel_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_dismiss_confirm()
	)
	btn_hbox.add_child(cancel_btn)


## 購入実行
func _on_buy_confirmed(item_id: String) -> void:
	var success: bool = FurnitureManager.purchase_item(item_id)
	_dismiss_confirm()

	if success:
		AudioManager.play_sfx("success")
		furniture_purchased.emit(item_id)

		# 資金表示を更新
		_update_cash_display()

		# 「すぐに配置しますか？」確認を表示
		_show_placement_prompt(item_id)
	else:
		# 購入失敗 — リスト再構築のみ
		_refresh_items()


## 配置確認プロンプト
func _show_placement_prompt(item_id: String) -> void:
	_dismiss_confirm()

	var item = FurnitureData.get_item(item_id)
	var item_name: String = item.get("name", "") if item else item_id
	var item_icon: String = item.get("icon", "") if item else ""

	_confirm_overlay = Control.new()
	_confirm_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_confirm_overlay)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.85)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_overlay.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var msg := Label.new()
	msg.text = "%s %s を購入しました！\nすぐに配置しますか？" % [item_icon, item_name]
	msg.add_theme_font_size_override("font_size", 26)
	msg.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	# 配置するボタン
	var place_btn := Button.new()
	place_btn.text = "配置する"
	place_btn.custom_minimum_size = Vector2(200, 52)
	place_btn.add_theme_font_size_override("font_size", 24)
	place_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(place_btn, "green")
	var iid = item_id
	place_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_dismiss_confirm()
		_panel_root.visible = false
		_is_open = false
		placement_requested.emit(iid)
	)
	btn_hbox.add_child(place_btn)

	# あとでボタン
	var later_btn := Button.new()
	later_btn.text = "あとで"
	later_btn.custom_minimum_size = Vector2(160, 52)
	later_btn.add_theme_font_size_override("font_size", 24)
	KenneyTheme.apply_button_style(later_btn, "grey")
	later_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_dismiss_confirm()
		_refresh_items()
	)
	btn_hbox.add_child(later_btn)


## 確認オーバーレイを消す
func _dismiss_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null
	_confirm_item_id = ""


## エフェクト辞書をコンパクトなテキストに変換
func _format_effects(effects: Dictionary) -> String:
	if effects.is_empty():
		return ""
	var parts: Array[String] = []
	for effect_type in effects:
		var value: int = effects[effect_type]
		var icon_str: String = OfficeBuffManager.get_effect_icon(effect_type)
		var sign: String = "+" if value > 0 else ""
		parts.append("%s%s%s" % [icon_str, sign, str(value)])
	return " ".join(parts)


## 資金表示を更新
func _update_cash_display() -> void:
	if _cash_label:
		_cash_label.text = "💰 %d万円" % GameState.cash


## カテゴリボタンの状態を更新
func _update_category_buttons() -> void:
	for cat_id in _category_buttons:
		var btn: Button = _category_buttons[cat_id]
		var is_active: bool = cat_id == _current_category

		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CATEGORY_ACTIVE if is_active else COLOR_CATEGORY_INACTIVE
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 6
		style.content_margin_bottom = 6

		var hover_style := style.duplicate()
		hover_style.bg_color = COLOR_CATEGORY_ACTIVE.lightened(0.1) if is_active else COLOR_CATEGORY_INACTIVE.lightened(0.15)

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE if is_active else COLOR_TEXT_GRAY)


## カテゴリボタンを再構築
func _rebuild_category_buttons() -> void:
	for child in _category_container.get_children():
		child.queue_free()
	_category_buttons.clear()

	var categories = FurnitureData.get_all_categories()
	for cat in categories:
		var cat_id: String = cat.get("id", "")
		var cat_icon: String = cat.get("icon", "")
		var cat_name: String = cat.get("name", "")

		var btn := Button.new()
		btn.text = "%s\n%s" % [cat_icon, cat_name]
		btn.custom_minimum_size = Vector2(90, 56)
		btn.add_theme_font_size_override("font_size", 18)
		var cid = cat_id
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_on_category_pressed(cid)
		)
		_category_container.add_child(btn)
		_category_buttons[cat_id] = btn

	_update_category_buttons()


## カテゴリ切り替え
func _on_category_pressed(category_id: String) -> void:
	if category_id == _current_category:
		return
	_current_category = category_id
	_update_category_buttons()
	_refresh_items()
	# スクロールを先頭に戻す
	_scroll.scroll_vertical = 0


## UIをコードで構築
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
	_overlay.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close()
	)
	_panel_root.add_child(_overlay)

	# 中央配置コンテナ
	# メインパネル
	var panel := PanelContainer.new()
	KenneyTheme.apply_panel_style(panel, "popup")
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = 0.03
	panel.anchor_bottom = 0.97
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(panel)

	# メインVBox
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "🛒 家具ショップ"
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	# 資金表示
	_cash_label = Label.new()
	_cash_label.text = "💰 0万円"
	_cash_label.add_theme_font_size_override("font_size", 26)
	_cash_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_cash_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	main_vbox.add_child(sep)

	# カテゴリタブ（横スクロール対応）
	var cat_scroll := ScrollContainer.new()
	cat_scroll.custom_minimum_size = Vector2(0, 68)
	cat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	main_vbox.add_child(cat_scroll)

	_category_container = HBoxContainer.new()
	_category_container.add_theme_constant_override("separation", 8)
	_category_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_scroll.add_child(_category_container)

	# アイテムスクロールエリア
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(_scroll)

	_items_container = VBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 10)
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_items_container)

	# 閉じるボタン
	_close_button = Button.new()
	_close_button.text = "閉じる"
	_close_button.custom_minimum_size = Vector2(0, 56)
	_close_button.add_theme_font_size_override("font_size", 28)
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(func():
		AudioManager.play_sfx("click")
		close()
	)
	main_vbox.add_child(_close_button)
