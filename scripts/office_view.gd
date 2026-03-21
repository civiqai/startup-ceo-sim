extends Control
## オフィスビジュアル: ピクセルアートの部屋背景 + アバター付きメンバー表示

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

const ROOM_HEIGHT := 260  # 部屋背景の表示高さ

const ROOM_TEXTURES := [
	"res://assets/images/rooms/office_phase1_garage.png",
	"res://assets/images/rooms/office_phase2_small.png",
	"res://assets/images/rooms/office_phase3_coworking.png",
	"res://assets/images/rooms/office_phase4_own.png",
	"res://assets/images/rooms/office_phase5_floor.png",
	"res://assets/images/rooms/office_phase6_building.png",
]

# メンバーの矩形エリア（タップ検知用）
var _member_rects: Array[Rect2] = []
var _current_phase: int = -1
var _room_texture_cache: Dictionary = {}
var _room_tex: Texture2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	call_deferred("refresh")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos = event.position
		for i in _member_rects.size():
			if _member_rects[i].has_point(pos):
				if i > 0:
					member_tapped.emit(i - 1)
				break


func _draw() -> void:
	var rect := get_rect()
	var w: float = rect.size.x
	var font: Font = ThemeDB.fallback_font
	_member_rects.clear()

	# --- 部屋背景を描画 ---
	if _room_tex:
		draw_texture_rect(_room_tex, Rect2(0, 0, w, ROOM_HEIGHT), false)
	else:
		draw_rect(Rect2(0, 0, w, ROOM_HEIGHT), Color(0.08, 0.09, 0.12, 1.0), true)

	var y_cursor := 4.0

	# --- オフィス名（部屋上に重ねて表示） ---
	var office_name = _get_office_name()
	draw_rect(Rect2(0, 0, w, 24), Color(0.0, 0.0, 0.0, 0.45), true)
	draw_string(font, Vector2(8, 18), office_name,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.92, 0.94, 0.97))

	# バーンレート
	var monthly = GameState.monthly_cost
	if monthly > 0:
		var months_left = GameState.cash / monthly
		var burn_color: Color
		var burn_text: String
		if months_left <= 3:
			burn_color = Color(0.90, 0.35, 0.30)
			burn_text = "⚠️ 残り%dヶ月" % months_left
		elif months_left <= 6:
			burn_color = Color(0.90, 0.75, 0.30)
			burn_text = "ランウェイ %dヶ月" % months_left
		else:
			burn_color = Color(0.50, 0.75, 0.50)
			burn_text = "ランウェイ %dヶ月" % months_left
		draw_string(font, Vector2(w - 180, 18), burn_text,
			HORIZONTAL_ALIGNMENT_RIGHT, 170, 14, burn_color)

	# --- メンバーグリッド（部屋の上に重ねて表示） ---
	y_cursor = _draw_member_grid(w, 28, font)

	# --- ゲージ等は部屋の下 ---
	y_cursor = ROOM_HEIGHT + 4.0

	var pm = get_node_or_null("/root/Main/Game/ProductManager")
	if pm:
		y_cursor = _draw_products_section(w, y_cursor, font, pm)
	y_cursor += 4

	y_cursor = _draw_company_section(w, y_cursor, font)


## メンバーグリッド: 大きな丸アバター + 名前 + 職種を部屋の上に表示
func _draw_member_grid(w: float, y: float, font: Font) -> float:
	var cols := 4
	var cell_w := (w - 16) / cols
	var cell_h := 100.0
	var start_x := 8.0

	var total = 1 + TeamManager.members.size()
	var rows = ceili(float(total) / cols)
	var grid_h = rows * cell_h + 6

	# 半透明背景
	draw_rect(Rect2(4, y, w - 8, grid_h), Color(0.0, 0.0, 0.0, 0.40), true)

	# 社長
	var boss_rect := Rect2(start_x, y + 4, cell_w - 4, cell_h - 4)
	_member_rects.append(boss_rect)
	_draw_member_cell(boss_rect, "社長", "CEO", 0, true, font, 0)

	# メンバー
	for i in TeamManager.members.size():
		var col = (i + 1) % cols
		var row = (i + 1) / cols
		var cell_rect := Rect2(start_x + col * cell_w, y + 4 + row * cell_h, cell_w - 4, cell_h - 4)
		_member_rects.append(cell_rect)
		var m = TeamManager.members[i]
		var skill_label = TeamMember.get_skill_label(m.skill_type) if m.skill_type else ""
		_draw_member_cell(cell_rect, m.member_name, skill_label, m.skill_level, false, font, m.avatar_id)

	return y + grid_h + 4


