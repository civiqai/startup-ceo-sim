class_name TrainingData
extends RefCounted
## 訓練メニューのマスターデータ定義

# 訓練タイプ: individual（個人訓練）/ team（チームイベント）
# absent_turns: 不在ターン数（0なら即時効果）

const TRAININGS := {
	# --- 個人訓練 ---
	"online_course": {
		"name": "オンライン講座",
		"cost": 10,
		"absent_turns": 0,
		"exp": 30,
		"morale": 0,
		"turnover_delta": 0.0,
		"target": "individual",
		"min_phase": 0,
		"icon": "💻",
		"description": "安全だけど地味。仕事しながら受講可能。",
	},
	"study_group": {
		"name": "勉強会参加",
		"cost": 20,
		"absent_turns": 0,
		"exp": 60,
		"morale": 0,
		"turnover_delta": 0.05,
		"target": "individual",
		"min_phase": 1,
		"icon": "📚",
		"description": "他社エンジニアと交流。転職リスク微増。",
	},
	"mountain_retreat": {
		"name": "山籠もり修行",
		"cost": 30,
		"absent_turns": 1,
		"exp": 100,
		"morale": -5,
		"turnover_delta": 0.0,
		"target": "individual",
		"min_phase": 1,
		"icon": "🏔️",
		"description": "1ターン不在。10%で覚醒、5%で熊に遭遇。",
	},
	"dev_camp": {
		"name": "開発合宿",
		"cost": 50,
		"absent_turns": 1,
		"exp": 80,
		"morale": 10,
		"turnover_delta": 0.0,
		"target": "individual",
		"min_phase": 1,
		"icon": "🏕️",
		"description": "2人以上必要。50%でチーム結束。",
		"min_members": 2,
	},
	"overseas_conference": {
		"name": "海外カンファレンス",
		"cost": 100,
		"absent_turns": 1,
		"exp": 150,
		"morale": 5,
		"turnover_delta": 0.10,
		"target": "individual",
		"min_phase": 2,
		"icon": "✈️",
		"description": "高コスト高リターン。30%で人脈獲得。転職リスク大。",
	},
	"hell_training": {
		"name": "地獄の新人研修",
		"cost": 20,
		"absent_turns": 1,
		"exp": 80,
		"morale": -15,
		"turnover_delta": 0.0,
		"target": "individual",
		"min_phase": 1,
		"icon": "🔥",
		"description": "10%で脱走（退職）、15%で覚醒。ハイリスク。",
	},
	# --- チームイベント ---
	"lt_meetup": {
		"name": "社内LT大会",
		"cost": 30,
		"absent_turns": 0,
		"exp": 40,
		"morale": 10,
		"turnover_delta": 0.0,
		"target": "team",
		"min_phase": 0,
		"icon": "🎤",
		"description": "気軽にできる全体育成。全員に効果。",
	},
	"company_conference": {
		"name": "自社カンファレンス開催",
		"cost": 500,
		"absent_turns": 1,
		"exp": 40,
		"speaker_exp": 120,
		"morale": 15,
		"turnover_delta": 0.03,
		"target": "team",
		"min_phase": 2,
		"icon": "🏛️",
		"description": "登壇者は経験値大。reputation+8。超高コスト。",
		"reputation_bonus": 8,
		"brand_bonus": 5,
	},
	"hackathon": {
		"name": "ハッカソン開催",
		"cost": 200,
		"absent_turns": 0,
		"exp": 60,
		"morale": -5,
		"turnover_delta": 0.0,
		"target": "team",
		"min_phase": 1,
		"icon": "⚡",
		"description": "全員参加。20%で新プロダクトアイデア発見。",
	},
}

# 特殊イベント定義（訓練IDごとの確率テーブル）
const SPECIAL_EVENTS := {
	"mountain_retreat": [
		{"name": "覚醒", "probability": 0.10, "message": "滝に打たれながらコードの真髄を悟った！", "effect": "skill_level_up"},
		{"name": "熊に遭遇", "probability": 0.05, "message": "熊と戦って生き延びた！逆境に強くなった", "effect": "bear_encounter"},
	],
	"hell_training": [
		{"name": "脱走", "probability": 0.10, "message": "%sは夜中に荷物をまとめて逃げ出した…", "effect": "desertion"},
		{"name": "覚醒", "probability": 0.15, "message": "地獄を乗り越えた%sの目は輝いていた", "effect": "personality_diligent"},
	],
	"overseas_conference": [
		{"name": "人脈獲得", "probability": 0.30, "message": "%sが海外VCとコネクションを作った！", "effect": "reputation_up"},
	],
	"dev_camp": [
		{"name": "チーム結束", "probability": 0.50, "message": "合宿を通じてチームの絆が深まった！", "effect": "team_bond"},
	],
	"hackathon": [
		{"name": "アイデア発見", "probability": 0.20, "message": "徹夜のテンションで画期的なアイデアが生まれた！", "effect": "product_idea"},
	],
	"company_conference": [
		{"name": "メディア掲載", "probability": 0.25, "message": "カンファレンスがメディアに取り上げられた！", "effect": "media_coverage"},
	],
}


## 指定フェーズで解放されている訓練一覧を返す
static func get_available_trainings(phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in TRAININGS:
		var t: Dictionary = TRAININGS[id].duplicate()
		t["id"] = id
		if t.get("min_phase", 0) <= phase:
			result.append(t)
	return result


## 個人訓練のみ取得
static func get_individual_trainings(phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in get_available_trainings(phase):
		if t.get("target", "") == "individual":
			result.append(t)
	return result


## チームイベントのみ取得
static func get_team_trainings(phase: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for t in get_available_trainings(phase):
		if t.get("target", "") == "team":
			result.append(t)
	return result


## 訓練データをIDで取得
static func get_training(id: String) -> Dictionary:
	if not TRAININGS.has(id):
		return {}
	var t: Dictionary = TRAININGS[id].duplicate()
	t["id"] = id
	return t


## 特殊イベントを抽選する（発生しなければ空Dictionaryを返す）
static func roll_special_event(training_id: String) -> Dictionary:
	if not SPECIAL_EVENTS.has(training_id):
		return {}
	var events: Array = SPECIAL_EVENTS[training_id]
	for event in events:
		if randf() < event.get("probability", 0.0):
			return event.duplicate()
	return {}
