extends CanvasLayer
## オフィスビュー上に表示するステータスUIオーバーレイ
## CanvasLayer (layer 10) で TileMap の上にControl系ノードで描画

signal product_card_swiped(page_index: int)

const GAUGE_BG := Color(0.15, 0.16, 0.20, 1.0)
const GAUGE_UX := Color(0.35, 0.60, 0.90)
const GAUGE_DESIGN := Color(0.85, 0.50, 0.70)
const GAUGE_MARGIN := Color(0.55, 0.85, 0.55)
const GAUGE_AWARENESS := Color(0.90, 0.75, 0.30)
const GAUGE_REPUTATION := Color(0.90, 0.70, 0.25)
const GAUGE_BRAND := Color(0.80, 0.45, 0.65)
const GAUGE_MORALE := Color(0.50, 0.80, 0.50)

const SCREEN_W := 720.0
const TOP_BAR_H := 28.0
const BOTTOM_MAX_H := 320.0

# プロダクトカードスワイプ用
var _product_page: int = 0
var _product_count: int = 0
var _swipe_start_x: float = 0.0
var _is_swiping: bool = false

# UIノード参照
var _top_bar: PanelContainer
var _top_office_label: Label
var _top_runway_label: Label
var _bottom_panel: PanelContainer
var _bottom_scroll: ScrollContainer
var _bottom_vbox: VBoxContainer
var _product_container: Control
var _product_cards_container: HBoxContainer
var _page_indicator: HBoxContainer
var _gauges_container: VBoxContainer
var _valuation_label: Label
var _market_share_label: Label
var _equity_label: Label


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_bottom_section()
	# 初回更新
	call_deferred("refresh")
	# GameStateの変更を監視
	if GameState.has_signal("state_changed"):
		GameState.state_changed.connect(refresh)


func _exit_tree() -> void:
	if GameState.has_signal("state_changed") and GameState.state_changed.is_connected(refresh):
		GameState.state_changed.disconnect(refresh)


# ============================================================
# トップバー構築
# ============================================================

func _build_top_bar() -> void:
	_top_bar = PanelContainer.new()
	_top_bar.name = "TopBar"
	# フルスクリーン幅で上端に固定
	_top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top_bar.custom_minimum_size = Vector2(0, TOP_BAR_H)
	_top_bar.size = Vector2(SCREEN_W, TOP_BAR_H)
	# 半透明ダーク背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	_top_bar.add_theme_stylebox_override("panel", style)
	# タッチイベントを透過しない（トップバー自体はタップ可能エリア）
	_top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_top_office_label = Label.new()
	_top_office_label.name = "OfficeLabel"
	_top_office_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_office_label.add_theme_font_size_override("font_size", 16)
	_top_office_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.97))
	_top_office_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_top_runway_label = Label.new()
	_top_runway_label.name = "RunwayLabel"
	_top_runway_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_runway_label.add_theme_font_size_override("font_size", 14)
	_top_runway_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(_top_office_label)
	hbox.add_child(_top_runway_label)
	_top_bar.add_child(hbox)
	add_child(_top_bar)


# ============================================================
# ボトムセクション構築
# ============================================================

func _build_bottom_section() -> void:
	_bottom_panel = PanelContainer.new()
	_bottom_panel.name = "BottomPanel"
	_bottom_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# 半透明ダーク背景
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.10, 0.75)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	_bottom_panel.add_theme_stylebox_override("panel", style)
	# ボトムパネル自体はタッチを通す（子の操作可能部分のみ受け取る）
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_bottom_scroll = ScrollContainer.new()
	_bottom_scroll.name = "BottomScroll"
	_bottom_scroll.custom_minimum_size = Vector2(0, 0)
	_bottom_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# スクロールのみ縦方向
	_bottom_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bottom_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_bottom_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	_bottom_vbox = VBoxContainer.new()
	_bottom_vbox.name = "ContentVBox"
	_bottom_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_vbox.add_theme_constant_override("separation", 6)

	# プロダクトカードエリア
	_build_product_area()

	# 会社ゲージ
	_build_company_gauges()

	# 時価総額・シェア・持株
	_build_valuation_row()

	_bottom_scroll.add_child(_bottom_vbox)
	_bottom_panel.add_child(_bottom_scroll)
	add_child(_bottom_panel)


