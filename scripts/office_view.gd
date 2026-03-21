extends Control
## オフィスビジュアル: シンプルなメンバーグリッド + ステータス表示

signal member_tapped(member_index: int)

const SKILL_COLORS := {
	"engineer": Color(0.25, 0.50, 0.80),
	"designer": Color(0.75, 0.40, 0.60),
	"marketer": Color(0.80, 0.55, 0.20),
	"bizdev": Color(0.40, 0.65, 0.40),
	"pm": Color(0.55, 0.45, 0.75),
}

const GAUGE_BG := Color(0.15, 0.16, 0.20, 1.0)
const GAUGE_UX := Color(0.35, 0.60, 0.90)
const GAUGE_DESIGN := Color(0.85, 0.50, 0.70)
const GAUGE_MARGIN := Color(0.55, 0.85, 0.55)
const GAUGE_AWARENESS := Color(0.90, 0.75, 0.30)
const GAUGE_REPUTATION := Color(0.90, 0.70, 0.25)
const GAUGE_BRAND := Color(0.80, 0.45, 0.65)
const GAUGE_MORALE := Color(0.50, 0.80, 0.50)

# メンバーの矩形エリア（タップ検知用）
var _member_rects: Array[Rect2] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		for i in _member_rects.size():
			if _member_rects[i].has_point(pos):
				# 0 = 社長（タップ不可）、1以降 = TeamManagerメンバー
				if i > 0:
					member_tapped.emit(i - 1)
				break


func _draw() -> void:
	var rect: Rect2 = get_rect()
	var w: float = rect.size.x
	var h: float = rect.size.y
	var font: Font = ThemeDB.fallback_font
	_member_rects.clear()

	var y_cursor := 4.0

	# --- 会社情報ヘッダー ---
	var office_name = _get_office_name()
	draw_string(font, Vector2(w / 2.0 - 80, y_cursor + 16),
		office_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 16, Color(0.55, 0.60, 0.70))
	y_cursor += 24

	# --- バーンレート ---
	y_cursor = _draw_burn_rate(w, y_cursor, font)

	# --- メンバーグリッド ---
	y_cursor = _draw_member_grid(w, y_cursor, font)

	# --- プロダクト一覧 ---
	y_cursor += 4
	var pm = get_node_or_null("/root/Main/Game/ProductManager")
	if pm:
		y_cursor = _draw_products_section(w, y_cursor, font, pm)
	y_cursor += 4

	# --- 会社全体 ---
	y_cursor = _draw_company_section(w, y_cursor, font)


