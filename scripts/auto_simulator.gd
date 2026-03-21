extends Node
## 自動シミュレーション: N回のゲームを自動実行し統計を出力

class_name AutoSimulator

signal simulation_completed(results: Dictionary)
signal simulation_progress(current: int, total: int)

# 戦略定義
enum Strategy {
	RANDOM,
	AGGRESSIVE_HIRING,
	BALANCED,
	PRODUCT_FOCUSED,
	FUNDRAISE_HEAVY,
}

const STRATEGY_NAMES := {
	Strategy.RANDOM: "ランダム",
	Strategy.AGGRESSIVE_HIRING: "積極採用",
	Strategy.BALANCED: "バランス型",
	Strategy.PRODUCT_FOCUSED: "プロダクト重視",
	Strategy.FUNDRAISE_HEAVY: "資金調達重視",
}

const ACTIONS := ["develop", "hire", "marketing", "fundraise", "team_care"]
const MAX_TURNS := 120  # 最大10年


## 戦略に基づいてアクションを選択
static func choose_action(strategy: Strategy, gs_snapshot: Dictionary) -> String:
	match strategy:
		Strategy.RANDOM:
			return ACTIONS[randi() % ACTIONS.size()]
		Strategy.AGGRESSIVE_HIRING:
			if gs_snapshot.cash >= 400:
				return "hire"
			elif gs_snapshot.cash < 200:
				return "fundraise"
			elif gs_snapshot.team_morale < 40:
				return "team_care"
			else:
				return "develop"
		Strategy.BALANCED:
			var month: int = gs_snapshot.month
			if gs_snapshot.cash < 300:
				return "fundraise"
			elif gs_snapshot.team_morale < 40:
				return "team_care"
			elif month % 5 == 0 and gs_snapshot.cash >= 200:
				return "hire"
			elif month % 3 == 0 and gs_snapshot.cash >= 100:
				return "marketing"
			else:
				return "develop"
		Strategy.PRODUCT_FOCUSED:
			if gs_snapshot.cash < 200:
				return "fundraise"
			elif gs_snapshot.team_morale < 30:
				return "team_care"
			elif gs_snapshot.product_power < 80:
				return "develop"
			elif gs_snapshot.cash >= 100:
				return "marketing"
			else:
				return "develop"
		Strategy.FUNDRAISE_HEAVY:
			if gs_snapshot.reputation > 20:
				return "fundraise"
			elif gs_snapshot.team_morale < 30:
				return "team_care"
			elif gs_snapshot.cash >= 200 and gs_snapshot.team_size < 5:
				return "hire"
			else:
				return "develop"
	return "develop"


## 1ゲームをシミュレーション（GameStateを直接操作）
static func simulate_one_game(strategy: Strategy) -> Dictionary:
	# ローカル状態でシミュレーション
	var state := {
		"cash": 1000,
		"product_power": 10,
		"team_size": 1,
		"team_morale": 70,
		"users": 0,
		"reputation": 30,
		"month": 0,
	}

	var result := {
		"won": false,
		"months": 0,
		"reason": "",
		"final_valuation": 0,
		"final_cash": 0,
		"final_users": 0,
	}

	# イベント定義（簡易版）
	var event_effects := [
		func(s: Dictionary): s.users += randi_range(100, 500); s.reputation += 10,
		func(s: Dictionary): s.users -= randi_range(30, 100); s.users = maxi(s.users, 0),
		func(s: Dictionary):
			if s.team_size > 1:
				s.team_size -= 1; s.team_morale -= 15,
		func(s: Dictionary): s.cash -= 100; s.reputation -= 5,
		func(s: Dictionary): s.cash += 500; s.reputation += 15,
		func(s: Dictionary): s.reputation -= 20; s.reputation = maxi(s.reputation, 0); s.users += randi_range(50, 200),
		func(s: Dictionary): s.team_size += 1; s.team_morale += 5,
		func(s: Dictionary): s.reputation += randi_range(5, 20),
	]

	for turn in MAX_TURNS:
		# アクション選択・実行
		var action := choose_action(strategy, state)
		_apply_action_to_state(state, action)

		# ランダムイベント（30%）
		if randf() <= 0.3:
			var effect = event_effects[randi() % event_effects.size()]
			effect.call(state)

		# 月末処理
		state.month += 1
		state.cash -= state.team_size * 50

		# クランプ
		state.team_morale = clampi(state.team_morale, 0, 100)
		state.reputation = clampi(state.reputation, 0, 100)
		state.product_power = clampi(state.product_power, 0, 100)
		state.users = maxi(state.users, 0)

		var valuation: int = state.users * state.product_power + state.reputation * 100

		# 判定
		if state.cash <= 0:
			result.won = false
			result.months = state.month
			result.reason = "倒産"
			result.final_valuation = valuation
			result.final_cash = 0
			result.final_users = state.users
			return result

		if valuation >= 1000000:
			result.won = true
			result.months = state.month
			result.reason = "IPO達成"
			result.final_valuation = valuation
			result.final_cash = state.cash
			result.final_users = state.users
			return result

	# タイムアウト
	var valuation: int = state.users * state.product_power + state.reputation * 100
	result.won = false
	result.months = MAX_TURNS
	result.reason = "タイムアウト（%dヶ月）" % MAX_TURNS
	result.final_valuation = valuation
	result.final_cash = state.cash
	result.final_users = state.users
	return result