func _build_product_area() -> void:
	_product_container = Control.new()
	_product_container.name = "ProductArea"
	_product_container.custom_minimum_size = Vector2(0, 150)
	_product_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_product_container.gui_input.connect(_on_product_swipe_input)

	_product_cards_container = HBoxContainer.new()
	_product_cards_container.name = "Cards"
	_product_cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_product_container.add_child(_product_cards_container)

	# ページインジケーター（ドット）
	_page_indicator = HBoxContainer.new()
	_page_indicator.name = "PageDots"
	_page_indicator.alignment = BoxContainer.ALIGNMENT_CENTER
	_page_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_indicator.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_page_indicator.position.y = 138
	_page_indicator.size = Vector2(SCREEN_W - 16, 12)
	_product_container.add_child(_page_indicator)

	_bottom_vbox.add_child(_product_container)


func _build_company_gauges() -> void:
	_gauges_container = VBoxContainer.new()
	_gauges_container.name = "CompanyGauges"
	_gauges_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauges_container.add_theme_constant_override("separation", 4)
	_bottom_vbox.add_child(_gauges_container)


func _build_valuation_row() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ValuationSection"
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	_valuation_label = Label.new()
	_valuation_label.add_theme_font_size_override("font_size", 18)
	_valuation_label.add_theme_color_override("font_color", Color(0.50, 0.85, 0.80))
	_valuation_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hbox := HBoxContainer.new()
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_theme_constant_override("separation", 16)

	_market_share_label = Label.new()
	_market_share_label.add_theme_font_size_override("font_size", 18)
	_market_share_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.50))
	_market_share_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_equity_label = Label.new()
	_equity_label.add_theme_font_size_override("font_size", 18)
	_equity_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.40))
	_equity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hbox.add_child(_market_share_label)
	hbox.add_child(_equity_label)

	vbox.add_child(_valuation_label)
	vbox.add_child(hbox)
	_bottom_vbox.add_child(vbox)


# ============================================================
# データ更新
# ============================================================

func refresh() -> void:
	_update_top_bar()
	_update_product_cards()
	_update_company_gauges()
	_update_valuation()
	_update_bottom_layout()


func _update_top_bar() -> void:
	if _top_office_label == null:
		return
	_top_office_label.text = _get_office_name()

	var monthly = GameState.monthly_cost
	if monthly > 0 and GameState.cash > 0:
		var months_left = GameState.cash / monthly
		if months_left <= 3:
			_top_runway_label.text = "⚠️ 残り%dヶ月" % months_left
			_top_runway_label.add_theme_color_override("font_color", Color(0.90, 0.35, 0.30))
		elif months_left <= 6:
			_top_runway_label.text = "ランウェイ %dヶ月" % months_left
			_top_runway_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
		else:
			_top_runway_label.text = "ランウェイ %dヶ月" % months_left
			_top_runway_label.add_theme_color_override("font_color", Color(0.50, 0.75, 0.50))
	else:
		_top_runway_label.text = ""


func _update_product_cards() -> void:
	if _product_cards_container == null:
		return
	# 既存カードをクリア
	for child in _product_cards_container.get_children():
		child.queue_free()
	for child in _page_indicator.get_children():
		child.queue_free()

	var pm = _get_product_manager()
	if pm == null:
		_show_no_product_message()
		_product_count = 0
		_product_container.custom_minimum_size.y = 36
		return

	var active = pm.get_active_products()
	_product_count = active.size()
	if active.is_empty():
		_show_no_product_message()
		_product_container.custom_minimum_size.y = 36
		return

	_product_container.custom_minimum_size.y = 150
	_product_page = clampi(_product_page, 0, _product_count - 1)

	# 現在ページのカードのみ表示
	var product = active[_product_page]
	var card = _create_product_card(product, pm)
	_product_cards_container.add_child(card)

	# ページインジケーター（複数プロダクト時のみ）
	if _product_count > 1:
		for i in _product_count:
			var dot := ColorRect.new()
			dot.custom_minimum_size = Vector2(10, 10)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if i == _product_page:
				dot.color = Color(0.95, 0.85, 0.40)
			else:
				dot.color = Color(0.40, 0.42, 0.50)
			_page_indicator.add_child(dot)
		_page_indicator.visible = true
	else:
		_page_indicator.visible = false


