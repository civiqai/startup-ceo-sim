extends Node
## ゲーム全体の状態を管理するシングルトン (Autoload)

signal state_changed
signal game_over(reason: String)
signal game_clear(reason: String)
signal emergency_fundraise_requested
signal training_completed(member, training_id: String)
signal headhunt_occurred(member, offer_salary: int)

const TeamMemberClass = preload("res://scripts/team_member.gd")

# 経営パラメータ
var cash: int = 1000         # 資金（万円）

# プロダクトパラメータはProductManagerのプロダクトに移動
# 後方互換getter（全アクティブプロダクトの平均）
var product_ux: int:
	get:
		var pm = _get_product_manager()
		if pm == null: return 0
		var active = pm.get_active_products()
		if active.is_empty(): return 0
		var total := 0
		for p in active: total += p.get("ux", 0)
		return total / active.size()

var product_design: int:
	get:
		var pm = _get_product_manager()
		if pm == null: return 0
		var active = pm.get_active_products()
		if active.is_empty(): return 0
		var total := 0
		for p in active: total += p.get("design", 0)
		return total / active.size()

var product_margin: int:
	get:
		var pm = _get_product_manager()
		if pm == null: return 0
		var active = pm.get_active_products()
		if active.is_empty(): return 0
		var total := 0
		for p in active: total += p.get("margin", 0)
		return total / active.size()

var product_awareness: int:
	get:
		var pm = _get_product_manager()
		if pm == null: return 0
		var active = pm.get_active_products()
		if active.is_empty(): return 0
		var total := 0
		for p in active: total += p.get("awareness", 0)
		return total / active.size()

# product_power は計算プロパティ（後方互換）
var product_power: int:
	get:
		return (product_ux + product_design + product_margin + product_awareness) / 4
var team_morale: int = 70    # チーム士気 (0-100)
var users: int = 0           # ユーザー数
var reputation: int = 30     # 投資家評判 (0-100)
var month: int = 0           # 経過月数
var brand_value: int = 0       # ブランド価値 (0-100)
var fundraise_cooldown: int = 0 # 資金調達クールダウン残り月数
var total_raised: int = 0       # 累計調達額
var fundraise_count: int = 0    # 調達回数
var marketing_channel_counts: Dictionary = {}  # チャネル別マーケ実行回数
var equity_share: float = 100.0  # 持ち株比率 (%) - 初期100%

# 借入金（銀行融資・ファクタリング）
var loans: Array[Dictionary] = []  # [{source, principal, remaining, monthly_payment, interest_rate, months_left}]
var total_loan_balance: int = 0    # 借入残高合計（表示用キャッシュ）

# 受託開発
var contract_work_remaining: int = 0  # 受託開発残り月数
var contract_work_name: String = ""   # 受託案件名
var contract_work_reward: int = 0     # 受託報酬
var contract_just_completed: bool = false  # 受託完了フラグ（ターン処理用）
var contract_completed_reward: int = 0     # 完了時の報酬額

