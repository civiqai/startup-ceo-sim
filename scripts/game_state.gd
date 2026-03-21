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

# 月間コスト: チーム人数 × 50万
var monthly_cost: int:
	get:
		return team_size * 50

# 時価総額の簡易計算
var valuation: int:
	get:
		return users * product_power + reputation * 100

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
	state_changed.emit()


func advance_month() -> void:
	month += 1
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
				var gain = randi_range(50, 200) * product_power / 10
				users += gain
				result = "マーケティング実施。ユーザー +%d人" % gain
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