func _show_no_product_message() -> void:
	var label := Label.new()
	label.text = "📦 プロダクトなし（PMを採用して立ち上げましょう）"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.50, 0.55, 0.65))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_product_cards_container.add_child(label)


func _create_product_card(product: Dictionary, pm) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(SCREEN_W - 32, 135)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.12, 0.18, 0.9)
	card_style.border_color = Color(0.25, 0.35, 0.50, 0.6)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 6.0
	card_style.content_margin_bottom = 6.0
	card.add_theme_stylebox_override("panel", card_style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)

	# プロダクト名
	var type_data = pm.PRODUCT_TYPES.get(product["type"], {})
	var icon = type_data.get("icon", "📦")
	var pname = product.get("name", "プロダクト")
	var title_label := Label.new()
	title_label.text = "%s %s" % [icon, pname]
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.40))
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(title_label)

	# ゲージ + 情報を横並び
	var content_hbox := HBoxContainer.new()
	content_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_hbox.add_theme_constant_override("separation", 12)

	# 左側: ゲージ群
	var gauges_vbox := VBoxContainer.new()
	gauges_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauges_vbox.size_flags_stretch_ratio = 1.4
	gauges_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauges_vbox.add_theme_constant_override("separation", 2)

	gauges_vbox.add_child(_create_mini_gauge("UX", product.get("ux", 0), 100, GAUGE_UX))
	gauges_vbox.add_child(_create_mini_gauge("デザイン", product.get("design", 0), 100, GAUGE_DESIGN))
	gauges_vbox.add_child(_create_mini_gauge("利益率", product.get("margin", 0), 100, GAUGE_MARGIN))
	gauges_vbox.add_child(_create_mini_gauge("知名度", product.get("awareness", 0), 100, GAUGE_AWARENESS))

	# 右側: ユーザー数・売上・技術的負債
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.size_flags_stretch_ratio = 1.0
	info_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_theme_constant_override("separation", 4)

	var users_label := Label.new()
	users_label.text = "📱 %s人" % _format_number(product.get("users", 0))
	users_label.add_theme_font_size_override("font_size", 16)
	users_label.add_theme_color_override("font_color", Color(0.75, 0.60, 0.88))
	users_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(users_label)

	var revenue_label := Label.new()
	revenue_label.text = "💹 %s万/月" % _format_number(_calc_product_revenue(product))
	revenue_label.add_theme_font_size_override("font_size", 16)
	revenue_label.add_theme_color_override("font_color", Color(0.55, 0.80, 0.55))
	revenue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(revenue_label)

	var debt_label := Label.new()
	debt_label.text = "🔧 負債: %d" % product.get("tech_debt", 0)
	debt_label.add_theme_font_size_override("font_size", 16)
	debt_label.add_theme_color_override("font_color", Color(0.80, 0.50, 0.40))
	debt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_vbox.add_child(debt_label)

	content_hbox.add_child(gauges_vbox)
	content_hbox.add_child(info_vbox)
	vbox.add_child(content_hbox)
	card.add_child(vbox)
	return card


func _create_mini_gauge(label_text: String, value: int, max_value: int, fill_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 18)
	row.add_theme_constant_override("separation", 4)

	# ラベル
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(68, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	# ゲージバー背景 + 塗り
	var bar_container := Control.new()
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.custom_minimum_size = Vector2(0, 12)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg := ColorRect.new()
	bar_bg.color = GAUGE_BG
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg)

	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = fill_color
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_right = ratio
	bar_fill.anchor_bottom = 1.0
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_fill)

	row.add_child(bar_container)

	# 数値
	var val_label := Label.new()
	val_label.text = "%d" % value
	val_label.custom_minimum_size = Vector2(32, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 13)
	val_label.add_theme_color_override("font_color", fill_color)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_label)

	return row


