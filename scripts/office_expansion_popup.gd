extends CanvasLayer
## オフィス拡張ポップアップ — ゾーン（サーバールーム、休憩室等）を閲覧・購入できる

signal zone_purchased(zone_id: String)
signal popup_closed

var _is_open := false
var _confirm_overlay: Control = null

# UI refs
var _panel_root: Control
var _overlay: ColorRect
var _title_label: Label
var _cash_label: Label
var _info_label: Label
var _scroll: ScrollContainer
var _items_container: VBoxContainer
var _close_button: Button

# スタイル定数（furniture_shop_popup と統一）
const COLOR_PANEL_BG := Color(0.08, 0.10, 0.16, 1.0)
const COLOR_TITLE := Color(0.95, 0.85, 0.40)
const COLOR_TEXT_WHITE := Color(0.95, 0.95, 0.97)
const COLOR_TEXT_GRAY := Color(0.65, 0.67, 0.72)
const COLOR_ACCENT := Color(0.35, 0.65, 0.85)
const COLOR_BUY_BTN := Color(0.18, 0.48, 0.32)
const COLOR_BUY_BTN_HOVER := Color(0.22, 0.55, 0.38)
const COLOR_LOCKED := Color(0.12, 0.13, 0.17)
const COLOR_LOCKED_TEXT := Color(0.45, 0.45, 0.50)
const COLOR_COST_RED := Color(0.90, 0.40, 0.35)
const COLOR_PURCHASED := Color(0.55, 0.85, 0.55)

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


## ポップアップを開く
func show_popup() -> void:
	_update_cash_display()
	_update_info_display()
	_refresh_zones()
	_panel_root.visible = true
	_is_open = true


## ポップアップを閉じる
func close() -> void:
	if not _is_open:
		return
	_dismiss_confirm()
	_panel_root.visible = false
	_is_open = false
	popup_closed.emit()


## ゾーンカード一覧を再構築
func _refresh_zones() -> void:
	for child in _items_container.get_children():
		child.queue_free()

	# 全ゾーンを required_phase 順にソートして表示
	var zone_ids: Array = OfficeExpansionManager.ZONES.keys()
	zone_ids.sort_custom(func(a, b):
		var pa: int = OfficeExpansionManager.ZONES[a].get("required_phase", 0)
		var pb: int = OfficeExpansionManager.ZONES[b].get("required_phase", 0)
		return pa < pb
	)

	for zone_id in zone_ids:
		var card := _build_zone_card(zone_id)
		_items_container.add_child(card)


