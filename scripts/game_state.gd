extends Node
## ゲーム全体の状態を管理するシングルトン (Autoload)

signal state_changed
signal game_over(reason: String)
signal game_clear(reason: String)
signal emergency_fundraise_triggered(amount: int, dilution: float)
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
	{"name": "大手商社の在庫管理システム", "reward": 800, "months": 2, "eng_bonus": 3},
	{"name": "製造業向けERPカスタマイズ", "reward": 1500, "months": 3, "eng_bonus": 5},
	{"name": "地方自治体のポータルサイト", "reward": 600, "months": 2, "eng_bonus": 2},
	{"name": "医療系予約システム", "reward": 2000, "months": 4, "eng_bonus": 6},
	{"name": "物流会社の配車最適化AI", "reward": 3000, "months": 5, "eng_bonus": 8},
	{"name": "金融機関のリスク管理ツール", "reward": 2500, "months": 4, "eng_bonus": 7},
	{"name": "教育プラットフォーム構築", "reward": 1200, "months": 3, "eng_bonus": 4},
	{"name": "不動産マッチングアプリ", "reward": 1000, "months": 3, "eng_bonus": 3},
]

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
		return 50 + TeamManager.get_total_monthly_cost()

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
		var product_component = users * product_power
		var brand_component = brand_value * brand_value * 2
		var revenue_component = revenue * 120
		var reputation_component = maxi(reputation - 30, 0) * 100  # 30以下では寄与しない
		return product_component + brand_component + revenue_component + reputation_component

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
		# 緊急資金調達フォールバック: 資金調達が可能なら倒産前に救済
		var emergency_amount := _try_emergency_fundraise()
		if emergency_amount > 0:
			cash += emergency_amount
			state_changed.emit()
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


## 緊急資金調達を試みる（倒産回避フォールバック）
## エクイティ調達 → 緊急借入（高金利）の順で試行する
## 成功時は調達額を返す、不可能なら0を返す
func _try_emergency_fundraise() -> int:
	# チャレンジモードで資金調達が禁止されている場合は不可
	if DifficultyManager.is_action_allowed("fundraise") == false:
		return 0

	# 1. エクイティ調達を試みる（クールダウンなし＋持株10%超）
	if fundraise_cooldown == 0 and equity_share > 10.0 and contract_work_remaining == 0:
		var raise_amount := maxi(200, valuation / 20)
		var dilution := clampf(float(raise_amount) / maxf(float(valuation), 1000.0) * 100.0, 2.0, 15.0)
		equity_share = maxf(equity_share - dilution, 5.0)
		fundraise_cooldown = 2
		fundraise_count += 1
		total_raised += raise_amount
		emergency_fundraise_triggered.emit(raise_amount, dilution)
		return raise_amount

	# 2. 緊急借入（ファクタリング的な高金利短期借入）
	#    クールダウン中でも利用可能、借入残高が売上の12ヶ月分以下なら
	var max_borrow := maxi(500, revenue * 3)  # 月商の3倍まで
	if total_loan_balance < max_borrow:
		var borrow_amount := maxi(300, monthly_cost + abs(cash))  # 赤字を補填+α
		borrow_amount = mini(borrow_amount, max_borrow - total_loan_balance)
		# 高金利（年利20%相当）、6ヶ月返済
		add_loan("緊急ファクタリング", borrow_amount, 0.10, 6)
		emergency_fundraise_triggered.emit(borrow_amount, 0.0)
		return borrow_amount

	return 0


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