const CONTRACT_JOBS := [
	# 小規模（1-2ヶ月）
	{"name": "地方自治体のポータルサイト", "reward": 600, "months": 2, "eng_bonus": 2},
	{"name": "飲食チェーンの予約システム", "reward": 500, "months": 1, "eng_bonus": 2},
	{"name": "NPO団体の会員管理サイト", "reward": 400, "months": 1, "eng_bonus": 1},
	{"name": "美容院の顧客カルテアプリ", "reward": 550, "months": 2, "eng_bonus": 2},
	{"name": "中小企業の社内Wiki構築", "reward": 450, "months": 1, "eng_bonus": 1},
	# 中規模（2-3ヶ月）
	{"name": "大手商社の在庫管理システム", "reward": 800, "months": 2, "eng_bonus": 3},
	{"name": "不動産マッチングアプリ", "reward": 1000, "months": 3, "eng_bonus": 3},
	{"name": "教育プラットフォーム構築", "reward": 1200, "months": 3, "eng_bonus": 4},
	{"name": "人材紹介会社のCRM開発", "reward": 900, "months": 2, "eng_bonus": 3},
	{"name": "EC事業者の受注管理システム", "reward": 1100, "months": 3, "eng_bonus": 4},
	{"name": "旅行代理店の予約エンジン", "reward": 1000, "months": 3, "eng_bonus": 3},
	{"name": "農業IoTデータ可視化ツール", "reward": 1300, "months": 3, "eng_bonus": 4},
	# 大規模（3-4ヶ月）
	{"name": "製造業向けERPカスタマイズ", "reward": 1500, "months": 3, "eng_bonus": 5},
	{"name": "医療系予約システム", "reward": 2000, "months": 4, "eng_bonus": 6},
	{"name": "金融機関のリスク管理ツール", "reward": 2500, "months": 4, "eng_bonus": 7},
	{"name": "保険会社の査定自動化システム", "reward": 2200, "months": 4, "eng_bonus": 6},
	{"name": "大手小売のPOSリプレイス", "reward": 1800, "months": 4, "eng_bonus": 5},
	# 超大規模（5ヶ月）
	{"name": "物流会社の配車最適化AI", "reward": 3000, "months": 5, "eng_bonus": 8},
	{"name": "官公庁の電子申請基盤", "reward": 3500, "months": 5, "eng_bonus": 8},
	{"name": "メガバンクの勘定系マイグレーション", "reward": 4000, "months": 5, "eng_bonus": 9},
]

# フェーズ別の受託報酬倍率（フェーズ0=1.0倍をベースに段階的に上昇）
const CONTRACT_PHASE_MULTIPLIER := [1.0, 1.5, 2.5, 4.0, 6.0, 8.0]

## フェーズに応じた報酬倍率を適用した受託案件リストを返す
func get_scaled_contract_jobs() -> Array[Dictionary]:
	var phase: int = current_phase
	var multiplier: float = CONTRACT_PHASE_MULTIPLIER[mini(phase, CONTRACT_PHASE_MULTIPLIER.size() - 1)]
	var scaled: Array[Dictionary] = []
	for job in CONTRACT_JOBS:
		var scaled_job: Dictionary = job.duplicate()
		scaled_job["reward"] = int(job["reward"] * multiplier)
		scaled.append(scaled_job)
	return scaled

# 品質パラメータ（24時間制で継続成長）
var code_quality: int = 30       # コード品質 (0-100) - バグ発生率に影響
var ux_quality: int = 20         # UX品質 (0-100) - ユーザー満足度に影響
var infra_stability: int = 30    # インフラ安定性 (0-100) - 障害確率に影響
var security_score: int = 20     # セキュリティ (0-100) - 脆弱性イベント確率に影響
var overtime_enabled: bool = false  # 残業モード
var current_phase: int = 0  # フェーズ制（PhaseManager参照）
var tutorial_month: int = 0  # チュートリアル進行（-1 = 完了、0-6 = ガイド中）

# 月次KPI履歴（KPIダッシュボード用）
var monthly_history: Array[Dictionary] = []

# チーム人数（TeamManagerから取得、社長分+1）
var team_size: int:
	get:
		return TeamManager.members.size() + 1

# 月間コスト: 社長50万 + メンバーの給与合計
var monthly_cost: int:
	get:
		var base: int = 50 + TeamManager.get_total_monthly_cost()
		var infra_cost: int = users / 100
		return base + infra_cost

# 月間売上（MRR）
# ユーザー数 × ARPU（利益率+UXで決まる単価） × ブランド倍率
var revenue: int:
	get:
		if users <= 0:
			return 0
		# ARPU = (margin + ux) / 100 万円 → ユーザー1000人・合計50で MRR 500万
		var arpu: float = (product_margin + product_ux) / 100.0
		var brand_multiplier: float = 1.0 + (brand_value / 100.0)
		return int(users * arpu * brand_multiplier)

