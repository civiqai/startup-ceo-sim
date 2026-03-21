extends Node
## セーブ/ロード管理シングルトン（Autoload）
## JSON形式で3スロット + オートセーブに対応

const SAVE_DIR := "user://saves/"
const SAVE_VERSION := 1

const TeamMemberClass = preload("res://scripts/team_member.gd")

var _slots := ["slot_1", "slot_2", "slot_3", "auto_save"]


func _ready() -> void:
	# セーブディレクトリを作成
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## 全スロット名を返す
func get_all_slots() -> Array:
	return _slots.duplicate()


## 指定スロットにセーブファイルが存在するか
func has_save(slot: String) -> bool:
	return FileAccess.file_exists(_get_path(slot))


## セーブデータの概要を返す（ロードせずに）
## 存在しない場合は空のDictionaryを返す
func get_save_info(slot: String) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_get_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"month": data.get("month", 0),
		"cash": data.get("cash", 0),
		"team_size": data.get("members", []).size() + 1,  # +1 は社長分
		"timestamp": data.get("timestamp", ""),
	}


## ゲームをセーブする
func save_game(slot: String) -> bool:
	var data := _serialize()
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(_get_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: セーブファイルを開けませんでした: %s" % _get_path(slot))
		return false
	file.store_string(json_text)
	file.close()
	return true


## ゲームをロードする
func load_game(slot: String) -> bool:
	if not has_save(slot):
		push_error("SaveManager: セーブファイルが見つかりません: %s" % slot)
		return false
	var file := FileAccess.open(_get_path(slot), FileAccess.READ)
	if file == null:
		push_error("SaveManager: セーブファイルを開けませんでした: %s" % _get_path(slot))
		return false
	var json_text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_error("SaveManager: JSONパースに失敗しました: %s" % slot)
		return false
	var data: Dictionary = json.data
	return _deserialize(data)


## オートセーブ
func auto_save() -> bool:
	return save_game("auto_save")


## セーブデータを削除する
func delete_save(slot: String) -> bool:
	if not has_save(slot):
		return false
	var err := DirAccess.remove_absolute(_get_path(slot))
	return err == OK


## スロット名からファイルパスを取得
func _get_path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"


## GameState + TeamManagerをDictionaryにシリアライズ
func _serialize() -> Dictionary:
	var members_data: Array = []
	for m in TeamManager.members:
		members_data.append({
			"member_name": m.member_name,
			"skill_type": m.skill_type,
			"skill_level": m.skill_level,
			"personality": m.personality,
			"role": m.role,
			"salary": m.salary,
			"months_employed": m.months_employed,
		})

	var now := Time.get_datetime_dict_from_system()
	var timestamp := "%04d-%02d-%02dT%02d:%02d:%02d" % [
		now["year"], now["month"], now["day"],
		now["hour"], now["minute"], now["second"],
	]

	# ProductManagerのセーブデータを取得
	var pm = GameState._get_product_manager()
	var product_data := {}
	if pm:
		product_data = pm.to_dict()

	return {
		"version": SAVE_VERSION,
		"timestamp": timestamp,
		"month": GameState.month,
		"cash": GameState.cash,
		"team_morale": GameState.team_morale,
		"users": GameState.users,
		"reputation": GameState.reputation,
		"brand_value": GameState.brand_value,
		"fundraise_cooldown": GameState.fundraise_cooldown,
		"total_raised": GameState.total_raised,
		"fundraise_count": GameState.fundraise_count,
		"equity_share": GameState.equity_share,
		"contract_work_remaining": GameState.contract_work_remaining,
		"contract_work_name": GameState.contract_work_name,
		"contract_work_reward": GameState.contract_work_reward,
		"tutorial_month": GameState.tutorial_month,
		"members": members_data,
		"product_manager": product_data,
	}


## DictionaryからGameState + TeamManagerを復元
func _deserialize(data: Dictionary) -> bool:
	# GameStateの復元
	GameState.month = int(data.get("month", 0))
	GameState.cash = int(data.get("cash", 1000))
	GameState.team_morale = int(data.get("team_morale", 70))
	GameState.users = int(data.get("users", 0))
	GameState.reputation = int(data.get("reputation", 30))
	GameState.brand_value = int(data.get("brand_value", 0))
	GameState.fundraise_cooldown = int(data.get("fundraise_cooldown", 0))
	GameState.total_raised = int(data.get("total_raised", 0))
	GameState.fundraise_count = int(data.get("fundraise_count", 0))
	GameState.equity_share = float(data.get("equity_share", 100.0))
	GameState.contract_work_remaining = int(data.get("contract_work_remaining", 0))
	GameState.contract_work_name = str(data.get("contract_work_name", ""))
	GameState.contract_work_reward = int(data.get("contract_work_reward", 0))
	GameState.tutorial_month = int(data.get("tutorial_month", -1))

	# TeamManagerのメンバーを復元
	TeamManager.members.clear()
	var members_data: Array = data.get("members", [])
	for m_data in members_data:
		var member := TeamMemberClass.new()
		member.member_name = str(m_data.get("member_name", ""))
		member.skill_type = str(m_data.get("skill_type", "engineer"))
		member.skill_level = int(m_data.get("skill_level", 1))
		member.personality = str(m_data.get("personality", "diligent"))
		member.role = str(m_data.get("role", "member"))
		member.salary = int(m_data.get("salary", 0))
		member.months_employed = int(m_data.get("months_employed", 0))
		TeamManager.members.append(member)

	# ProductManagerの復元
	var pm = GameState._get_product_manager()
	if pm:
		if data.has("product_manager"):
			pm.from_dict(data["product_manager"])
		elif data.has("product_ux"):
			# 旧フォーマットからの移行: GameState直下のプロダクトパラメータをProductManagerに移す
			var active = pm.get_active_products()
			if not active.is_empty():
				var p = active[0]
				p["ux"] = int(data.get("product_ux", 5))
				p["design"] = int(data.get("product_design", 5))
				p["margin"] = int(data.get("product_margin", 0))
				p["awareness"] = int(data.get("product_awareness", 0))

	GameState.state_changed.emit()
	return true
