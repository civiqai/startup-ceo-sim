extends Node
## チーム管理シングルトン（Autoload）
## メンバーの採用・解雇・昇進・スキルボーナス計算を管理する

const TeamMemberClass = preload("res://scripts/team_member.gd")

signal member_hired(member)
signal member_left(member)
signal member_promoted(member, old_role, new_role)
signal member_leveled_up(member, old_level: int, new_level: int)

var members: Array[Resource] = []

# 日本語名プール（30名以上）
const NAME_POOL: Array[String] = [
	"太郎", "花子", "翔太", "美咲", "大輝",
	"さくら", "健太", "愛", "拓海", "遥",
	"蓮", "陽菜", "悠斗", "結衣", "颯太",
	"凛", "大和", "葵", "陸", "七海",
	"樹", "真央", "海斗", "琴音", "隼人",
	"あかり", "龍之介", "柚希", "奏", "千尋",
	"春樹", "萌", "涼介", "ひなた", "響",
]

const SKILL_TYPES: Array[String] = ["engineer", "designer", "marketer", "bizdev", "pm"]
const PERSONALITIES: Array[String] = ["diligent", "creative", "mood_maker", "analytical", "leader"]
const ROLES: Array[String] = ["member", "leader", "manager", "cxo"]
## フェーズに応じたメンバー上限を返す
func get_max_members() -> int:
	var phase: int = GameState.current_phase
	match phase:
		0: return 2
		1: return 4
		2: return 6
		3: return 8
		_: return 10


## チームが上限に達しているか
func is_full() -> bool:
	return members.size() >= get_max_members()


## ランダムな候補者を生成する
func generate_candidate(min_level: int = 1, max_level: int = 3) -> Resource:
	var member := TeamMemberClass.new()
	member.member_name = _random_name()
	member.skill_type = SKILL_TYPES[randi() % SKILL_TYPES.size()]
	member.skill_level = randi_range(min_level, max_level)
	member.personality = PERSONALITIES[randi() % PERSONALITIES.size()]
	member.role = "member"
	member.months_employed = 0
	member.avatar_id = randi_range(1, 70)
	member.calculate_salary()
	return member


## メンバーを採用する
func hire(member) -> void:
	members.append(member)
	member_hired.emit(member)


## メンバーを解雇する
func fire(member) -> void:
	var idx := members.find(member)
	if idx >= 0:
		members.remove_at(idx)
		member_left.emit(member)


## メンバーを昇進させる
func promote(member, new_role: String) -> void:
	var old_role: String = member.role
	member.role = new_role
	member_promoted.emit(member, old_role, new_role)


## 全メンバーの月間コスト合計（万円）
func get_total_monthly_cost() -> int:
	var total := 0
	for m in members:
		total += m.get_monthly_cost()
	return total


## 指定スキルタイプのメンバー一覧を取得
func get_members_by_skill(skill_type: String) -> Array:
	var result: Array = []
	for m in members:
		if m.skill_type == skill_type:
			result.append(m)
	return result


## 指定スキルタイプのCxOを取得（いなければnull）
## 例: "engineer" -> CTO
func get_cxo(skill_type: String) -> Resource:
	for m in members:
		if m.skill_type == skill_type and m.role == "cxo":
			return m
	return null


## 指定スキルタイプのCxOが存在するか
func has_cxo(skill_type: String) -> bool:
	return get_cxo(skill_type) != null


## 指定スキルタイプのスキルボーナスを計算
## 各メンバーの (skill_level * role_multiplier) の合計
func get_skill_bonus(skill_type: String) -> int:
	var total := 0.0
	for m in members:
		if m.skill_type == skill_type:
			var multiplier: float = TeamMemberClass.ROLE_MULTIPLIER.get(m.role, 1.0)
			total += m.skill_level * multiplier
	return int(total)


## パーソナリティ効果の集計ヘルパー
## 指定タイプの効果値を全メンバーから合算して返す
func get_total_personality_effect(effect_type: String) -> float:
	var total := 0.0
	for m in members:
		var effect: Dictionary = TeamMemberClass.get_personality_effect(m.personality)
		if effect.get("type", "") == effect_type:
			total += effect.get("value", 0.0)
	return total


## 全メンバーを出社させる
func all_arrive() -> void:
	for m in members:
		if m.is_in_training():
			continue  # 訓練中は出社しない
		if m.stamina > 10.0:  # 体力10以下は欠勤
			m.arrive_at_office()


## 全メンバーを退社させる
func all_leave() -> void:
	for m in members:
		m.leave_office()


## 全メンバーの夜間回復
func all_rest_overnight() -> void:
	for m in members:
		m.rest_overnight()


## 全メンバーの完全回復（休日）
func all_rest_full() -> void:
	for m in members:
		m.rest_full()


## 出社中のメンバー一覧
func get_office_members() -> Array:
	var result: Array = []
	for m in members:
		if m.is_at_office:
			result.append(m)
	return result


## 全メンバーの1時間の作業を実行し、スキルタイプ別の生産性合計を返す
func work_all_one_hour() -> Dictionary:
	var productivity := {}
	for skill in SKILL_TYPES:
		productivity[skill] = 0.0
	for m in members:
		if m.is_at_office and m.work_state == "working":
			var output = m.work_one_hour()
			productivity[m.skill_type] += output
	return productivity


## ランダムな日本語名を返す
func _random_name() -> String:
	return NAME_POOL[randi() % NAME_POOL.size()]