# 時価総額
var valuation: int:
	get:
		var product_component: int = users * product_power
		var brand_component: int = brand_value * brand_value * 5
		var revenue_component: int = revenue * 40
		var reputation_component: int = maxi(reputation - 30, 0) * 300
		var team_component: int = team_size * team_size * 50
		return product_component + brand_component + revenue_component + reputation_component + team_component

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
	team_morale = 70
	users = 0
	reputation = 30
	month = 0
	brand_value = 0
	fundraise_cooldown = 0
	total_raised = 0
	fundraise_count = 0
	marketing_channel_counts.clear()
	equity_share = 100.0
	loans.clear()
	total_loan_balance = 0
	contract_work_remaining = 0
	contract_work_name = ""
	contract_work_reward = 0
	code_quality = 30
	ux_quality = 20
	infra_stability = 30
	security_score = 20
	overtime_enabled = false
	current_phase = 0
	tutorial_month = 0
	monthly_history.clear()
	TeamManager.members.clear()
	state_changed.emit()


func advance_month() -> void:
	month += 1
	# メンバーの在籍月数を更新
	for m in TeamManager.members:
		m.months_employed += 1
	# パッシブ経験値成長
	for m in TeamManager.members:
		if m.is_in_training():
			continue  # 訓練中は別途付与
		var base_exp := randi_range(10, 15)
		# 士気70以上ボーナス
		if team_morale >= 70:
			base_exp += 5
		# 同スキルタイプにリーダー以上がいればボーナス
		for other in TeamManager.members:
			if other != m and other.skill_type == m.skill_type and other.role in ["leader", "manager", "cxo"]:
				base_exp += 5
				break
		var leveled_up: bool = m.add_experience(base_exp)
		if leveled_up:
			TeamManager.member_leveled_up.emit(m, m.skill_level - 1, m.skill_level)
	# 転職リスク自然減衰 (-0.02/月、下限0)
	for m in TeamManager.members:
		m.turnover_risk = maxf(m.turnover_risk - 0.02, 0.0)
	# 訓練進行処理
	var _training_completed_members: Array = []
	for m in TeamManager.members:
		if m.training != "" and m.training_remaining > 0:
			m.training_remaining -= 1
			if m.training_remaining <= 0:
				_training_completed_members.append({"member": m, "training_id": m.training})
				m.training = ""
				m.training_remaining = 0
	for completed in _training_completed_members:
		training_completed.emit(completed["member"], completed["training_id"])
	# ムードメーカーの士気ボーナス
	var morale_bonus := int(TeamManager.get_total_personality_effect("morale"))
	if morale_bonus > 0:
		team_morale = mini(team_morale + morale_bonus, 100)
	# 引き抜き判定
	var _headhunt_targets: Array = []
	for m in TeamManager.members:
		if m.turnover_risk <= 0.05:
			continue
		if team_morale >= 80:
			continue  # 居心地が良ければ残る
		# 給与が相場以下かチェック
		var market_salary: int = TeamMemberClass.BASE_SALARY.get(m.skill_type, 400) + m.skill_level * 120
		if m.salary >= market_salary:
			continue
		# 発生確率 = turnover_risk * 50%
		if randf() < m.turnover_risk * 0.5:
			_headhunt_targets.append(m)
	for m in _headhunt_targets:
		var base: int = TeamMemberClass.BASE_SALARY.get(m.skill_type, 400)
		var offer: int = base + m.skill_level * 150 + randi_range(50, 200)
		if m.skill_level >= 4:
			offer += 300  # 高レベルは引き抜きオファーが高い
		headhunt_occurred.emit(m, offer)
	# 売上入金
	cash += revenue
	# オーガニックユーザー獲得（各プロダクトの知名度×UXベース）
	var pm = _get_product_manager()
	if pm:
		for p in pm.get_active_products():
			var p_awareness = p.get("awareness", 0)
			var p_ux = p.get("ux", 0)
			p["users"] = p.get("users", 0) + p_awareness * p_ux / 50
	users += product_awareness * product_ux / 50
	# 月次チャーン（ユーザー離脱）
	if users > 0:
		var churn_rate: float = maxf(0.05 - product_power * 0.0003, 0.01)
		var churned: int = int(users * churn_rate)
		users = maxi(users - churned, 0)
	# ブランド自然減衰
	if brand_value >= 20:
		brand_value -= 1
	# 受託開発の進捗
	contract_just_completed = false
	if contract_work_remaining > 0:
		contract_work_remaining -= 1
		if contract_work_remaining <= 0:
			cash += contract_work_reward
			contract_just_completed = true
			contract_completed_reward = contract_work_reward
			# エンジニア技術力UP
			for m in TeamManager.members:
				if m.skill_type == "engineer":
					m.skill_level = mini(m.skill_level + 1, 5)
			contract_work_name = ""
			contract_work_reward = 0
	# 資金調達クールダウン
	if fundraise_cooldown > 0:
		fundraise_cooldown -= 1
	# 借入金の月次返済
	_process_loan_payments()
	cash -= monthly_cost

	# 月次KPI履歴を記録
	monthly_history.append({
		"month": month,
		"cash": cash,
		"revenue": revenue,
		"users": users,
		"product_power": product_power,
		"team_size": team_size,
		"monthly_cost": monthly_cost,
	})

	if cash <= 0:
		# 緊急資金調達: プレイヤーに選択させる
		if _can_emergency_fundraise():
			state_changed.emit()
			emergency_fundraise_requested.emit()
			return
		cash = 0
		state_changed.emit()
		game_over.emit("資金がゼロになりました…倒産です。")
		return

	if valuation >= IPO_THRESHOLD:
		state_changed.emit()
		game_clear.emit("時価総額100億円達成！IPOおめでとうございます！")
		return

	state_changed.emit()


