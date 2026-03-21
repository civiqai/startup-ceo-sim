extends RefCounted
## 資金調達タイプ定義（4タイプ × 8マス）

const TYPES := [
	{
		"id": "angel",
		"name": "エンジェル投資",
		"icon": "👼",
		"description": "個人投資家からの出資。大当たりも大外れもある。",
		"color": Color(0.85, 0.55, 0.20),
		"cooldown": 2,
		"variance": "high",
	},
	{
		"id": "vc",
		"name": "VC調達",
		"icon": "🏦",
		"description": "VCからの本格出資。評判が重要。",
		"color": Color(0.25, 0.45, 0.75),
		"cooldown": 3,
		"variance": "medium",
	},
	{
		"id": "bank",
		"name": "銀行融資",
		"icon": "🏛️",
		"description": "銀行からの融資。安定的だが額は控えめ。",
		"color": Color(0.45, 0.55, 0.40),
		"cooldown": 4,
		"variance": "low",
	},
	{
		"id": "crowdfund",
		"name": "クラウドファンディング",
		"icon": "👥",
		"description": "ユーザーからの直接支援。ブランド力が鍵。",
		"color": Color(0.60, 0.40, 0.70),
		"cooldown": 3,
		"variance": "medium",
	},
]

# --- Board squares per type (8 each) ---

const ANGEL_SQUARES := [
	{"name": "大口エンジェル", "icon": "💎", "color": Color(0.95, 0.75, 0.15)},
	{"name": "少額エンジェル", "icon": "👼", "color": Color(0.40, 0.70, 0.40)},
	{"name": "条件付き出資", "icon": "📝", "color": Color(0.70, 0.55, 0.30)},
	{"name": "起業家の紹介", "icon": "🤝", "color": Color(0.35, 0.55, 0.80)},
	{"name": "門前払い", "icon": "🚪", "color": Color(0.45, 0.45, 0.45)},
	{"name": "先越された", "icon": "😰", "color": Color(0.75, 0.30, 0.30)},
	{"name": "メディア露出", "icon": "📺", "color": Color(0.60, 0.45, 0.80)},
	{"name": "アクセラレーター", "icon": "🚀", "color": Color(0.25, 0.65, 0.60)},
]

const VC_SQUARES := [
	{"name": "メガラウンド", "icon": "💰", "color": Color(0.95, 0.75, 0.15)},
	{"name": "標準出資", "icon": "🏦", "color": Color(0.35, 0.55, 0.80)},
	{"name": "小規模出資", "icon": "📊", "color": Color(0.40, 0.60, 0.50)},
	{"name": "好条件出資", "icon": "⭐", "color": Color(0.50, 0.75, 0.35)},
	{"name": "却下", "icon": "❌", "color": Color(0.75, 0.30, 0.30)},
	{"name": "厳しい条件", "icon": "⚖️", "color": Color(0.70, 0.55, 0.30)},
	{"name": "大型ラウンド", "icon": "🎯", "color": Color(0.25, 0.60, 0.80)},
	{"name": "リードインベスター", "icon": "👑", "color": Color(0.80, 0.60, 0.90)},
]

const BANK_SQUARES := [
	{"name": "特別融資枠", "icon": "🏛️", "color": Color(0.95, 0.75, 0.15)},
	{"name": "標準融資", "icon": "📋", "color": Color(0.45, 0.65, 0.45)},
	{"name": "少額融資", "icon": "💴", "color": Color(0.50, 0.55, 0.40)},
	{"name": "好条件融資", "icon": "✅", "color": Color(0.40, 0.70, 0.50)},
	{"name": "審査落ち", "icon": "📝", "color": Color(0.55, 0.45, 0.40)},
	{"name": "担保要求", "icon": "🔒", "color": Color(0.70, 0.55, 0.30)},
	{"name": "大口融資", "icon": "💎", "color": Color(0.35, 0.60, 0.75)},
	{"name": "信用枠拡大", "icon": "📈", "color": Color(0.50, 0.70, 0.60)},
]