## ゾーンカードを1つ構築
func _build_zone_card(zone_id: String) -> PanelContainer:
	var zone: Dictionary = OfficeExpansionManager.ZONES[zone_id]
	var zone_name: String = zone.get("name", "")
	var zone_icon: String = zone.get("icon", "")
	var zone_cost: int = zone.get("cost", 0)
	var zone_desc: String = zone.get("description", "")
	var effects: Dictionary = zone.get("effects", {})
	var required_phase: int = zone.get("required_phase", 0)
	var size_bonus: Vector2i = zone.get("size_bonus", Vector2i.ZERO)

	var current_phase: int = GameState.current_phase
	var is_locked: bool = current_phase < required_phase
	var is_purchased: bool = OfficeExpansionManager.is_zone_purchased(zone_id)
	var can_afford: bool = GameState.cash >= zone_cost

	# カードスタイル
	var card_style := StyleBoxFlat.new()
	if is_locked:
		card_style.bg_color = COLOR_LOCKED
	elif is_purchased:
		card_style.bg_color = Color(0.10, 0.16, 0.14)
	else:
		card_style.bg_color = Color(0.12, 0.14, 0.20)
	card_style.corner_radius_top_left = 10
	card_style.corner_radius_top_right = 10
	card_style.corner_radius_bottom_left = 10
	card_style.corner_radius_bottom_right = 10
	card_style.border_width_left = 3
	if is_locked:
		card_style.border_color = Color(0.25, 0.25, 0.30)
	elif is_purchased:
		card_style.border_color = COLOR_PURCHASED
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

	# 上部: アイコン + 情報
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	outer_vbox.add_child(hbox)

	# アイコン表示
	var icon_container := PanelContainer.new()
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.15, 0.17, 0.24) if not is_locked else Color(0.10, 0.10, 0.13)
	icon_style.corner_radius_top_left = 8
	icon_style.corner_radius_top_right = 8
	icon_style.corner_radius_bottom_left = 8
	icon_style.corner_radius_bottom_right = 8
	icon_style.content_margin_left = 4
	icon_style.content_margin_right = 4
	icon_style.content_margin_top = 4
	icon_style.content_margin_bottom = 4
	icon_container.add_theme_stylebox_override("panel", icon_style)
	icon_container.custom_minimum_size = Vector2(56, 56)
	icon_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hbox.add_child(icon_container)

	var icon_label := Label.new()
	icon_label.text = zone_icon
	icon_label.add_theme_font_size_override("font_size", 32)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.custom_minimum_size = Vector2(48, 48)
	if is_locked:
		icon_label.modulate = Color(0.5, 0.5, 0.5)
	icon_container.add_child(icon_label)

	# 右側: テキスト情報
	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	# 1行目: 名前 + コスト
	var name_hbox := HBoxContainer.new()
	name_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(name_hbox)

	var name_label := Label.new()
	name_label.text = zone_name
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE if not is_locked else COLOR_LOCKED_TEXT)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_hbox.add_child(name_label)

	var cost_label := Label.new()
	cost_label.text = "%d万円" % zone_cost
	cost_label.add_theme_font_size_override("font_size", 18)
	if is_locked:
		cost_label.add_theme_color_override("font_color", COLOR_LOCKED_TEXT)
	elif is_purchased:
		cost_label.add_theme_color_override("font_color", COLOR_PURCHASED)
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
		effects_label.add_theme_font_size_override("font_size", 16)
		effects_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY if not is_locked else COLOR_LOCKED_TEXT)
		effects_label.clip_text = true
		info_vbox.add_child(effects_label)

	# 3行目: 説明
	if zone_desc != "":
		var desc_label := Label.new()
		desc_label.text = zone_desc
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.50, 0.52, 0.58) if not is_locked else COLOR_LOCKED_TEXT)
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_label)

	# サイズボーナス表示
	if size_bonus != Vector2i.ZERO:
		var size_label := Label.new()
		size_label.text = "\U0001F4D0 部屋拡張: +%dx%d タイル" % [size_bonus.x, size_bonus.y]
		size_label.add_theme_font_size_override("font_size", 14)
		size_label.add_theme_color_override("font_color", Color(0.60, 0.75, 0.90) if not is_locked else COLOR_LOCKED_TEXT)
		info_vbox.add_child(size_label)

	# ボタン or ステータスラベル
	if is_purchased:
		var purchased_label := Label.new()
		purchased_label.text = "\u2705 購入済み"
		purchased_label.add_theme_font_size_override("font_size", 18)
		purchased_label.add_theme_color_override("font_color", COLOR_PURCHASED)
		purchased_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		outer_vbox.add_child(purchased_label)
	elif is_locked:
		var lock_label := Label.new()
		var phase_name: String = PHASE_NAMES.get(required_phase, "Phase %d" % required_phase)
		lock_label.text = "\U0001F512 %sで解放" % phase_name
		lock_label.add_theme_font_size_override("font_size", 16)
		lock_label.add_theme_color_override("font_color", COLOR_LOCKED_TEXT)
		lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		outer_vbox.add_child(lock_label)
	else:
		# 購入ボタン
		var buy_btn := _create_buy_button(zone_id, can_afford, zone_cost)
		outer_vbox.add_child(buy_btn)

	return card


