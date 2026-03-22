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
	{
		"id": "factoring",
		"name": "ファクタリング",
		"icon": "💸",
		"description": "売掛金を即現金化。手数料が高いが審査なし・即日入金。",
		"color": Color(0.80, 0.30, 0.30),
		"cooldown": 1,
		"variance": "low",
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

const FACTORING_SQUARES := [
	{"name": "優良債権買取", "icon": "💎", "color": Color(0.95, 0.75, 0.15)},
	{"name": "標準ファクタリング", "icon": "💸", "color": Color(0.50, 0.60, 0.50)},
	{"name": "高手数料買取", "icon": "⚠️", "color": Color(0.80, 0.50, 0.25)},
	{"name": "一括買取", "icon": "📦", "color": Color(0.40, 0.60, 0.70)},
	{"name": "審査不通過", "icon": "❌", "color": Color(0.55, 0.40, 0.40)},
	{"name": "悪質業者", "icon": "🦊", "color": Color(0.75, 0.25, 0.25)},
	{"name": "即日入金", "icon": "⚡", "color": Color(0.35, 0.70, 0.55)},
	{"name": "大口買取", "icon": "🏆", "color": Color(0.60, 0.50, 0.80)},
]

const _SQUARES_MAP := {
	"angel": ANGEL_SQUARES,
	"vc": VC_SQUARES,
	"bank": BANK_SQUARES,
	"crowdfund": CROWDFUND_SQUARES,
	"factoring": FACTORING_SQUARES,
}

# Dice-sum-to-position mapping tables per type
# Each maps modified dice sum ranges to board square indices
const _DICE_MAP := {
	"angel": {3: 5, 4: 5, 5: 4, 6: 4, 7: 2, 8: 2, 9: 1, 10: 1, 11: 3, 12: 3, 13: 6, 14: 6, 15: 7, 16: 7, 17: 0, 18: 0},
	"vc": {3: 4, 4: 4, 5: 4, 6: 5, 7: 5, 8: 2, 9: 2, 10: 1, 11: 1, 12: 1, 13: 3, 14: 3, 15: 6, 16: 6, 17: 7, 18: 7, 19: 0, 20: 0, 21: 0, 22: 0},
	"bank": {3: 4, 4: 4, 5: 4, 6: 2, 7: 2, 8: 2, 9: 1, 10: 1, 11: 1, 12: 3, 13: 3, 14: 3, 15: 6, 16: 6, 17: 6, 18: 0},
	"crowdfund": {3: 5, 4: 5, 5: 5, 6: 4, 7: 4, 8: 2, 9: 2, 10: 2, 11: 1, 12: 1, 13: 1, 14: 3, 15: 3, 16: 6, 17: 6, 18: 0, 19: 0, 20: 0},
	"factoring": {3: 5, 4: 5, 5: 4, 6: 4, 7: 2, 8: 2, 9: 1, 10: 1, 11: 1, 12: 3, 13: 3, 14: 6, 15: 6, 16: 7, 17: 7, 18: 0},
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
		"factoring":
			return gs.revenue > 0  # 売上があれば利用可能（クールダウン短い）
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
		"factoring":
			return "売上あり"
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
		"factoring":
			if gs.revenue >= 200:
				modified += 2
			elif gs.revenue >= 50:
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


## 希釈率をバリュエーションベースで計算（現実準拠）
## amount / (pre_money + amount) で希釈率を算出
## penalty_mult: 厳しい条件時に1.0超を指定（例: 1.3 = 30%増）
static func _calc_dilution(amount: int, valuation: int, emergency: bool, penalty_mult: float = 1.0) -> float:
	var pre_money = maxf(valuation, 10000.0)  # 最低バリュエーション1億円
	var dilution = amount / (pre_money + amount) * 100.0 * penalty_mult
	if emergency:
		dilution *= 2.0
	return dilution


static func apply_effect(type_id: String, square_index: int, gs, emergency: bool = false) -> String:
	var cap = gs.max_fundraise_amount
	var idx = square_index % 8

	match type_id:
		"angel":
			match idx:
				0: # 大口エンジェル
					var amount = mini(3000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 10, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +10（持株 %.1f%%）" % [amount, gs.equity_share]
				1: # 少額エンジェル
					var amount = mini(500, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 5, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +5（持株 %.1f%%）" % [amount, gs.equity_share]
				2: # 条件付き出資
					var amount = mini(1200, cap)
					gs.cash += amount
					gs.reputation = maxi(gs.reputation - 10, 0)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 -10（持株 %.1f%%）" % [amount, gs.equity_share]
				3: # 起業家の紹介
					var amount = mini(800, cap)
					gs.cash += amount
					gs.add_product_power(5)
					gs.reputation = mini(gs.reputation + 5, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、プロダクト力 +5、評判 +5（持株 %.1f%%）" % [amount, gs.equity_share]
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
					gs.add_product_power(8)
					gs.brand_value = mini(gs.brand_value + 5, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、プロダクト力 +8、ブランド +5（持株 %.1f%%）" % [amount, gs.equity_share]

		"vc":
			match idx:
				0: # メガラウンド
					var amount = mini(5000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 15, 100)
					gs.brand_value = mini(gs.brand_value + 10, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +15、ブランド +10（持株 %.1f%%）" % [amount, gs.equity_share]
				1: # 標準出資
					var amount = mini(2000, cap)
					gs.cash += amount
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円（持株 %.1f%%）" % [amount, gs.equity_share]
				2: # 小規模出資
					var amount = mini(1000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 5, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +5（持株 %.1f%%）" % [amount, gs.equity_share]
				3: # 好条件出資
					var amount = mini(3000, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 10, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +10（持株 %.1f%%）" % [amount, gs.equity_share]
				4: # 却下
					gs.reputation = maxi(gs.reputation - 10, 0)
					gs.team_morale = maxi(gs.team_morale - 10, 0)
					return "却下された… 評判 -10、士気 -10"
				5: # 厳しい条件
					var amount = mini(2500, cap)
					gs.cash += amount
					gs.reputation = maxi(gs.reputation - 15, 0)
					var dilution = _calc_dilution(amount, gs.valuation, emergency, 1.3)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 -15（持株 %.1f%%）" % [amount, gs.equity_share]
				6: # 大型ラウンド
					var amount = mini(4000, cap)
					gs.cash += amount
					gs.brand_value = mini(gs.brand_value + 5, 100)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、ブランド +5（持株 %.1f%%）" % [amount, gs.equity_share]
				7: # リードインベスター
					var amount = mini(3500, cap)
					gs.cash += amount
					gs.reputation = mini(gs.reputation + 20, 100)
					gs.add_product_power(3)
					var dilution = _calc_dilution(amount, gs.valuation, emergency)
					gs.equity_share = maxf(gs.equity_share - dilution, 0.0)
					return "資金 +%d万円、評判 +20、プロダクト力 +3（持株 %.1f%%）" % [amount, gs.equity_share]

		"bank":
			# 銀行融資: 金利3〜8%、12ヶ月返済。持株希釈なし。
			match idx:
				0: # 特別融資枠
					var amount = mini(2000, cap)
					gs.cash += amount
					gs.add_loan("銀行特別融資", amount, 0.03, 12)
					return "融資 +%d万円（金利3%%/12ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.03 / 12.0))]
				1: # 標準融資
					var amount = mini(1000, cap)
					gs.cash += amount
					gs.add_loan("銀行融資", amount, 0.05, 12)
					return "融資 +%d万円（金利5%%/12ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.05 / 12.0))]
				2: # 少額融資
					var amount = mini(500, cap)
					gs.cash += amount
					gs.add_loan("銀行融資", amount, 0.04, 6)
					return "融資 +%d万円（金利4%%/6ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.04 / 6.0))]
				3: # 好条件融資
					var amount = mini(1500, cap)
					gs.cash += amount
					gs.add_loan("好条件融資", amount, 0.03, 12)
					gs.reputation = mini(gs.reputation + 5, 100)
					return "融資 +%d万円（金利3%%/12ヶ月）、評判 +5" % amount
				4: # 審査落ち
					gs.team_morale = maxi(gs.team_morale - 3, 0)
					return "審査落ち… 士気 -3"
				5: # 担保要求
					var amount = mini(1200, cap)
					gs.cash += amount
					gs.add_loan("担保付融資", amount, 0.06, 12)
					gs.add_product_power(-3)
					return "融資 +%d万円（金利6%%/12ヶ月）、プロダクト力 -3" % amount
				6: # 大口融資
					var amount = mini(1800, cap)
					gs.cash += amount
					gs.add_loan("大口融資", amount, 0.05, 18)
					return "融資 +%d万円（金利5%%/18ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.05 / 18.0))]
				7: # 信用枠拡大
					var amount = mini(800, cap)
					gs.cash += amount
					gs.add_loan("信用枠融資", amount, 0.03, 6)
					gs.reputation = mini(gs.reputation + 3, 100)
					return "融資 +%d万円（金利3%%/6ヶ月）、評判 +3" % amount

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

		"factoring":
			# ファクタリング: 高手数料（10〜20%）、短期返済。即現金化。
			var rev = maxi(gs.revenue, 50)
			match idx:
				0: # 優良債権買取
					var amount = mini(rev * 3, cap)
					gs.cash += amount
					gs.add_loan("ファクタリング", amount, 0.10, 3)
					return "即入金 +%d万円（手数料10%%/3ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.10 / 3.0))]
				1: # 標準ファクタリング
					var amount = mini(rev * 2, cap)
					gs.cash += amount
					gs.add_loan("ファクタリング", amount, 0.15, 3)
					return "即入金 +%d万円（手数料15%%/3ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.15 / 3.0))]
				2: # 高手数料買取
					var amount = mini(rev * 2, cap)
					gs.cash += amount
					gs.add_loan("ファクタリング", amount, 0.20, 3)
					return "即入金 +%d万円（手数料20%%/3ヶ月返済）⚠️高手数料" % amount
				3: # 一括買取
					var amount = mini(rev * 4, cap)
					gs.cash += amount
					gs.add_loan("ファクタリング", amount, 0.12, 6)
					return "即入金 +%d万円（手数料12%%/6ヶ月返済、月%d万円）" % [amount, int(ceil(amount * 1.12 / 6.0))]
				4: # 審査不通過
					gs.team_morale = maxi(gs.team_morale - 3, 0)
					return "売掛金が認められず不通過… 士気 -3"
				5: # 悪質業者
					var amount = mini(rev, cap)
					gs.cash += amount
					gs.add_loan("悪質ファクタリング", amount, 0.30, 3)
					gs.reputation = maxi(gs.reputation - 5, 0)
					return "即入金 +%d万円（手数料30%%！）評判 -5 ⚠️悪質業者" % amount
				6: # 即日入金
					var amount = mini(rev * 2, cap)
					gs.cash += amount
					gs.add_loan("ファクタリング", amount, 0.12, 3)
					return "即日入金 +%d万円（手数料12%%/3ヶ月返済）" % amount
				7: # 大口買取
					var amount = mini(rev * 5, cap)
					gs.cash += amount
					gs.add_loan("大口ファクタリング", amount, 0.10, 6)
					gs.reputation = mini(gs.reputation + 3, 100)
					return "大口即入金 +%d万円（手数料10%%/6ヶ月）、信用力UP" % amount

	return ""