func _draw_products_section(w: float, y: float, font: Font, pm) -> float:
	var active = pm.get_active_products()
	if active.is_empty():
		draw_string(font, Vector2(w * 0.05, y + 14),
			"📦 プロダクトなし（PMを採用して立ち上げましょう）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.50, 0.55, 0.65))
		return y + 24

	for p in active:
		y = _draw_product_card(w, y, font, p, pm)
	return y


func _draw_product_card(w: float, y: float, font: Font, product: Dictionary, pm) -> float:
	var type_data = pm.PRODUCT_TYPES.get(product["type"], {})
	var card_x := w * 0.03
	var card_w := w * 0.94
	var card_h := 90.0

	# カード背景
	draw_rect(Rect2(card_x, y, card_w, card_h), Color(0.10, 0.12, 0.18, 0.9), true)
	draw_rect(Rect2(card_x, y, card_w, card_h), Color(0.25, 0.35, 0.50, 0.6), false, 1.0)

	# タイトル行
	var icon = type_data.get("icon", "📦")
	var pname = product.get("name", "プロダクト")
	draw_string(font, Vector2(card_x + 8, y + 14),
		"%s %s" % [icon, pname],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.95, 0.85, 0.40))

	# 4ゲージ（ミニ）
	var gauge_y := y + 22
	var gauge_h := 8.0
	var gauge_spacing := 16.0
	var gauge_x := card_x + 8
	var gauge_w := card_w * 0.55

	_draw_mini_gauge(gauge_x, gauge_y, gauge_w, gauge_h, "UX", product.get("ux", 0), 100, GAUGE_UX, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing, gauge_w, gauge_h, "デザイン", product.get("design", 0), 100, GAUGE_DESIGN, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing * 2, gauge_w, gauge_h, "利益率", product.get("margin", 0), 100, GAUGE_MARGIN, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing * 3, gauge_w, gauge_h, "知名度", product.get("awareness", 0), 100, GAUGE_AWARENESS, font)

	# 右側に数値情報
	var info_x := card_x + card_w * 0.62
	draw_string(font, Vector2(info_x, gauge_y + 8),
		"📱 %s人" % _format_number(product.get("users", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.60, 0.88))
	draw_string(font, Vector2(info_x, gauge_y + 24),
		"💹 %s万/月" % _format_number(_calc_product_revenue(product)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.55, 0.80, 0.55))
	draw_string(font, Vector2(info_x, gauge_y + 40),
		"🔧 負債: %d" % product.get("tech_debt", 0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.80, 0.50, 0.40))

	return y + card_h + 4


func _calc_product_revenue(product: Dictionary) -> int:
	var p_users = product.get("users", 0)
	var margin = product.get("margin", 0)
	var ux = product.get("ux", 0)
	if p_users <= 0:
		return 0
	return p_users * (margin + ux) / 800


func _draw_mini_gauge(x: float, y: float, w: float, h: float,
		label_text: String, value: int, max_value: int, fill_color: Color, font: Font) -> void:
	var label_w: float = 60.0
	var bar_x: float = x + label_w
	var bar_w: float = w - label_w - 30

	# ラベル
	draw_string(font, Vector2(x, y + h - 1), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.68, 0.75))

	# バー背景
	draw_rect(Rect2(bar_x, y, bar_w, h), GAUGE_BG, true)

	# バー塗り
	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	if ratio > 0:
		draw_rect(Rect2(bar_x, y, bar_w * ratio, h), fill_color, true)

	# ボーダー
	draw_rect(Rect2(bar_x, y, bar_w, h), fill_color.darkened(0.3), false, 1.0)

	# 値テキスト
	draw_string(font, Vector2(bar_x + bar_w + 4, y + h - 1),
		"%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill_color)


func _draw_company_section(w: float, y: float, font: Font) -> float:
	var gauge_x = w * 0.05
	var gauge_w = w * 0.90
	var gauge_h = 12.0
	var gauge_spacing = 20.0

	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "⭐ 評判", GameState.reputation, 100, GAUGE_REPUTATION)
	y += gauge_spacing
	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "🏷️ ブランド", GameState.brand_value, 100, GAUGE_BRAND)
	y += gauge_spacing
	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "💪 士気", GameState.team_morale, 100, GAUGE_MORALE)
	y += gauge_spacing + 8

	# 数値情報
	draw_string(font, Vector2(gauge_x, y),
		"📈 時価総額: %s万円" % _format_number(GameState.valuation),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.50, 0.85, 0.80))
	var comp_mgr = get_node_or_null("/root/Main/Game/CompetitorManager")
	if comp_mgr:
		var share = comp_mgr.get_player_market_share(GameState)
		draw_string(font, Vector2(w * 0.5, y),
			"🏪 シェア: %.1f%%" % share,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.70, 0.50))
	y += 24
	draw_string(font, Vector2(gauge_x, y),
		"💰 持株: %.1f%%" % GameState.equity_share,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.80, 0.75, 0.40))

	return y + 24


func _draw_burn_rate(w: float, y: float, font: Font) -> float:
	var monthly = GameState.monthly_cost
	if monthly <= 0:
		return y
	var months_left = GameState.cash / monthly
	var color: Color
	var text: String
	if months_left <= 3:
		color = Color(0.90, 0.35, 0.30)
		text = "⚠️ 残り%dヶ月で資金枯渇" % months_left
	elif months_left <= 6:
		color = Color(0.90, 0.75, 0.30)
		text = "💰 ランウェイ: %dヶ月" % months_left
	else:
		color = Color(0.50, 0.75, 0.50)
		text = "💰 ランウェイ: %dヶ月" % months_left

	draw_string(font, Vector2(w / 2.0 - 100, y + 14), text,
		HORIZONTAL_ALIGNMENT_CENTER, 250, 16, color)
	return y + 22


func _draw_member_grid(w: float, y: float, font: Font) -> float:
	var cols := 4
	var cell_w := (w - 20) / cols
	var cell_h := 60.0
	var start_x := 10.0

	# 社長 + メンバー
	var total = 1 + TeamManager.members.size()
	var rows = ceili(float(total) / cols)

	# 背景
	var grid_h = rows * cell_h + 4
	draw_rect(Rect2(4, y, w - 8, grid_h), Color(0.08, 0.09, 0.13, 0.8), true)
	draw_rect(Rect2(4, y, w - 8, grid_h), Color(0.20, 0.25, 0.35, 0.5), false, 1.0)

	# 社長セル
	var boss_rect := Rect2(start_x, y + 2, cell_w - 4, cell_h - 4)
	_member_rects.append(boss_rect)
	_draw_member_cell(boss_rect, "社長", "", 0, true, font, 0)

	# メンバー
	for i in TeamManager.members.size():
		var col = (i + 1) % cols
		var row = (i + 1) / cols
		var cell_rect := Rect2(start_x + col * cell_w, y + 2 + row * cell_h, cell_w - 4, cell_h - 4)
		_member_rects.append(cell_rect)
		var m = TeamManager.members[i]
		_draw_member_cell(cell_rect, m.member_name, m.skill_type, m.skill_level, false, font, m.avatar_id)

	return y + grid_h + 4


