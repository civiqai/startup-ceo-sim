extends Node
## 難易度・モード管理

signal difficulty_changed(difficulty_id: String)

const DIFFICULTIES := {
	"easy": {
		"name": "イージー", "icon": "😊",
		"description": "初心者向け。資金と士気にボーナス。",
		"initial_cash": 2000,
		"initial_morale": 85,
		"initial_reputation": 40,
		"event_damage_multiplier": 0.6,
		"cost_multiplier": 0.8,
		"revenue_multiplier": 1.3,
	},
	"normal": {
		"name": "ノーマル", "icon": "😐",
		"description": "標準的な難易度。",
		"initial_cash": 1000,
		"initial_morale": 70,
		"initial_reputation": 30,
		"event_damage_multiplier": 1.0,
		"cost_multiplier": 1.0,
		"revenue_multiplier": 1.0,
	},
	"hard": {
		"name": "ハード", "icon": "😤",
		"description": "経験者向け。イベントダメージ増加。",
		"initial_cash": 700,
		"initial_morale": 60,
		"initial_reputation": 20,
		"event_damage_multiplier": 1.4,
		"cost_multiplier": 1.2,
		"revenue_multiplier": 0.8,
	},
	"lunatic": {
		"name": "ルナティック", "icon": "💀",
		"description": "最高難易度。生き残れるか。",
		"initial_cash": 500,
		"initial_morale": 50,
		"initial_reputation": 10,
		"event_damage_multiplier": 2.0,
		"cost_multiplier": 1.5,
		"revenue_multiplier": 0.6,
	},
}

const CHALLENGES := {
	"no_fundraise": {
		"name": "資金調達禁止", "icon": "🚫💵",
		"description": "資金調達なしで生き残れ",
		"rule": "fundraise_disabled",
	},
	"solo": {
		"name": "ぼっち社長", "icon": "🧑‍💻",
		"description": "採用禁止。一人で戦え。",
		"rule": "hire_disabled",
	},
	"speed_run": {
		"name": "スピードラン", "icon": "⏱️",
		"description": "12ヶ月以内にIPOせよ",
		"rule": "time_limit_12",
	},
	"debt_hell": {
		"name": "借金地獄", "icon": "📉",
		"description": "初期資金-500万（借金スタート）",
		"rule": "negative_start",
	},
}

var current_difficulty: String = "normal"
var active_challenge: String = ""  # 空ならチャレンジなし
var daily_seed: int = 0


func get_difficulty_data() -> Dictionary:
	return DIFFICULTIES.get(current_difficulty, DIFFICULTIES["normal"])


func set_difficulty(difficulty_id: String) -> void:
	if DIFFICULTIES.has(difficulty_id):
		current_difficulty = difficulty_id
		difficulty_changed.emit(difficulty_id)


func set_challenge(challenge_id: String) -> void:
	if CHALLENGES.has(challenge_id) or challenge_id == "":
		active_challenge = challenge_id


## チャレンジのルールを取得
func get_active_rule() -> String:
	if active_challenge == "":
		return ""
	return CHALLENGES.get(active_challenge, {}).get("rule", "")


## アクションが許可されているか
func is_action_allowed(action: String) -> bool:
	var rule = get_active_rule()
	if rule == "fundraise_disabled" and action == "fundraise":
		return false
	if rule == "hire_disabled" and action == "hire":
		return false
	return true


## 難易度に基づく初期パラメータをGameStateに適用
func apply_initial_params(gs) -> void:
	var data = get_difficulty_data()
	gs.cash = data.get("initial_cash", 1000)
	gs.team_morale = data.get("initial_morale", 70)
	gs.reputation = data.get("initial_reputation", 30)

	# チャレンジ特殊処理
	var rule = get_active_rule()
	if rule == "negative_start":
		gs.cash = -500  # 借金スタート

	# デイリーチャレンジ用シード
	if daily_seed > 0:
		seed(daily_seed)


## デイリーチャレンジのシードを生成（日付ベース）
func setup_daily_challenge() -> void:
	var date = Time.get_date_dict_from_system()
	daily_seed = date["year"] * 10000 + date["month"] * 100 + date["day"]
	active_challenge = ""
	current_difficulty = "normal"


## タイムリミットチェック（スピードランチャレンジ）
func check_time_limit(gs) -> bool:
	if get_active_rule() == "time_limit_12" and gs.month >= 12:
		return true
	return false


## リセット
func reset() -> void:
	current_difficulty = "normal"
	active_challenge = ""
	daily_seed = 0
