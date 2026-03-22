class_name TeamMember
extends Resource
## チームメンバーのデータモデル

@export var member_name: String = ""
@export var skill_type: String = "engineer"  # engineer, designer, marketer, bizdev, pm
@export var skill_level: int = 1  # 1-5
@export var personality: String = "diligent"  # diligent, creative, mood_maker, analytical, leader
@export var role: String = "member"  # member, leader, manager, cxo
@export var salary: int = 0  # 年収（万円）
@export var months_employed: int = 0  # 在籍月数
@export var stamina: float = 100.0  # 体力 (0-100)
@export var avatar_id: int = 0  # アバター識別用ID (1-70)
@export var experience: int = 0  # 累計経験値
@export var training: String = ""  # 訓練中なら訓練ID（空なら通常勤務）
@export var training_remaining: int = 0  # 訓練の不在残りターン数
@export var turnover_risk: float = 0.0  # 転職リスク (0.0〜1.0)
@export var exp_multiplier: float = 1.0  # 経験値倍率（熊遭遇等の一時バフ用）
var is_at_office: bool = false
var work_state: String = "idle"  # idle, working, resting, left

# スキルタイプ別ベース給与（万円）
const BASE_SALARY := {
	"engineer": 400,
	"designer": 350,
	"marketer": 350,
	"bizdev": 400,
	"pm": 450,
}

# ロール別倍率（スキルボーナス計算用）
const ROLE_MULTIPLIER := {
	"member": 1.0,
	"leader": 1.5,
	"manager": 2.0,
	"cxo": 3.0,
}

# パーソナリティ効果の定義
# diligent（勤勉）: +10% productivity
# creative（クリエイティブ）: +15% product_power gain
# mood_maker（ムードメーカー）: +5 team morale per turn
# analytical（分析的）: +10% reputation gain
# leader（リーダー気質）: +5% team-wide productivity (stacks)
const PERSONALITY_EFFECTS := {
	"diligent": {"type": "productivity", "value": 0.10},
	"creative": {"type": "product_power", "value": 0.15},
	"mood_maker": {"type": "morale", "value": 5},
	"analytical": {"type": "reputation", "value": 0.10},
	"leader": {"type": "team_productivity", "value": 0.05},
}


# レベルアップ経験値テーブル（必要累計経験値）
const EXP_TABLE := {
	2: 100,
	3: 350,
	4: 850,
	5: 1850,
}


## 経験値を加算し、レベルアップしたかを返す
func add_experience(amount: int) -> bool:
	var adjusted := int(amount * exp_multiplier)
	experience += adjusted
	if skill_level >= 5:
		return false
	var next_level := skill_level + 1
	var required: int = EXP_TABLE.get(next_level, 99999)
	if experience >= required:
		skill_level = next_level
		calculate_salary()
		return true
	return false


## 訓練中かどうか（不在中）
func is_in_training() -> bool:
	return training != "" and training_remaining > 0


## 1時間の作業で体力を消費する
func work_one_hour() -> float:
	if stamina <= 0:
		work_state = "left"
		is_at_office = false
		return 0.0
	var drain = 5.0 + (skill_level * 0.5)  # 高レベルほどスタミナ消費が多い
	stamina = maxf(stamina - drain, 0.0)
	if stamina <= 0:
		work_state = "left"
		is_at_office = false
	return skill_level * ROLE_MULTIPLIER.get(role, 1.0)  # 生産性を返す


## 出社処理
func arrive_at_office() -> void:
	is_at_office = true
	work_state = "working"


## 退社処理
func leave_office() -> void:
	is_at_office = false
	work_state = "left"


## 翌日の回復（自宅で休息）
func rest_overnight() -> void:
	stamina = minf(stamina + 40.0, 100.0)
	work_state = "idle"


## 完全回復（休日）
func rest_full() -> void:
	stamina = 100.0
	work_state = "idle"


## 給与を計算してセットする
func calculate_salary() -> void:
	var base: int = BASE_SALARY.get(skill_type, 400)
	salary = base + skill_level * 100


## 月間コスト（万円）
func get_monthly_cost() -> int:
	return salary / 12


## パーソナリティ効果を取得
static func get_personality_effect(personality_key: String) -> Dictionary:
	return PERSONALITY_EFFECTS.get(personality_key, {})


## パーソナリティの日本語名を取得
static func get_personality_label(personality_key: String) -> String:
	match personality_key:
		"diligent":
			return "勤勉"
		"creative":
			return "クリエイティブ"
		"mood_maker":
			return "ムードメーカー"
		"analytical":
			return "分析的"
		"leader":
			return "リーダー気質"
		_:
			return personality_key


## スキルタイプの日本語名を取得
static func get_skill_label(skill: String) -> String:
	match skill:
		"engineer":
			return "エンジニア"
		"designer":
			return "デザイナー"
		"marketer":
			return "マーケター"
		"bizdev":
			return "ビズデブ"
		"pm":
			return "PM"
		_:
			return skill


## ロールの日本語名を取得
static func get_role_label(role_key: String) -> String:
	match role_key:
		"member":
			return "メンバー"
		"leader":
			return "リーダー"
		"manager":
			return "マネージャー"
		"cxo":
			return "CxO"
		_:
			return role_key


## 挨拶メッセージを取得（採用時に表示）
static func get_greeting(member_name: String, skill: String, personality_key: String) -> String:
	var skill_greetings := {
		"engineer": [
			"コード書くの大好きです！よろしくお願いします！",
			"技術で会社を支えます。一緒に良いプロダクト作りましょう！",
			"前職ではバックエンドを担当してました。頑張ります！",
			"最新の技術スタック、キャッチアップ済みです！",
		],
		"designer": [
			"ユーザー体験を最高にします！よろしくです！",
			"UIもUXもお任せください！ワクワクしてます！",
			"美しいデザインで世界を変えたいです！",
			"ピクセル単位でこだわるタイプです。期待してください！",
		],
		"marketer": [
			"この会社のファンを増やしますよ！よろしく！",
			"前職でDAU10万人まで伸ばした実績あります！",
			"SNSもSEOもお任せを。バズらせます！",
			"数字で語るマーケター目指してます！",
		],
		"bizdev": [
			"事業を大きくするのが得意です！よろしくお願いします！",
			"パートナーシップで売上倍増させますよ！",
			"営業畑出身です。数字にはこだわります！",
			"新規事業の種、たくさん持ってきました！",
		],
		"pm": [
			"プロジェクト、しっかり回します！よろしく！",
			"チームが最高のパフォーマンスを出せるよう頑張ります！",
			"スケジュール管理はお任せください！",
			"ユーザーの声を開発に届ける橋渡し役、やります！",
		],
	}
	var personality_additions := {
		"diligent": "コツコツ頑張るのが信条です。",
		"creative": "面白いアイデア、たくさん出しますね！",
		"mood_maker": "職場を明るくしますよ〜！",
		"analytical": "データに基づいて判断するタイプです。",
		"leader": "チームを引っ張っていきます！",
	}
	var greetings: Array = skill_greetings.get(skill, ["よろしくお願いします！"])
	var greeting: String = greetings[randi() % greetings.size()]
	var addition: String = personality_additions.get(personality_key, "")
	if addition != "" and randf() < 0.5:
		greeting += "\n" + addition
	return greeting


## CxOタイトルをスキルタイプから取得
static func get_cxo_title(skill: String) -> String:
	match skill:
		"engineer":
			return "CTO"
		"designer":
			return "CDO"
		"marketer":
			return "CMO"
		"bizdev":
			return "COO"
		"pm":
			return "CPO"
		_:
			return "CxO"
