extends Node
## 投資家・ステークホルダー管理

signal board_meeting_triggered(meeting_data: Dictionary)
signal mentor_met(mentor_data: Dictionary)
signal investor_mood_changed(investor_id: String, mood: String)

# 投資家キャラクター定義
const INVESTORS := {
	"angel_tanaka": {
		"name": "田中 誠一", "type": "angel", "icon": "👼",
		"description": "元起業家。シード期のスタートアップを応援する個人投資家。",
		"min_phase": 0, "max_phase": 1,
		"investment_range": [300, 1000],
		"kpi_focus": "product_power",
		"kpi_threshold": 30,
		"personality": "supportive",  # supportive, strict, visionary
	},
	"vc_suzuki": {
		"name": "鈴木 恵子", "type": "vc", "icon": "🏦",
		"description": "大手VCのパートナー。成長ステージに強い。",
		"min_phase": 1, "max_phase": 3,
		"investment_range": [2000, 8000],
		"kpi_focus": "users",
		"kpi_threshold": 3000,
		"personality": "strict",
	},
	"vc_yamamoto": {
		"name": "山本 龍太郎", "type": "vc", "icon": "🦅",
		"description": "アグレッシブな投資スタイルで知られるVC。",
		"min_phase": 2, "max_phase": 4,
		"investment_range": [5000, 20000],
		"kpi_focus": "revenue",
		"kpi_threshold": 500,
		"personality": "strict",
	},
	"cvc_mega": {
		"name": "メガコープ・ベンチャーズ", "type": "cvc", "icon": "🏢",
		"description": "大企業のCVC。事業シナジーを重視する。",
		"min_phase": 2, "max_phase": 4,
		"investment_range": [3000, 15000],
		"kpi_focus": "brand_value",
		"kpi_threshold": 40,
		"personality": "visionary",
	},
}

# メンター/アドバイザー定義
const MENTORS := {
	"mentor_tech": {
		"name": "佐藤 博士", "icon": "🧑‍🔬",
		"description": "テック業界の大御所。技術的な知見が深い。",
		"condition_type": "product_power", "condition_value": 50,
		"buff_type": "product_power", "buff_value": 5,
		"advice": "技術は手段であり目的ではない。ユーザーの課題に集中しなさい。",
	},
	"mentor_biz": {
		"name": "高橋 美穂", "icon": "👩‍💼",
		"description": "連続起業家。3社をイグジットさせた経歴を持つ。",
		"condition_type": "reputation", "condition_value": 40,
		"buff_type": "reputation", "buff_value": 10,
		"advice": "スピードが全て。完璧を求めるな、まず市場に出せ。",
	},
	"mentor_hr": {
		"name": "中村 大輔", "icon": "🤝",
		"description": "HR領域のスペシャリスト。組織づくりの達人。",
		"condition_type": "team_size", "condition_value": 10,
		"buff_type": "team_morale", "buff_value": 15,
		"advice": "人が全てだ。採用に妥協するな。文化を守れ。",
	},
}

var active_investors: Array[String] = []  # 出資済み投資家ID
var met_mentors: Array[String] = []       # 出会ったメンターID
var active_mentors: Array[String] = []    # アドバイザー契約中メンターID
var board_meeting_cooldown: int = 0       # ボード会議クールダウン
var investor_moods: Dictionary = {}       # investor_id -> "happy"/"neutral"/"unhappy"


## 毎月の処理
func advance_month(gs) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# ボード会議クールダウン
	if board_meeting_cooldown > 0:
		board_meeting_cooldown -= 1

	# 投資家の気分更新
	for inv_id in active_investors:
		_update_investor_mood(inv_id, gs)

	# ボード会議判定（3ヶ月ごと、投資家がいる場合）
	if active_investors.size() > 0 and board_meeting_cooldown <= 0 and gs.month > 0 and gs.month % 3 == 0:
		var meeting = _generate_board_meeting(gs)
		if not meeting.is_empty():
			results.append({"type": "board_meeting", "data": meeting})
			board_meeting_cooldown = 3

	# メンター出会い判定
	for mentor_id in MENTORS:
		if mentor_id in met_mentors:
			continue
		var mentor = MENTORS[mentor_id]
		var condition_val = gs.get(mentor["condition_type"])
		if condition_val != null and condition_val >= mentor["condition_value"]:
			if randf() < 0.3:
				met_mentors.append(mentor_id)
				results.append({"type": "mentor_met", "data": mentor.duplicate()})
				results[-1]["data"]["id"] = mentor_id

	# アクティブメンターのバフ適用
	for mentor_id in active_mentors:
		if MENTORS.has(mentor_id):
			var mentor = MENTORS[mentor_id]
			var buff_type = mentor["buff_type"]
			var buff_val = mentor["buff_value"]
			var current = gs.get(buff_type)
			if current != null:
				gs.set(buff_type, mini(current + buff_val, 100))

	return results