func _draw_member_cell(rect: Rect2, name_str: String, role_str: String, level: int, is_boss: bool, font: Font, avatar_id: int = 0) -> void:
	var cx: float = rect.position.x + rect.size.x / 2.0
	var cy: float = rect.position.y
	var avatar_r: float = 28.0
	var avatar_cx: float = cx
	var avatar_cy: float = cy + avatar_r + 4.0
	var circle_segs := 24

	# スキルカラー取得
	var bg_color: Color
	if is_boss:
		bg_color = Color(0.80, 0.70, 0.25)
	else:
		bg_color = Color(0.4, 0.4, 0.4)
		for key in SKILL_COLORS:
			if TeamMember.get_skill_label(key) == role_str:
				bg_color = SKILL_COLORS[key]
				break

	# 丸い背景（アバターの下地）
	var bg_points := PackedVector2Array()
	for j in circle_segs:
		var angle = j * TAU / circle_segs
		bg_points.append(Vector2(avatar_cx + cos(angle) * avatar_r, avatar_cy + sin(angle) * avatar_r))
	draw_colored_polygon(bg_points, bg_color)

	# アバター画像（丸くクリップして描画）
	var avatar_drawn := false
	if avatar_id > 0 and AvatarLoader != null:
		var tex: Texture2D = AvatarLoader.get_cached(avatar_id)
		if tex != null:
			# 丸い領域にアバター画像を描画
			var img_rect := Rect2(avatar_cx - avatar_r, avatar_cy - avatar_r, avatar_r * 2, avatar_r * 2)
			draw_texture_rect(tex, img_rect, false)
			# 丸枠で囲んで丸く見せる（外側をスキルカラーの枠で覆う）
			var ring_points := PackedVector2Array()
			for j in circle_segs + 1:
				var angle = j * TAU / circle_segs
				ring_points.append(Vector2(avatar_cx + cos(angle) * avatar_r, avatar_cy + sin(angle) * avatar_r))
			draw_polyline(ring_points, bg_color.darkened(0.2), 3.0)
			avatar_drawn = true

	# ボス枠（金色）
	if is_boss:
		var border_points := PackedVector2Array()
		for j in circle_segs + 1:
			var angle = j * TAU / circle_segs
			border_points.append(Vector2(avatar_cx + cos(angle) * (avatar_r + 2), avatar_cy + sin(angle) * (avatar_r + 2)))
		draw_polyline(border_points, Color(0.95, 0.85, 0.30), 3.0)

	# イニシャル（画像なしフォールバック）
	if not avatar_drawn:
		var initial = name_str.left(1) if name_str.length() > 0 else "?"
		draw_string(font, Vector2(avatar_cx - 8, avatar_cy + 8), initial,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))

	# 名前（大きめ）
	var display_name = name_str.left(4) if name_str.length() > 4 else name_str
	draw_string(font, Vector2(cx - 28, avatar_cy + avatar_r + 16), display_name,
		HORIZONTAL_ALIGNMENT_LEFT, 60, 14, Color(0.95, 0.95, 1.0))

	# 職種
	if role_str != "":
		draw_string(font, Vector2(cx - 28, avatar_cy + avatar_r + 30), role_str,
			HORIZONTAL_ALIGNMENT_LEFT, 60, 11, bg_color.lightened(0.4))


# ============================================================
# 以下、プロダクト / 会社ステータス / ゲージ描画
# ============================================================

func _draw_products_section(w: float, y: float, font: Font, pm) -> float:
	var active = pm.get_active_products()
	if active.is_empty():
		draw_string(font, Vector2(w * 0.05, y + 20),
			"📦 プロダクトなし（PMを採用して立ち上げましょう）",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.50, 0.55, 0.65))
		return y + 32
	for p in active:
		y = _draw_product_card(w, y, font, p, pm)
	return y


func _draw_product_card(w: float, y: float, font: Font, product: Dictionary, pm) -> float:
	var type_data = pm.PRODUCT_TYPES.get(product["type"], {})
	var card_x := w * 0.02
	var card_w := w * 0.96
	var card_h := 140.0

	draw_rect(Rect2(card_x, y, card_w, card_h), Color(0.10, 0.12, 0.18, 0.9), true)
	draw_rect(Rect2(card_x, y, card_w, card_h), Color(0.25, 0.35, 0.50, 0.6), false, 1.0)

	var icon = type_data.get("icon", "📦")
	var pname = product.get("name", "プロダクト")
	draw_string(font, Vector2(card_x + 12, y + 22),
		"%s %s" % [icon, pname],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.85, 0.40))

	var gauge_y := y + 34
	var gauge_h := 12.0
	var gauge_spacing := 22.0
	var gauge_x := card_x + 12
	var gauge_w := card_w * 0.54

	_draw_mini_gauge(gauge_x, gauge_y, gauge_w, gauge_h, "UX", product.get("ux", 0), 100, GAUGE_UX, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing, gauge_w, gauge_h, "デザイン", product.get("design", 0), 100, GAUGE_DESIGN, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing * 2, gauge_w, gauge_h, "利益率", product.get("margin", 0), 100, GAUGE_MARGIN, font)
	_draw_mini_gauge(gauge_x, gauge_y + gauge_spacing * 3, gauge_w, gauge_h, "知名度", product.get("awareness", 0), 100, GAUGE_AWARENESS, font)

	var info_x := card_x + card_w * 0.60
	var info_spacing := 24.0
	draw_string(font, Vector2(info_x, gauge_y + 12),
		"📱 %s人" % _format_number(product.get("users", 0)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.75, 0.60, 0.88))
	draw_string(font, Vector2(info_x, gauge_y + 12 + info_spacing),
		"💹 %s万/月" % _format_number(_calc_product_revenue(product)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.55, 0.80, 0.55))
	draw_string(font, Vector2(info_x, gauge_y + 12 + info_spacing * 2),
		"🔧 負債: %d" % product.get("tech_debt", 0),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.80, 0.50, 0.40))

	return y + card_h + 8