## 緊急資金調達が可能かどうかを判定する
func _can_emergency_fundraise() -> bool:
	# いずれかの資金調達タイプが利用可能なら true
	var FundraiseTypes = preload("res://scripts/fundraise_types.gd")
	for type_data in FundraiseTypes.get_all_types():
		if FundraiseTypes.is_available(type_data["id"], self):
			return true
	return false


## 緊急資金調達後の処理（双六完了後にgame.gdから呼ばれる）
func complete_emergency_fundraise() -> void:
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


## 緊急資金調達を拒否した場合（game.gdから呼ばれる）
func fail_emergency_fundraise() -> void:
	cash = 0
	state_changed.emit()
	game_over.emit("資金がゼロになりました…倒産です。")


## 借入金を追加する（銀行融資・ファクタリング用）
func add_loan(source: String, principal: int, interest_rate: float, repay_months: int) -> void:
	var total_repay := int(principal * (1.0 + interest_rate))
	var monthly := int(ceil(float(total_repay) / repay_months))
	loans.append({
		"source": source,
		"principal": principal,
		"remaining": total_repay,
		"monthly_payment": monthly,
		"interest_rate": interest_rate,
		"months_left": repay_months,
	})
	_update_loan_balance()


## 月次の借入返済処理
func _process_loan_payments() -> void:
	var completed: Array[int] = []
	for i in range(loans.size()):
		var loan: Dictionary = loans[i]
		var payment: int = loan["monthly_payment"]
		cash -= payment
		loan["remaining"] -= payment
		loan["months_left"] -= 1
		if loan["months_left"] <= 0 or loan["remaining"] <= 0:
			completed.append(i)
	# 完済したローンを除去（逆順で）
	completed.reverse()
	for idx in completed:
		loans.remove_at(idx)
	_update_loan_balance()


## 月次返済額の合計を取得
func get_monthly_loan_payment() -> int:
	var total := 0
	for loan in loans:
		total += loan["monthly_payment"]
	return total


## 借入残高を更新
func _update_loan_balance() -> void:
	total_loan_balance = 0
	for loan in loans:
		total_loan_balance += loan["remaining"]


## イベント等でランダムメンバーを追加する
func add_random_member() -> void:
	var member := TeamManager.generate_candidate(2, 4)
	TeamManager.hire(member)


## イベント等でランダムメンバーを離脱させる
func remove_random_member() -> void:
	if TeamManager.members.size() > 0:
		var idx := randi() % TeamManager.members.size()
		var member = TeamManager.members[idx]
		TeamManager.fire(member)