func _create_company_gauge(label_text: String, value: int, max_value: int, fill_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size = Vector2(0, 22)
	row.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(110, 0)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.70, 0.72, 0.78))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var bar_container := Control.new()
	bar_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_container.custom_minimum_size = Vector2(0, 14)
	bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg := ColorRect.new()
	bar_bg.color = GAUGE_BG
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_bg)

	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	var bar_fill := ColorRect.new()
	bar_fill.color = fill_color
	bar_fill.anchor_left = 0.0
	bar_fill.anchor_top = 0.0
	bar_fill.anchor_right = ratio
	bar_fill.anchor_bottom = 1.0
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_container.add_child(bar_fill)

	row.add_child(bar_container)

	var val_label := Label.new()
	val_label.text = "%d" % value
	val_label.custom_minimum_size = Vector2(36, 0)
	val_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_label.add_theme_font_size_override("font_size", 16)
	val_label.add_theme_color_override("font_color", fill_color)
	val_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_label)

	return row


func _update_company_gauges() -> void:
	if _gauges_container == null:
		return
	for child in _gauges_container.get_children():
		child.queue_free()

	_gauges_container.add_child(
		_create_company_gauge("⭐ 評判", GameState.reputation, 100, GAUGE_REPUTATION))
	_gauges_container.add_child(
		_create_company_gauge("🏷️ ブランド", GameState.brand_value, 100, GAUGE_BRAND))
	_gauges_container.add_child(
		_create_company_gauge("💪 士気", GameState.team_morale, 100, GAUGE_MORALE))


func _update_valuation() -> void:
	if _valuation_label == null:
		return
	_valuation_label.text = "📈 時価総額: %s万円" % _format_number(GameState.valuation)

	var comp_mgr = _get_competitor_manager()
	if comp_mgr:
		var share = comp_mgr.get_player_market_share(GameState)
		_market_share_label.text = "🏪 シェア: %.1f%%" % share
		_market_share_label.visible = true
	else:
		_market_share_label.text = ""
		_market_share_label.visible = false

	_equity_label.text = "💰 持株: %.1f%%" % GameState.equity_share


func _update_bottom_layout() -> void:
	# ボトムパネルの位置を画面下端に合わせる
	if _bottom_panel == null:
		return
	# サイズは子コンテンツに任せつつ最大高さを制限
	await get_tree().process_frame
	var content_h = _bottom_vbox.size.y + 20  # マージン分
	var clamped_h = minf(content_h, BOTTOM_MAX_H)
	_bottom_panel.position = Vector2(0, get_viewport().get_visible_rect().size.y - clamped_h)
	_bottom_panel.size = Vector2(SCREEN_W, clamped_h)


# ============================================================
# プロダクトカードスワイプ処理
# ============================================================

func _on_product_swipe_input(event: InputEvent) -> void:
	if _product_count <= 1:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_swiping = true
			_swipe_start_x = event.position.x
		else:
			if _is_swiping:
				_is_swiping = false
				var diff = event.position.x - _swipe_start_x
				var threshold := 60.0
				if diff < -threshold and _product_page < _product_count - 1:
					_product_page += 1
					product_card_swiped.emit(_product_page)
					_update_product_cards()
				elif diff > threshold and _product_page > 0:
					_product_page -= 1
					product_card_swiped.emit(_product_page)
					_update_product_cards()


# ============================================================
# ヘルパー関数
# ============================================================

func _get_office_name() -> String:
	var names := ["🏠 自宅ガレージ", "🏢 小さなオフィス", "🏢 コワーキングスペース",
		"🏢 自社オフィス", "🏙️ フロア貸しオフィス", "🏙️ 自社ビル"]
	var idx = _get_phase_index()
	return names[idx]


func _get_phase_index() -> int:
	var team = GameState.team_size
	if team <= 3:
		return 0
	elif team <= 6:
		return 1
	elif team <= 10:
		return 2
	elif team <= 15:
		return 3
	elif team <= 25:
		return 4
	else:
		return 5


func _calc_product_revenue(product: Dictionary) -> int:
	var p_users = product.get("users", 0)
	var margin_val = product.get("margin", 0)
	var ux = product.get("ux", 0)
	if p_users <= 0:
		return 0
	return p_users * (margin_val + ux) / 800


func _format_number(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 10000.0 / 10000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)


func _get_product_manager():
	return get_tree().root.get_node_or_null("Main/Game/ProductManager") if get_tree() else null


func _get_competitor_manager():
	return get_tree().root.get_node_or_null("Main/Game/CompetitorManager") if get_tree() else null