## 投資家が出資可能か判定
func get_available_investors(gs) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for inv_id in INVESTORS:
		if inv_id in active_investors:
			continue
		var inv = INVESTORS[inv_id]
		if gs.current_phase >= inv["min_phase"] and gs.current_phase <= inv["max_phase"]:
			var data = inv.duplicate()
			data["id"] = inv_id
			result.append(data)
	return result


## 投資を受ける
func accept_investment(investor_id: String, gs) -> String:
	if not INVESTORS.has(investor_id) or investor_id in active_investors:
		return ""
	var inv = INVESTORS[investor_id]
	var amount = randi_range(inv["investment_range"][0], inv["investment_range"][1])
	gs.cash += amount
	gs.total_raised += amount
	gs.fundraise_count += 1
	active_investors.append(investor_id)
	investor_moods[investor_id] = "happy"
	return "%s %sから%d万円の出資を受けた！" % [inv["icon"], inv["name"], amount]


## メンターをアドバイザーに迎える
func hire_mentor(mentor_id: String) -> String:
	if not MENTORS.has(mentor_id) or mentor_id in active_mentors:
		return ""
	active_mentors.append(mentor_id)
	var mentor = MENTORS[mentor_id]
	return "%s %sがアドバイザーに就任！「%s」" % [mentor["icon"], mentor["name"], mentor["advice"]]


## 投資家の気分を更新
func _update_investor_mood(investor_id: String, gs) -> void:
	if not INVESTORS.has(investor_id):
		return
	var inv = INVESTORS[investor_id]
	var kpi_type = inv["kpi_focus"]
	var kpi_val = gs.get(kpi_type)
	if kpi_val == null:
		return
	var threshold = inv["kpi_threshold"]
	var old_mood = investor_moods.get(investor_id, "neutral")
	var new_mood: String
	if kpi_val >= threshold * 1.5:
		new_mood = "happy"
	elif kpi_val >= threshold:
		new_mood = "neutral"
	else:
		new_mood = "unhappy"
	if new_mood != old_mood:
		investor_moods[investor_id] = new_mood
		investor_mood_changed.emit(investor_id, new_mood)


## ボード会議イベント生成
func _generate_board_meeting(gs) -> Dictionary:
	var unhappy_count := 0
	var messages: Array[String] = []
	for inv_id in active_investors:
		var mood = investor_moods.get(inv_id, "neutral")
		var inv = INVESTORS.get(inv_id, {})
		var name_str = inv.get("name", "投資家")
		if mood == "unhappy":
			unhappy_count += 1
			messages.append("😠 %s: KPI未達です。改善を求めます。" % name_str)
		elif mood == "happy":
			messages.append("😊 %s: 素晴らしい成長です。引き続き期待しています。" % name_str)
		else:
			messages.append("😐 %s: まずまずですね。さらなる成長を。" % name_str)

	return {
		"title": "📋 ボード会議",
		"messages": messages,
		"pressure": unhappy_count,
		"morale_effect": -5 * unhappy_count + 3 * (active_investors.size() - unhappy_count),
	}


## リセット
func reset() -> void:
	active_investors.clear()
	met_mentors.clear()
	active_mentors.clear()
	board_meeting_cooldown = 0
	investor_moods.clear()


## セーブ用
func to_dict() -> Dictionary:
	return {
		"active_investors": active_investors.duplicate(),
		"met_mentors": met_mentors.duplicate(),
		"active_mentors": active_mentors.duplicate(),
		"board_meeting_cooldown": board_meeting_cooldown,
		"investor_moods": investor_moods.duplicate(),
	}


## ロード用
func from_dict(data: Dictionary) -> void:
	active_investors.clear()
	for i in data.get("active_investors", []):
		active_investors.append(i)
	met_mentors.clear()
	for m in data.get("met_mentors", []):
		met_mentors.append(m)
	active_mentors.clear()
	for m in data.get("active_mentors", []):
		active_mentors.append(m)
	board_meeting_cooldown = data.get("board_meeting_cooldown", 0)
	investor_moods = data.get("investor_moods", {})