const CROWDFUND_SQUARES := [
	{"name": "社会現象", "icon": "🌟", "color": Color(0.95, 0.75, 0.15)},
	{"name": "目標達成", "icon": "🎉", "color": Color(0.40, 0.70, 0.40)},
	{"name": "そこそこ達成", "icon": "👍", "color": Color(0.50, 0.60, 0.50)},
	{"name": "ストレッチゴール", "icon": "🏆", "color": Color(0.50, 0.75, 0.35)},
	{"name": "目標未達", "icon": "😥", "color": Color(0.55, 0.45, 0.40)},
	{"name": "炎上", "icon": "🔥", "color": Color(0.80, 0.25, 0.25)},
	{"name": "バズって大成功", "icon": "📱", "color": Color(0.60, 0.45, 0.80)},
	{"name": "コミュニティ形成", "icon": "🤝", "color": Color(0.45, 0.65, 0.70)},
]

const _SQUARES_MAP := {
	"angel": ANGEL_SQUARES,
	"vc": VC_SQUARES,
	"bank": BANK_SQUARES,
	"crowdfund": CROWDFUND_SQUARES,
}

# Dice-sum-to-position mapping tables per type
# Each maps modified dice sum ranges to board square indices
const _DICE_MAP := {
	"angel": {3: 5, 4: 5, 5: 4, 6: 4, 7: 2, 8: 2, 9: 1, 10: 1, 11: 3, 12: 3, 13: 6, 14: 6, 15: 7, 16: 7, 17: 0, 18: 0},
	"vc": {3: 4, 4: 4, 5: 4, 6: 5, 7: 5, 8: 2, 9: 2, 10: 1, 11: 1, 12: 1, 13: 3, 14: 3, 15: 6, 16: 6, 17: 7, 18: 7, 19: 0, 20: 0, 21: 0, 22: 0},
	"bank": {3: 4, 4: 4, 5: 4, 6: 2, 7: 2, 8: 2, 9: 1, 10: 1, 11: 1, 12: 3, 13: 3, 14: 3, 15: 6, 16: 6, 17: 6, 18: 0},
	"crowdfund": {3: 5, 4: 5, 5: 5, 6: 4, 7: 4, 8: 2, 9: 2, 10: 2, 11: 1, 12: 1, 13: 1, 14: 3, 15: 3, 16: 6, 17: 6, 18: 0, 19: 0, 20: 0},
}


static func get_type_count() -> int:
	return TYPES.size()


static func get_type(type_id: String) -> Dictionary:
	for t in TYPES:
		if t["id"] == type_id:
			return t
	return {}


static func get_all_types() -> Array:
	return TYPES


static func get_squares(type_id: String) -> Array:
	return _SQUARES_MAP.get(type_id, [])


static func get_square(type_id: String, index: int) -> Dictionary:
	var squares = get_squares(type_id)
	if squares.is_empty():
		return {}
	return squares[index % squares.size()]


static func get_square_count() -> int:
	return 8


static func is_available(type_id: String, gs) -> bool:
	if gs.fundraise_cooldown > 0:
		return false
	match type_id:
		"angel":
			return gs.max_fundraise_amount >= 300
		"vc":
			return gs.reputation >= 30 and gs.product_power >= 20 and gs.max_fundraise_amount >= 500
		"bank":
			return gs.month >= 6 and gs.revenue > 0
		"crowdfund":
			return gs.users >= 100 and gs.brand_value >= 10
	return false


static func get_unlock_text(type_id: String) -> String:
	match type_id:
		"angel":
			return "調達可能額300万以上"
		"vc":
			return "評判30以上 & プロダクト力20以上"
		"bank":
			return "6ヶ月目以降 & 売上あり"
		"crowdfund":
			return "ユーザー100人以上 & ブランド10以上"
	return ""


