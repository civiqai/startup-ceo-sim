extends Node
## 実績/アチーブメント管理 — 永続的な実績とアンロック報酬

signal achievement_unlocked(achievement: Dictionary)

const ACHIEVEMENTS := {
	"first_ipo": {
		"name": "初のIPO", "icon": "👑",
		"description": "初めてIPOを達成した",
		"reward": "初期資金+500万で開始可能",
		"reward_type": "initial_cash_bonus", "reward_value": 500,
	},
	"hire_10": {
		"name": "10人採用", "icon": "👥",
		"description": "チームメンバーを10人以上採用した",
		"reward": "採用コスト10%割引",
		"reward_type": "hire_discount", "reward_value": 0.10,
	},
	"survive_fire_3": {
		"name": "炎上サバイバー", "icon": "🔥",
		"description": "炎上イベントを3回生き延びた",
		"reward": "炎上時のダメージ軽減",
		"reward_type": "fire_damage_reduce", "reward_value": 0.5,
	},
	"mrr_1000": {
		"name": "MRR1000万", "icon": "💰",
		"description": "月間売上1000万円を達成した",
		"reward": "売上ボーナス+5%",
		"reward_type": "revenue_bonus", "reward_value": 0.05,
	},
	"users_100k": {
		"name": "ユーザー10万人", "icon": "📱",
		"description": "ユーザー数10万人を突破した",
		"reward": "オーガニック成長率UP",
		"reward_type": "organic_growth", "reward_value": 1.2,
	},
	"speed_ipo": {
		"name": "スピードIPO", "icon": "⚡",
		"description": "24ヶ月以内にIPOを達成した",
		"reward": "ゲーム速度x8解放",
		"reward_type": "speed_8x", "reward_value": 8.0,
	},
	"zero_fire": {
		"name": "クリーン経営", "icon": "✨",
		"description": "炎上イベントなしでIPOを達成した",
		"reward": "初期評判+20",
		"reward_type": "initial_reputation_bonus", "reward_value": 20,
	},
	"full_team": {
		"name": "フルハウス", "icon": "🏠",
		"description": "全ロール（CTO/CMO/COO/CDO/CPO）を揃えた",
		"reward": "CxO就任コスト無料",
		"reward_type": "cxo_free", "reward_value": 1,
	},
	"debt_zero": {
		"name": "無借金経営", "icon": "🏦",
		"description": "資金調達せずにIPOを達成した",
		"reward": "初期プロダクト力+20",
		"reward_type": "initial_product_bonus", "reward_value": 20,
	},
	"market_leader": {
		"name": "マーケットリーダー", "icon": "🏆",
		"description": "市場シェア50%を獲得した",
		"reward": "競合の成長速度-20%",
		"reward_type": "competitor_slow", "reward_value": 0.8,
	},
	"mentor_all": {
		"name": "人脈王", "icon": "🤝",
		"description": "全メンターと出会った",
		"reward": "メンターバフ効果2倍",
		"reward_type": "mentor_double", "reward_value": 2.0,
	},
	"product_complete": {
		"name": "フルスタック", "icon": "🔧",
		"description": "全機能を開発完了した",
		"reward": "技術的負債の蓄積-50%",
		"reward_type": "debt_reduce", "reward_value": 0.5,
	},
}

# 永続保存パス
const SAVE_PATH := "user://achievements.json"

var unlocked: Dictionary = {}  # achievement_id -> true
var progress: Dictionary = {}  # トラッキング用カウンター
# progress keys: "fire_survived", "total_hired", "max_share"


func _ready() -> void:
	_load()


