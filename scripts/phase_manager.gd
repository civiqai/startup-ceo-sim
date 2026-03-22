extends Node
## フェーズ制管理 — 会社の成長段階を管理する

signal phase_changed(old_phase: int, new_phase: int)

const PHASE_DATA := [
	{
		"id": 0, "name": "シード期", "icon": "🌱",
		"description": "アイデアを形にする段階",
		"mrr": 0, "users": 0, "team": 0, "raised": 0,
		"unlocks": ["develop", "hire", "team_care", "marketing"],
	},
	{
		"id": 1, "name": "アーリー", "icon": "🌿",
		"description": "PMFを目指してプロダクトを磨く",
		"mrr": 50, "users": 500, "team": 3, "raised": 0,
		"unlocks": [],
	},
	{
		"id": 2, "name": "シリーズA", "icon": "🚀",
		"description": "成長の加速フェーズ",
		"mrr": 200, "users": 3000, "team": 5, "raised": 3000,
		"unlocks": ["fundraise"],
	},
	{
		"id": 3, "name": "シリーズB", "icon": "📈",
		"description": "スケーリングと組織拡大",
		"mrr": 500, "users": 10000, "team": 7, "raised": 10000,
		"unlocks": [],
	},
	{
		"id": 4, "name": "プレIPO", "icon": "🏛️",
		"description": "上場準備フェーズ",
		"mrr": 2000, "users": 50000, "team": 9, "raised": 50000,
		"unlocks": [],
	},
	{
		"id": 5, "name": "IPO", "icon": "👑",
		"description": "株式公開達成！",
		"mrr": 0, "users": 0, "team": 0, "raised": 0,
		"unlocks": [],
	},
]

var current_phase: int = 0


func get_phase_data(phase_id: int = -1) -> Dictionary:
	if phase_id < 0:
		phase_id = current_phase
	if phase_id >= 0 and phase_id < PHASE_DATA.size():
		return PHASE_DATA[phase_id]
	return {}


func get_phase_name() -> String:
	var data = get_phase_data()
	return "%s %s" % [data.get("icon", ""), data.get("name", "")]


## 毎ターン末にフェーズ昇格判定
func check_phase_up(gs) -> Dictionary:
	if current_phase >= PHASE_DATA.size() - 1:
		return {}
	var next = PHASE_DATA[current_phase + 1]
	var mrr_ok = gs.revenue >= next["mrr"]
	var users_ok = gs.users >= next["users"]
	var team_ok = gs.team_size >= next["team"]
	var raised_ok = gs.total_raised >= next["raised"]
	if mrr_ok and users_ok and team_ok and raised_ok:
		var old_phase = current_phase
		current_phase += 1
		phase_changed.emit(old_phase, current_phase)
		return get_phase_data()
	return {}


## 次のフェーズまでの進捗を返す (0.0 - 1.0 per criteria)
func get_progress(gs) -> Dictionary:
	if current_phase >= PHASE_DATA.size() - 1:
		return {"mrr": 1.0, "users": 1.0, "team": 1.0, "raised": 1.0}
	var next = PHASE_DATA[current_phase + 1]
	return {
		"mrr": minf(float(gs.revenue) / maxf(next["mrr"], 1), 1.0),
		"users": minf(float(gs.users) / maxf(next["users"], 1), 1.0),
		"team": minf(float(gs.team_size) / maxf(next["team"], 1), 1.0),
		"raised": minf(float(gs.total_raised) / maxf(next["raised"], 1), 1.0),
	}


## アクションがアンロック済みか判定
func is_action_unlocked(action: String) -> bool:
	for i in range(current_phase + 1):
		if action in PHASE_DATA[i].get("unlocks", []):
			return true
	return false


## リセット
func reset() -> void:
	current_phase = 0


## セーブ用データ
func to_dict() -> Dictionary:
	return {"current_phase": current_phase}


## ロード用
func from_dict(data: Dictionary) -> void:
	current_phase = data.get("current_phase", 0)