static func _apply_action_to_state(state: Dictionary, action: String) -> void:
	match action:
		"develop":
			var gain = randi_range(3, 8) + state.team_size
			if state.team_morale > 60:
				gain += 3
			state.product_power = mini(state.product_power + gain, 100)
		"hire":
			if state.cash >= 200:
				state.cash -= 200
				state.team_size += 1
				state.team_morale -= 5
		"marketing":
			if state.cash >= 100:
				state.cash -= 100
				var gain = randi_range(50, 200) * state.product_power / 10
				state.users += gain
		"fundraise":
			var amount = randi_range(500, 2000) * state.reputation / 30
			state.cash += amount
			state.reputation -= randi_range(5, 15)
			state.reputation = maxi(state.reputation, 0)
		"team_care":
			var gain = randi_range(10, 20)
			state.team_morale = mini(state.team_morale + gain, 100)


## N回シミュレーション実行して統計を返す
func run_simulation(strategy: Strategy, num_games: int) -> Dictionary:
	var wins := 0
	var total_months := 0
	var total_valuation := 0
	var win_months := 0
	var loss_months := 0
	var losses := 0
	var timeouts := 0
	var results_list := []

	for i in num_games:
		var r := simulate_one_game(strategy)
		results_list.append(r)
		total_months += r.months
		total_valuation += r.final_valuation
		if r.won:
			wins += 1
			win_months += r.months
		elif r.reason.begins_with("タイムアウト"):
			timeouts += 1
		else:
			losses += 1
			loss_months += r.months

		if i % 10 == 0:
			simulation_progress.emit(i, num_games)

	var stats := {
		"strategy": STRATEGY_NAMES[strategy],
		"num_games": num_games,
		"wins": wins,
		"losses": losses,
		"timeouts": timeouts,
		"win_rate": float(wins) / num_games * 100.0,
		"avg_months": float(total_months) / num_games,
		"avg_months_to_ipo": float(win_months) / maxi(wins, 1),
		"avg_months_to_bankruptcy": float(loss_months) / maxi(losses, 1),
		"avg_final_valuation": total_valuation / num_games,
	}

	simulation_completed.emit(stats)
	return stats


## 全戦略を比較実行
func run_all_strategies(num_games: int) -> Array[Dictionary]:
	var all_stats: Array[Dictionary] = []
	for strategy_key in STRATEGY_NAMES.keys():
		var stats := run_simulation(strategy_key, num_games)
		all_stats.append(stats)
	return all_stats


## 統計結果をテキスト化
static func format_stats(stats: Dictionary) -> String:
	var text := ""
	text += "[b]戦略: %s[/b]\n" % stats.strategy
	text += "  試行回数: %d\n" % stats.num_games
	text += "  勝利(IPO): %d / 敗北(倒産): %d / タイムアウト: %d\n" % [stats.wins, stats.losses, stats.timeouts]
	text += "  勝率: %.1f%%\n" % stats.win_rate
	text += "  平均所要月数: %.1f ヶ月\n" % stats.avg_months
	text += "  IPO平均月数: %.1f ヶ月\n" % stats.avg_months_to_ipo
	text += "  倒産平均月数: %.1f ヶ月\n" % stats.avg_months_to_bankruptcy
	text += "  平均最終時価総額: %d 万円\n" % stats.avg_final_valuation
	return text


static func format_all_stats(all_stats: Array[Dictionary]) -> String:
	var text := "[b]=== 自動シミュレーション結果 ===[/b]\n\n"
	for stats in all_stats:
		text += format_stats(stats) + "\n"
	return text