static func dice_sum_to_position(type_id: String, dice_sum: int, gs) -> int:
	var modified = dice_sum

	# Type-specific stat bonuses
	match type_id:
		"vc":
			if gs.reputation >= 80:
				modified += 4
			elif gs.reputation >= 60:
				modified += 2
		"crowdfund":
			if gs.users >= 5000:
				modified += 2
			elif gs.users >= 1000:
				modified += 1
			if gs.brand_value >= 40:
				modified += 1
		"bank":
			if gs.revenue >= 100:
				modified += 1

	var map: Dictionary = _DICE_MAP.get(type_id, {})
	# Clamp to map range
	var max_key = 18
	for k in map:
		if k > max_key:
			max_key = k
	modified = clampi(modified, 3, max_key)

	if map.has(modified):
		return map[modified]
	# Fallback: find nearest key
	var best_key = 3
	for k in map:
		if k <= modified and k > best_key:
			best_key = k
	return map.get(best_key, 0)


static func apply_effect(type_id: String, square_index: int, gs) -> String:
	var cap = gs.max_fundraise_amount
	var idx = square_index % 8

	match type_id:
		"angel":
			match idx:
				0: # 大口エンジェル
					var amount = mini(3000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 10, 100)
					return "資金 +%d万円、評判 +10" % amount
				1: # 少額エンジェル
					var amount = mini(500, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 5, 100)
					return "資金 +%d万円、評判 +5" % amount
				2: # 条件付き出資
					var amount = mini(1200, cap)
					gs.cash += amount
					gs.reputation = maxi(gs.reputation - 10, 0)
					return "資金 +%d万円、評判 -10" % amount
				3: # 起業家の紹介
					var amount = mini(800, cap)
					gs.cash += amount
					gs.product_power = mini(gs.product_power + 5, 100)
					gs.reputation = mini(gs.reputation + 5, 100)
					return "資金 +%d万円、プロダクト力 +5、評判 +5" % amount
				4: # 門前払い
					gs.team_morale = maxi(gs.team_morale - 5, 0)
					return "何も得られなかった… 士気 -5"
				5: # 先越された
					gs.reputation = maxi(gs.reputation - 15, 0)
					gs.team_morale = maxi(gs.team_morale - 10, 0)
					return "評判 -15、士気 -10"
				6: # メディア露出
					gs.users += 300
					gs.brand_value = mini(gs.brand_value + 10, 100)
					gs.reputation = mini(gs.reputation + 5, 100)
					return "ユーザー +300人、ブランド +10、評判 +5"
				7: # アクセラレーター
					var amount = mini(800, cap)
					gs.cash += amount
					gs.product_power = mini(gs.product_power + 8, 100)
					gs.brand_value = mini(gs.brand_value + 5, 100)
					return "資金 +%d万円、プロダクト力 +8、ブランド +5" % amount

		"vc":
			match idx:
				0: # メガラウンド
					var amount = mini(5000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 15, 100)
					gs.brand_value = mini(gs.brand_value + 10, 100)
					return "資金 +%d万円、評判 +15、ブランド +10" % amount
				1: # 標準出資
					var amount = mini(2000, cap)
					gs.cash += amount
					return "資金 +%d万円" % amount
				2: # 小規模出資
					var amount = mini(1000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 5, 100)
					return "資金 +%d万円、評判 +5" % amount
				3: # 好条件出資
					var amount = mini(3000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 10, 100)
					return "資金 +%d万円、評判 +10" % amount
				4: # 却下
					gs.reputation = maxi(gs.reputation - 10, 0)
					gs.team_morale = maxi(gs.team_morale - 10, 0)
					return "却下された… 評判 -10、士気 -10"
				5: # 厳しい条件
					var amount = mini(2500, cap)
					gs.cash += amount
					gs.reputation = maxi(gs.reputation - 15, 0)
					return "資金 +%d万円、評判 -15（持株比率大）" % amount
				6: # 大型ラウンド
					var amount = mini(4000, cap)
					gs.cash += amount
					gs.brand_value = mini(gs.brand_value + 5, 100)
					return "資金 +%d万円、ブランド +5" % amount
				7: # リードインベスター
					var amount = mini(3500, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 20, 100)
					gs.product_power = mini(gs.product_power + 3, 100)
					return "資金 +%d万円、評判 +20、プロダクト力 +3" % amount

		"bank":
			match idx:
				0: # 特別融資枠
					var amount = mini(2000, cap)
					gs.cash += amount
					return "資金 +%d万円" % amount
				1: # 標準融資
					var amount = mini(1000, cap)
					gs.cash += amount
					return "資金 +%d万円" % amount
				2: # 少額融資
					var amount = mini(500, cap)
					gs.cash += amount
					return "資金 +%d万円" % amount
				3: # 好条件融資
					var amount = mini(1500, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 5, 100)
					return "資金 +%d万円、評判 +5" % amount
				4: # 審査落ち
					gs.team_morale = maxi(gs.team_morale - 3, 0)
					return "審査落ち… 士気 -3"
				5: # 担保要求
					var amount = mini(1200, cap)
					gs.cash += amount
					gs.product_power = maxi(gs.product_power - 3, 0)
					return "資金 +%d万円、プロダクト力 -3" % amount
				6: # 大口融資
					var amount = mini(1800, cap)
					gs.cash += amount
					return "資金 +%d万円" % amount
				7: # 信用枠拡大
					var amount = mini(800, cap)
					gs.cash += amount
					# Reduce next bank cooldown by setting a flag (simplified: just give reputation)
					gs.reputation = mini(gs.reputation + 3, 100)
					return "資金 +%d万円、信用力UP（評判 +3）" % amount

		"crowdfund":
			match idx:
				0: # 社会現象
					var amount = mini(3000, cap)
					gs.cash += amount
					gs.users += 1000
					gs.brand_value = mini(gs.brand_value + 20, 100)
					return "資金 +%d万円、ユーザー +1000人、ブランド +20" % amount
				1: # 目標達成
					var amount = mini(1000, cap)
					gs.cash += amount
					gs.users += 200
					gs.brand_value = mini(gs.brand_value + 5, 100)
					return "資金 +%d万円、ユーザー +200人、ブランド +5" % amount
				2: # そこそこ達成
					var amount = mini(600, cap)
					gs.cash += amount
					gs.users += 100
					return "資金 +%d万円、ユーザー +100人" % amount
				3: # ストレッチゴール
					var amount = mini(2000, cap)
					gs.cash += amount
					gs.users += 500
					gs.brand_value = mini(gs.brand_value + 10, 100)
					return "資金 +%d万円、ユーザー +500人、ブランド +10" % amount
				4: # 目標未達
					var amount = mini(200, cap)
					gs.cash += amount
					gs.brand_value = maxi(gs.brand_value - 5, 0)
					return "資金 +%d万円、ブランド -5" % amount
				5: # 炎上
					gs.reputation = maxi(gs.reputation - 10, 0)
					gs.brand_value = maxi(gs.brand_value - 15, 0)
					gs.users = maxi(gs.users - 100, 0)
					return "評判 -10、ブランド -15、ユーザー -100人"
				6: # バズって大成功
					var amount = mini(2500, cap)
					gs.cash += amount
					gs.users += 800
					gs.brand_value = mini(gs.brand_value + 15, 100)
					return "資金 +%d万円、ユーザー +800人、ブランド +15" % amount
				7: # コミュニティ形成
					var amount = mini(700, cap)
					gs.cash += amount
					gs.users += 300
					gs.team_morale = mini(gs.team_morale + 10, 100)
					gs.brand_value = mini(gs.brand_value + 8, 100)
					return "資金 +%d万円、ユーザー +300人、士気 +10、ブランド +8" % amount

	return ""