# ヘルパー: プロダクト力を均等に分配して加算（ProductManager経由）
func add_product_power(amount: int) -> void:
	var pm = _get_product_manager()
	if pm == null:
		return
	var p = pm._get_active_product()
	if p.is_empty():
		return
	if amount >= 0:
		var per = amount / 4
		var remainder = amount % 4
		p["ux"] = mini(p.get("ux", 0) + per + (1 if remainder > 0 else 0), 100)
		p["design"] = mini(p.get("design", 0) + per + (1 if remainder > 1 else 0), 100)
		p["margin"] = mini(p.get("margin", 0) + per + (1 if remainder > 2 else 0), 100)
		p["awareness"] = mini(p.get("awareness", 0) + per, 100)
	else:
		var per = (-amount) / 4
		var remainder = (-amount) % 4
		p["ux"] = maxi(p.get("ux", 0) - per - (1 if remainder > 0 else 0), 0)
		p["design"] = maxi(p.get("design", 0) - per - (1 if remainder > 1 else 0), 0)
		p["margin"] = maxi(p.get("margin", 0) - per - (1 if remainder > 2 else 0), 0)
		p["awareness"] = maxi(p.get("awareness", 0) - per, 0)


# 特定パラメータを加算（ProductManager経由）
func add_product_stat(stat: String, amount: int) -> void:
	var pm = _get_product_manager()
	if pm == null:
		return
	var p = pm._get_active_product()
	if p.is_empty():
		return
	match stat:
		"ux": p["ux"] = clampi(p.get("ux", 0) + amount, 0, 100)
		"design": p["design"] = clampi(p.get("design", 0) + amount, 0, 100)
		"margin": p["margin"] = clampi(p.get("margin", 0) + amount, 0, 100)
		"awareness": p["awareness"] = clampi(p.get("awareness", 0) + amount, 0, 100)


## ProductManagerノードを安全に取得（シーンツリーにない場合はnullを返す）
func _get_product_manager():
	var tree = Engine.get_main_loop()
	if tree == null:
		return null
	var root = tree.root
	if root == null:
		return null
	return root.get_node_or_null("/root/Main/Game/ProductManager")


func apply_action(action: String) -> String:
	var result := ""
	match action:
		"develop":
			var eng_bonus := TeamManager.get_skill_bonus("engineer")
			var design_bonus := TeamManager.get_skill_bonus("designer")
			var gain = randi_range(3, 8) + team_size + eng_bonus
			if team_morale > 60:
				gain += 3
			# クリエイティブ性格ボーナス
			var creative_bonus := TeamManager.get_total_personality_effect("product_power")
			gain = int(gain * (1.0 + creative_bonus))
			# 勤勉・リーダー気質ボーナス（生産性）
			var productivity_bonus := TeamManager.get_total_personality_effect("productivity")
			productivity_bonus += TeamManager.get_total_personality_effect("team_productivity")
			gain = int(gain * (1.0 + productivity_bonus))
			var ux_gain = gain / 2 + (gain % 2)
			var design_gain = gain / 2 + design_bonus
			add_product_stat("ux", ux_gain)
			add_product_stat("design", design_gain)
			var details := []
			if ux_gain > 0:
				details.append("UX +%d" % ux_gain)
			if design_gain > 0:
				details.append("デザイン +%d" % design_gain)
			if team_morale > 60:
				details.append("(高士気ボーナス!)")
			result = "🔨 開発に集中！ → %s" % " / ".join(details)
		"marketing":
			# マーケティングはポップアップ経由で処理（game.gdから直接呼ばれない）
			result = "マーケティングチャネルを選択してください。"
		"fundraise":
			var amount = randi_range(500, 2000) * reputation / 30
			cash += amount
			reputation -= randi_range(5, 15)
			reputation = maxi(reputation, 0)
			result = "資金調達成功！%d万円を獲得（評判ダウン）" % amount
		"team_care":
			var gain = randi_range(10, 20)
			var old_morale = team_morale
			team_morale = mini(team_morale + gain, 100)
			var actual_gain = team_morale - old_morale
			result = "❤️ チームケアを実施！ → 士気 %d → %d (+%d)" % [old_morale, team_morale, actual_gain]

	return result