func _draw_member_cell(rect: Rect2, name_str: String, skill_type: String, level: int, is_boss: bool, font: Font, avatar_id: int = 0) -> void:
	var cx: float = rect.position.x + rect.size.x / 2.0
	var cy: float = rect.position.y

	# アバター（丸い背景 + イニシャル or 画像）
	var avatar_r: float = 16.0
	var avatar_cx: float = cx
	var avatar_cy: float = cy + avatar_r + 4.0

	var bg_color: Color
	if is_boss:
		bg_color = Color(0.80, 0.70, 0.25)
	else:
		bg_color = SKILL_COLORS.get(skill_type, Color(0.4, 0.4, 0.4))

	# 丸を描画（多角形で近似）— 背景として常に表示
	var points := PackedVector2Array()
	for j in 16:
		var angle = j * TAU / 16
		points.append(Vector2(avatar_cx + cos(angle) * avatar_r, avatar_cy + sin(angle) * avatar_r))
	draw_colored_polygon(points, bg_color)

	# アバター画像をキャッシュから取得して描画
	var avatar_drawn := false
	if avatar_id > 0 and AvatarLoader != null:
		var tex: ImageTexture = AvatarLoader.get_cached(avatar_id)
		if tex != null:
			# 丸い領域に合わせて画像を描画
			var img_rect := Rect2(avatar_cx - avatar_r, avatar_cy - avatar_r, avatar_r * 2, avatar_r * 2)
			draw_texture_rect(tex, img_rect, false)
			avatar_drawn = true

	# ボス枠
	if is_boss:
		var border_points := PackedVector2Array()
		for j in 17:
			var angle = j * TAU / 16
			border_points.append(Vector2(avatar_cx + cos(angle) * (avatar_r + 2), avatar_cy + sin(angle) * (avatar_r + 2)))
		draw_polyline(border_points, Color(0.95, 0.85, 0.30), 2.0)

	# イニシャル（画像が無い場合のフォールバック）
	if not avatar_drawn:
		var initial = name_str.left(1) if name_str.length() > 0 else "?"
		draw_string(font, Vector2(avatar_cx - 6, avatar_cy + 6), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))

	# 名前（短縮）
	var display_name = name_str.left(4) if name_str.length() > 4 else name_str
	draw_string(font, Vector2(cx - 20, avatar_cy + avatar_r + 14), display_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.80, 0.82, 0.88))

	# レベル（★）
	if level > 0:
		var stars = "★".repeat(level)
		draw_string(font, Vector2(cx - 16, avatar_cy + avatar_r + 26), stars,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.90, 0.80, 0.30))


func _draw_gauge(x: float, y: float, w: float, h: float,
		label_text: String, value: int, max_value: int, fill_color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var label_w: float = 120.0
	var bar_x: float = x + label_w
	var bar_w: float = w - label_w - 40

	# ラベル
	draw_string(font, Vector2(x, y + h - 2), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.65, 0.68, 0.75))

	# バー背景
	draw_rect(Rect2(bar_x, y, bar_w, h), GAUGE_BG, true)

	# バー塗り
	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	if ratio > 0:
		draw_rect(Rect2(bar_x, y, bar_w * ratio, h), fill_color, true)

	# 角丸風のボーダー
	draw_rect(Rect2(bar_x, y, bar_w, h), fill_color.darkened(0.3), false, 1.0)

	# 値テキスト
	draw_string(font, Vector2(bar_x + bar_w + 6, y + h - 2),
		"%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, fill_color)


func _get_office_name() -> String:
	var team = GameState.team_size
	if team <= 1:
		return "🏠 自宅ガレージ"
	elif team <= 3:
		return "🏢 小さなオフィス"
	elif team <= 6:
		return "🏢 コワーキングスペース"
	elif team <= 10:
		return "🏢 自社オフィス"
	elif team <= 20:
		return "🏙️ フロア貸しオフィス"
	else:
		return "🏙️ 自社ビル"


func _format_number(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 10000.0 / 10000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)


func refresh() -> void:
	# メンバーのアバター画像をプリロード（キャッシュになければダウンロード開始）
	if AvatarLoader != null:
		for m in TeamManager.members:
			if m.avatar_id > 0 and AvatarLoader.get_cached(m.avatar_id) == null:
				AvatarLoader.get_avatar(m.avatar_id, func(_tex: Variant) -> void:
					queue_redraw()  # 画像取得後に再描画
				)
	queue_redraw()
