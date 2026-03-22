extends Node
## 難易度管理（3レベル: イージー / ノーマル / ハード）

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
}

var current_difficulty: String = "normal"


func get_difficulty_data() -> Dictionary:
	return DIFFICULTIES.get(current_difficulty, DIFFICULTIES["normal"])


func set_difficulty(difficulty_id: String) -> void:
	if DIFFICULTIES.has(difficulty_id):
		current_difficulty = difficulty_id
		difficulty_changed.emit(difficulty_id)


## 難易度に基づく初期パラメータをGameStateに適用
func apply_initial_params(gs) -> void:
	var data = get_difficulty_data()
	gs.cash = data.get("initial_cash", 1000)
	gs.team_morale = data.get("initial_morale", 70)
	gs.reputation = data.get("initial_reputation", 30)


## リセット
func reset() -> void:
	current_difficulty = "normal"