func _calc_product_revenue(product: Dictionary) -> int:
	var p_users = product.get("users", 0)
	var margin_val = product.get("margin", 0)
	var ux = product.get("ux", 0)
	if p_users <= 0:
		return 0
	return p_users * (margin_val + ux) / 800


func _draw_mini_gauge(x: float, y: float, w: float, h: float,
		label_text: String, value: int, max_value: int, fill_color: Color, font: Font) -> void:
	var label_w: float = 80.0
	var bar_x: float = x + label_w
	var bar_w: float = w - label_w - 36
	draw_string(font, Vector2(x, y + h), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.70, 0.72, 0.78))
	draw_rect(Rect2(bar_x, y + 1, bar_w, h - 2), GAUGE_BG, true)
	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	if ratio > 0:
		draw_rect(Rect2(bar_x, y + 1, bar_w * ratio, h - 2), fill_color, true)
	draw_rect(Rect2(bar_x, y + 1, bar_w, h - 2), fill_color.darkened(0.3), false, 1.0)
	draw_string(font, Vector2(bar_x + bar_w + 6, y + h),
		"%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, fill_color)


func _draw_company_section(w: float, y: float, font: Font) -> float:
	var gauge_x = w * 0.04
	var gauge_w = w * 0.92
	var gauge_h = 16.0
	var gauge_spacing = 28.0

	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "⭐ 評判", GameState.reputation, 100, GAUGE_REPUTATION)
	y += gauge_spacing
	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "🏷️ ブランド", GameState.brand_value, 100, GAUGE_BRAND)
	y += gauge_spacing
	_draw_gauge(gauge_x, y, gauge_w, gauge_h, "💪 士気", GameState.team_morale, 100, GAUGE_MORALE)
	y += gauge_spacing + 12

	draw_string(font, Vector2(gauge_x, y),
		"📈 時価総額: %s万円" % _format_number(GameState.valuation),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.50, 0.85, 0.80))
	var comp_mgr = get_node_or_null("/root/Main/Game/CompetitorManager")
	if comp_mgr:
		var share = comp_mgr.get_player_market_share(GameState)
		draw_string(font, Vector2(w * 0.52, y),
			"🏪 シェア: %.1f%%" % share,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.75, 0.70, 0.50))
	y += 28
	draw_string(font, Vector2(gauge_x, y),
		"💰 持株: %.1f%%" % GameState.equity_share,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.80, 0.75, 0.40))

	return y + 28


func _draw_gauge(x: float, y: float, w: float, h: float,
		label_text: String, value: int, max_value: int, fill_color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var label_w: float = 130.0
	var bar_x: float = x + label_w
	var bar_w: float = w - label_w - 44
	draw_string(font, Vector2(x, y + h), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.70, 0.72, 0.78))
	draw_rect(Rect2(bar_x, y + 1, bar_w, h - 2), GAUGE_BG, true)
	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	if ratio > 0:
		draw_rect(Rect2(bar_x, y + 1, bar_w * ratio, h - 2), fill_color, true)
	draw_rect(Rect2(bar_x, y + 1, bar_w, h - 2), fill_color.darkened(0.3), false, 1.0)
	draw_string(font, Vector2(bar_x + bar_w + 8, y + h),
		"%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, fill_color)


## 部屋フェーズ判定
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


func _get_office_name() -> String:
	var names := ["🏠 自宅ガレージ", "🏢 小さなオフィス", "🏢 コワーキングスペース",
		"🏢 自社オフィス", "🏙️ フロア貸しオフィス", "🏙️ 自社ビル"]
	return names[_get_phase_index()]


## 部屋背景を更新
func _update_room_bg(phase: int) -> void:
	if phase == _current_phase and _room_tex != null:
		return
	_current_phase = phase

	if phase in _room_texture_cache:
		_room_tex = _room_texture_cache[phase]
		return

	var tex_path = ROOM_TEXTURES[phase]
	var tex = load(tex_path)
	if tex == null:
		push_warning("Room image load failed: %s" % tex_path)
		return

	_room_texture_cache[phase] = tex
	_room_tex = tex


func _format_number(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 10000.0 / 10000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)


func refresh() -> void:
	if AvatarLoader != null:
		for m in TeamManager.members:
			if m.avatar_id > 0 and AvatarLoader.get_cached(m.avatar_id) == null:
				AvatarLoader.get_avatar(m.avatar_id, func(_tex: Variant) -> void:
					queue_redraw()
				)

	var phase = _get_phase_index()
	_update_room_bg(phase)
	queue_redraw()
