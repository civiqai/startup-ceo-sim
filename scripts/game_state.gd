extends Node
## ゲーム全体の状態を管理するシングルトン (Autoload)

signal state_changed
signal game_over(reason: String)
signal game_clear(reason: String)

# 経営パラメータ
var cash: int = 1000         # 資金（万円）
var product_power: int = 10  # プロダクト力 (0-100)
var team_size: int = 1       # チーム人数
var team_morale: int = 70    # チーム士気 (0-100)
var users: int = 0           # ユーザー数
var reputation: int = 30     # 投資家評判 (0-100)
var month: int = 0           # 経過月数
var brand_value: int = 0       # ブランド価値 (0-100)
var fundraise_cooldown: int = 0 # 資金調達クールダウン残り月数
var total_raised: int = 0       # 累計調達額
var fundraise_count: int = 0    # 調達回数

# 月間コスト: チーム人数 × 50万
var monthly_cost: int:
	get:
		return team_size * 50

# 月間売上
var revenue: int:
	get:
		if users <= 0 or product_power <= 0:
			return 0
		var base = users * product_power / 500
		var brand_multiplier = 1.0 + (brand_value / 200.0)
		return int(base * brand_multiplier)

# 時価総額
var valuation: int:
	get:
		var user_component = users * product_power
		var brand_component = brand_value * brand_value * 2
		var revenue_component = revenue * 120
		var reputation_component = reputation * 100
		return user_component + brand_component + revenue_component + reputation_component

# 最大調達可能額
var max_fundraise_amount: int:
	get:
		var base = 500
		var product_factor = product_power * 20
		var user_factor = mini(users, 10000) / 2
		var brand_factor = brand_value * 30
		var revenue_factor = revenue * 24
		var reputation_factor = reputation * 15
		var raw = base + product_factor + user_factor + brand_factor + revenue_factor + reputation_factor
		var diminish = pow(0.80, fundraise_count)
		return int(raw * diminish)

# IPO条件: 時価総額100億円（1000000万円）
const IPO_THRESHOLD := 1000000


func reset() -> void:
	cash = 1000
	product_power = 10
	team_size = 1
	team_morale = 70
	users = 0
	reputation = 30
	month = 0
	brand_value = 0
	fundraise_cooldown = 0
	total_raised = 0
	fundraise_count = 0
	state_changed.emit()


func advance_month() -> void:
	month += 1
	# 売上入金
	cash += revenue
	# オーガニックユーザー獲得
	users += brand_value * product_power / 50
	# ブランド自然減衰
	if brand_value >= 20:
		brand_value -= 1
	# 資金調達クールダウン
	if fundraise_cooldown > 0:
		fundraise_cooldown -= 1
	cash -= monthly_cost

	if cash <= 0:
		cash = 0
		state_changed.emit()
		game_over.emit("資金がゼロになりました…倒産です。")
		return

	if valuation >= IPO_THRESHOLD:
		state_changed.emit()
		game_clear.emit("時価総額100億円達成！IPOおめでとうございます！")
		return

	state_changed.emit()


func apply_action(action: String) -> String:
	var result := ""
	match action:
		"develop":
			var gain = randi_range(3, 8) + team_size
			if team_morale > 60:
				gain += 3
			product_power = mini(product_power + gain, 100)
			result = "開発に集中した。プロダクト力 +%d" % gain
		"hire":
			if cash < 200:
				result = "資金が足りず採用できなかった。"
			else:
				cash -= 200
				team_size += 1
				team_morale -= 5
				result = "新メンバーを1人採用した。（採用費200万円）"
		"marketing":
			if cash < 100:
				result = "資金が足りずマーケティングできなかった。"
			else:
				cash -= 100
				var brand_gain = randi_range(5, 12)
				brand_value = mini(brand_value + brand_gain, 100)
				var direct_users = randi_range(20, 80) * product_power / 20
				users += direct_users
				result = "マーケティング実施。ブランド価値 +%d、ユーザー +%d人" % [brand_gain, direct_users]
		"fundraise":
			var amount = randi_range(500, 2000) * reputation / 30
			cash += amount
			reputation -= randi_range(5, 15)
			reputation = maxi(reputation, 0)
			result = "資金調達成功！%d万円を獲得（評判ダウン）" % amount
		"team_care":
			var gain = randi_range(10, 20)
			team_morale = mini(team_morale + gain, 100)
			result = "チームケアを実施。士気 +%d" % gain

	return result