## 毎ターン末に実績チェック
func check(gs, extra: Dictionary = {}) -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []

	# 10人採用
	if not unlocked.has("hire_10") and gs.team_size >= 10:
		newly_unlocked.append(_unlock("hire_10"))

	# MRR1000万
	if not unlocked.has("mrr_1000") and gs.revenue >= 1000:
		newly_unlocked.append(_unlock("mrr_1000"))

	# ユーザー10万人
	if not unlocked.has("users_100k") and gs.users >= 100000:
		newly_unlocked.append(_unlock("users_100k"))

	# フルハウス（全CxO）
	if not unlocked.has("full_team"):
		var has_all_cxo := true
		for skill in ["engineer", "designer", "marketer", "bizdev", "pm"]:
			if not TeamManager.has_cxo(skill):
				has_all_cxo = false
				break
		if has_all_cxo:
			newly_unlocked.append(_unlock("full_team"))

	# マーケットリーダー
	var share = extra.get("market_share", 0.0)
	if not unlocked.has("market_leader") and share >= 50.0:
		newly_unlocked.append(_unlock("market_leader"))

	# 全メンター
	var met_mentors = extra.get("met_mentors_count", 0)
	if not unlocked.has("mentor_all") and met_mentors >= 3:
		newly_unlocked.append(_unlock("mentor_all"))

	# 全機能開発
	var all_features = extra.get("all_features_done", false)
	if not unlocked.has("product_complete") and all_features:
		newly_unlocked.append(_unlock("product_complete"))

	return newly_unlocked


## ゲームクリア時の実績チェック
func check_on_clear(gs, extra: Dictionary = {}) -> Array[Dictionary]:
	var newly_unlocked: Array[Dictionary] = []

	# 初のIPO
	if not unlocked.has("first_ipo"):
		newly_unlocked.append(_unlock("first_ipo"))

	# スピードIPO（24ヶ月以内）
	if not unlocked.has("speed_ipo") and gs.month <= 24:
		newly_unlocked.append(_unlock("speed_ipo"))

	# クリーン経営（炎上なし）
	var fire_count = progress.get("fire_survived", 0)
	if not unlocked.has("zero_fire") and fire_count == 0:
		newly_unlocked.append(_unlock("zero_fire"))

	# 無借金経営
	if not unlocked.has("debt_zero") and gs.fundraise_count == 0:
		newly_unlocked.append(_unlock("debt_zero"))

	return newly_unlocked


## 炎上生存カウント
func record_fire_survived() -> void:
	progress["fire_survived"] = progress.get("fire_survived", 0) + 1
	# 炎上サバイバー
	if not unlocked.has("survive_fire_3") and progress["fire_survived"] >= 3:
		_unlock("survive_fire_3")
	_save()


## アンロック処理
func _unlock(achievement_id: String) -> Dictionary:
	unlocked[achievement_id] = true
	var data = ACHIEVEMENTS.get(achievement_id, {}).duplicate()
	data["id"] = achievement_id
	achievement_unlocked.emit(data)
	_save()
	return data


## 報酬が有効か
func has_reward(reward_type: String) -> bool:
	for ach_id in unlocked:
		var ach = ACHIEVEMENTS.get(ach_id, {})
		if ach.get("reward_type", "") == reward_type:
			return true
	return false


## 報酬値を取得
func get_reward_value(reward_type: String, default: float = 0.0) -> float:
	for ach_id in unlocked:
		var ach = ACHIEVEMENTS.get(ach_id, {})
		if ach.get("reward_type", "") == reward_type:
			return ach.get("reward_value", default)
	return default


## アンロック済み実績の一覧を返す
func get_unlocked_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ach_id in unlocked:
		if ACHIEVEMENTS.has(ach_id):
			var data = ACHIEVEMENTS[ach_id].duplicate()
			data["id"] = ach_id
			result.append(data)
	return result


## 全実績の一覧（アンロック状態付き）
func get_all_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for ach_id in ACHIEVEMENTS:
		var data = ACHIEVEMENTS[ach_id].duplicate()
		data["id"] = ach_id
		data["unlocked"] = unlocked.has(ach_id)
		result.append(data)
	return result


func _save() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"unlocked": unlocked, "progress": progress}))
		file.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var data = json.data
			if data is Dictionary:
				unlocked = data.get("unlocked", {})
				progress = data.get("progress", {})
		file.close()


func reset_progress() -> void:
	progress.clear()