## 購入ボタンを作成
func _create_buy_button(zone_id: String, can_afford: bool, cost: int) -> Button:
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
	btn.text = "購入する (%d万円)" % cost
	btn.custom_minimum_size = Vector2(0, 44)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE if can_afford else COLOR_LOCKED_TEXT)
	btn.add_theme_stylebox_override("normal", btn_style)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.add_theme_stylebox_override("pressed", btn_hover)
	btn.add_theme_stylebox_override("disabled", btn_style)

	if not can_afford:
		btn.disabled = true
	else:
		var zid = zone_id
		btn.pressed.connect(func():
			AudioManager.play_sfx("click")
			_show_purchase_confirm(zid)
		)

	return btn


## 購入確認オーバーレイ
func _show_purchase_confirm(zone_id: String) -> void:
	_dismiss_confirm()

	var zone: Dictionary = OfficeExpansionManager.ZONES.get(zone_id, {})
	if zone.is_empty():
		return

	var zone_name: String = zone.get("name", "")
	var zone_icon: String = zone.get("icon", "")
	var zone_cost: int = zone.get("cost", 0)
	var zone_desc: String = zone.get("description", "")
	var effects: Dictionary = zone.get("effects", {})
	var size_bonus: Vector2i = zone.get("size_bonus", Vector2i.ZERO)

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
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	vbox.add_child(sep)

	# ゾーン名 + アイコン
	var name_label := Label.new()
	name_label.text = "%s %s" % [zone_icon, zone_name]
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_label)

	# 説明
	if zone_desc != "":
		var desc_label := Label.new()
		desc_label.text = zone_desc
		desc_label.add_theme_font_size_override("font_size", 18)
		desc_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_label)

	# 効果詳細パネル
	if not effects.is_empty():
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
		eff_title.add_theme_font_size_override("font_size", 18)
		eff_title.add_theme_color_override("font_color", COLOR_ACCENT)
		eff_vbox.add_child(eff_title)

		for effect_type in effects:
			var value: int = effects[effect_type]
			var icon_str: String = OfficeBuffManager.get_effect_icon(effect_type)
			var display_name: String = OfficeBuffManager.get_effect_display_name(effect_type)
			var sign: String = "+" if value > 0 else ""
			var eff_label := Label.new()
			eff_label.text = "%s %s: %s%s" % [icon_str, display_name, sign, str(value)]
			eff_label.add_theme_font_size_override("font_size", 18)
			eff_label.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
			eff_vbox.add_child(eff_label)

		effects_panel.add_child(eff_vbox)
		vbox.add_child(effects_panel)

	# サイズボーナス
	if size_bonus != Vector2i.ZERO:
		var size_label := Label.new()
		size_label.text = "\U0001F4D0 部屋拡張: +%dx%d タイル" % [size_bonus.x, size_bonus.y]
		size_label.add_theme_font_size_override("font_size", 18)
		size_label.add_theme_color_override("font_color", Color(0.60, 0.75, 0.90))
		size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(size_label)

	# コスト表示
	var cost_info := Label.new()
	cost_info.text = "\U0001F4B0 %d万円 \u2192 残り %d万円" % [zone_cost, GameState.cash - zone_cost]
	cost_info.add_theme_font_size_override("font_size", 20)
	cost_info.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	cost_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(cost_info)

	# ボタン: 購入 + キャンセル
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_hbox)

	var buy_btn := Button.new()
	buy_btn.text = "購入する (%d万円)" % zone_cost
	buy_btn.custom_minimum_size = Vector2(280, 52)
	buy_btn.add_theme_font_size_override("font_size", 20)
	buy_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(buy_btn, "green")
	var zid = zone_id
	buy_btn.pressed.connect(func():
		AudioManager.play_sfx("cash")
		_on_buy_confirmed(zid)
	)
	btn_hbox.add_child(buy_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "キャンセル"
	cancel_btn.custom_minimum_size = Vector2(180, 52)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.add_theme_color_override("font_color", COLOR_TEXT_WHITE)
	KenneyTheme.apply_button_style(cancel_btn, "grey")
	cancel_btn.pressed.connect(func():
		AudioManager.play_sfx("click")
		_dismiss_confirm()
	)
	btn_hbox.add_child(cancel_btn)


## 購入実行
func _on_buy_confirmed(zone_id: String) -> void:
	var success: bool = OfficeExpansionManager.purchase_zone(zone_id)
	_dismiss_confirm()

	if success:
		AudioManager.play_sfx("success")
		zone_purchased.emit(zone_id)

		# 表示を更新
		_update_cash_display()
		_update_info_display()
		_refresh_zones()
	else:
		_refresh_zones()


## 確認オーバーレイを消す
func _dismiss_confirm() -> void:
	if _confirm_overlay != null:
		_confirm_overlay.queue_free()
		_confirm_overlay = null


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
		_cash_label.text = "\U0001F4B0 %d万円" % GameState.cash


## オフィス情報表示を更新
func _update_info_display() -> void:
	if not _info_label:
		return

	var phase: int = GameState.current_phase
	# office_tilemap.gd の OFFICE_NAMES と同等
	var office_names := ["自宅ガレージ", "小さなオフィス", "コワーキングスペース", "自社オフィス", "フロア貸しオフィス", "自社ビル"]
	var room_sizes := {
		0: Vector2i(16, 10), 1: Vector2i(22, 14), 2: Vector2i(28, 16),
		3: Vector2i(36, 20), 4: Vector2i(44, 24), 5: Vector2i(56, 30),
	}

	var clamped_phase := clampi(phase, 0, office_names.size() - 1)
	var office_name: String = office_names[clamped_phase]
	var base_size: Vector2i = room_sizes.get(clamped_phase, Vector2i(16, 10))
	var bonus: Vector2i = OfficeExpansionManager.get_total_size_bonus()

	var text := "%s (%dx%d)" % [office_name, base_size.x, base_size.y]
	if bonus != Vector2i.ZERO:
		text += "  +%dx%d ゾーン拡張" % [bonus.x, bonus.y]

	var purchased_count: int = OfficeExpansionManager.get_purchased_zones().size()
	var total_zones: int = OfficeExpansionManager.ZONES.size()
	text += "\n設置済みゾーン: %d / %d" % [purchased_count, total_zones]

	_info_label.text = text


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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel_root.add_child(center)

	# メインパネル
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 950)
	KenneyTheme.apply_panel_style(panel, "popup")
	center.add_child(panel)

	# メインVBox
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	panel.add_child(main_vbox)

	# タイトル
	_title_label = Label.new()
	_title_label.text = "\U0001F3D7\uFE0F オフィス拡張"
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_title_label)

	# 資金表示
	_cash_label = Label.new()
	_cash_label.text = "\U0001F4B0 0万円"
	_cash_label.add_theme_font_size_override("font_size", 22)
	_cash_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.70))
	_cash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(_cash_label)

	# オフィス情報
	_info_label = Label.new()
	_info_label.text = ""
	_info_label.add_theme_font_size_override("font_size", 16)
	_info_label.add_theme_color_override("font_color", COLOR_TEXT_GRAY)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main_vbox.add_child(_info_label)

	# 区切り線
	var sep := HSeparator.new()
	sep.add_theme_color_override("separator_color", Color(0.30, 0.32, 0.40))
	main_vbox.add_child(sep)

	# ゾーンスクロールエリア
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
	_close_button.add_theme_font_size_override("font_size", 24)
	_close_button.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	KenneyTheme.apply_button_style(_close_button, "grey")
	_close_button.pressed.connect(func():
		AudioManager.play_sfx("click")
		close()
	)
	main_vbox.add_child(_close_button)
