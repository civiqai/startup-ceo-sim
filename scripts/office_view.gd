extends Control
## オフィスビジュアル: 会社の状態をグラフィカルに表示

# オフィスの段階
# 1人: ガレージ
# 2-4人: 小さなオフィス
# 5-9人: 中規模オフィス
# 10人+: 大きなオフィス

const DESK_EMOJI := "🖥️"
const PERSON_EMOJI := "👤"
const FLOOR_COLOR := Color(0.14, 0.16, 0.22, 1.0)
const WALL_COLOR := Color(0.20, 0.22, 0.30, 1.0)
const DESK_COLOR := Color(0.30, 0.25, 0.18, 1.0)
const CHAIR_COLOR := Color(0.22, 0.22, 0.28, 1.0)
const SCREEN_ON_COLOR := Color(0.30, 0.55, 0.85, 1.0)
const SCREEN_OFF_COLOR := Color(0.15, 0.15, 0.18, 1.0)
const GAUGE_BG := Color(0.15, 0.16, 0.20, 1.0)
const GAUGE_PRODUCT := Color(0.35, 0.60, 0.90, 1.0)
const GAUGE_REPUTATION := Color(0.90, 0.75, 0.30, 1.0)
const GAUGE_BRAND := Color(0.80, 0.45, 0.65, 1.0)
const GAUGE_MORALE := Color(0.50, 0.80, 0.50, 1.0)


func _draw() -> void:
	var rect = get_rect()
	var w = rect.size.x
	var h = rect.size.y

	# オフィスフロア
	_draw_office_floor(w, h)

	# デスク描画
	_draw_desks(w, h)

	# ゲージ描画（下部）
	var gauge_y = h * 0.58
	var gauge_w = w * 0.85
	var gauge_x = (w - gauge_w) / 2.0
	var gauge_h = 18.0
	var gauge_spacing = 38.0

	_draw_gauge(gauge_x, gauge_y, gauge_w, gauge_h,
		"⚡ プロダクト力", GameState.product_power, 100, GAUGE_PRODUCT)
	_draw_gauge(gauge_x, gauge_y + gauge_spacing, gauge_w, gauge_h,
		"⭐ 評判", GameState.reputation, 100, GAUGE_REPUTATION)
	_draw_gauge(gauge_x, gauge_y + gauge_spacing * 2, gauge_w, gauge_h,
		"🏷️ ブランド", GameState.brand_value, 100, GAUGE_BRAND)
	_draw_gauge(gauge_x, gauge_y + gauge_spacing * 3, gauge_w, gauge_h,
		"💪 士気", GameState.team_morale, 100, GAUGE_MORALE)

	# 数値情報（ゲージの下）
	var info_y = gauge_y + gauge_spacing * 4 + 8
	var font = ThemeDB.fallback_font
	var font_size = 20

	draw_string(font, Vector2(gauge_x, info_y),
		"📱 ユーザー: %s人" % _format_number(GameState.users),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.75, 0.60, 0.88))

	draw_string(font, Vector2(gauge_x, info_y + 28),
		"💹 売上: %s万円/月" % _format_number(GameState.revenue),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.55, 0.80, 0.55))

	draw_string(font, Vector2(gauge_x, info_y + 56),
		"📈 時価総額: %s万円" % _format_number(GameState.valuation),
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.50, 0.85, 0.80))


func _draw_office_floor(w: float, h: float) -> void:
	var office_h = h * 0.52
	# 壁
	draw_rect(Rect2(16, 8, w - 32, office_h), WALL_COLOR, true)
	# 床
	draw_rect(Rect2(20, 12, w - 40, office_h - 8), FLOOR_COLOR, true)
	# 窓
	var window_count = 3
	if GameState.team_size >= 5:
		window_count = 4
	if GameState.team_size >= 10:
		window_count = 5
	var win_w = (w - 80) / window_count - 10
	for i in window_count:
		var wx = 40 + i * (win_w + 10)
		draw_rect(Rect2(wx, 20, win_w, 30), Color(0.25, 0.35, 0.50, 0.6), true)
		draw_rect(Rect2(wx, 20, win_w, 30), Color(0.35, 0.45, 0.60, 0.4), false, 1.0)

	# オフィス名
	var font = ThemeDB.fallback_font
	var office_name = _get_office_name()
	draw_string(font, Vector2(w / 2.0 - 80, office_h + 20),
		office_name, HORIZONTAL_ALIGNMENT_CENTER, 200, 18, Color(0.50, 0.55, 0.65))


func _draw_desks(w: float, h: float) -> void:
	var team = GameState.team_size
	var max_cols = 5
	var cols = mini(team, max_cols)
	var rows = ceili(float(team) / max_cols)

	var desk_w = 56.0
	var desk_h = 40.0
	var spacing_x = 16.0
	var spacing_y = 20.0

	var total_w = cols * desk_w + (cols - 1) * spacing_x
	var start_x = (w - total_w) / 2.0
	var start_y = 65.0

	for i in team:
		var col = i % max_cols
		var row = i / max_cols
		var dx = start_x + col * (desk_w + spacing_x)
		var dy = start_y + row * (desk_h + spacing_y)
		_draw_single_desk(dx, dy, desk_w, desk_h, true)


func _draw_single_desk(x: float, y: float, w: float, h: float, active: bool) -> void:
	# デスク本体
	draw_rect(Rect2(x, y, w, h), DESK_COLOR, true)
	draw_rect(Rect2(x, y, w, h), DESK_COLOR.lightened(0.2), false, 1.0)

	# モニター
	var mon_w = w * 0.5
	var mon_h = h * 0.55
	var mon_x = x + (w - mon_w) / 2.0
	var mon_y = y + 4
	var screen_color = SCREEN_ON_COLOR if active else SCREEN_OFF_COLOR
	draw_rect(Rect2(mon_x, mon_y, mon_w, mon_h), screen_color, true)
	draw_rect(Rect2(mon_x, mon_y, mon_w, mon_h), screen_color.lightened(0.3), false, 1.0)

	# 椅子（デスクの下に小さな丸）
	var chair_x = x + w / 2.0
	var chair_y = y + h + 8
	draw_circle(Vector2(chair_x, chair_y), 8.0, CHAIR_COLOR)


func _draw_gauge(x: float, y: float, w: float, h: float,
		label_text: String, value: int, max_value: int, fill_color: Color) -> void:
	var font = ThemeDB.fallback_font
	var label_w = 160.0
	var bar_x = x + label_w
	var bar_w = w - label_w - 50

	# ラベル
	draw_string(font, Vector2(x, y + h - 2), label_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.65, 0.68, 0.75))

	# バー背景
	draw_rect(Rect2(bar_x, y, bar_w, h), GAUGE_BG, true)

	# バー塗り
	var ratio = clampf(float(value) / max_value, 0.0, 1.0)
	if ratio > 0:
		draw_rect(Rect2(bar_x, y, bar_w * ratio, h), fill_color, true)

	# 角丸風のボーダー
	draw_rect(Rect2(bar_x, y, bar_w, h), fill_color.darkened(0.3), false, 1.0)

	# 値テキスト
	draw_string(font, Vector2(bar_x + bar_w + 8, y + h - 2),
		"%d" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, fill_color)


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
	queue_redraw()
