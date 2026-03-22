extends Node

## オフィスエリア拡張管理シングルトン
## 専用ゾーン（サーバールーム、休憩室など）の購入・効果適用を管理する。
## ゾーン効果は OfficeBuffManager に "zone_<zone_id>" キーで登録される。

signal zone_purchased(zone_id: String)
signal zone_effects_changed

# ゾーン定義
const ZONES: Dictionary = {
	"server_room": {
		"name": "サーバールーム",
		"icon": "\U0001F5A5\uFE0F",
		"description": "専用サーバールームを設置。インフラ安定性が大幅に向上する。",
		"cost": 200,
		"required_phase": 2,
		"effects": {"incident_reduction": 15, "product_power": 2},
		"size_bonus": Vector2i(4, 3),
	},
	"break_room": {
		"name": "休憩室",
		"icon": "\u2615",
		"description": "くつろげる休憩スペース。チームの士気が常時向上。",
		"cost": 150,
		"required_phase": 1,
		"effects": {"team_morale": 5},
		"size_bonus": Vector2i(3, 3),
	},
	"meeting_room": {
		"name": "会議室",
		"icon": "\U0001F91D",
		"description": "専用の会議室。投資家ミーティングや社内会議がスムーズに。",
		"cost": 180,
		"required_phase": 2,
		"effects": {"reputation": 4, "marketing_bonus": 2},
		"size_bonus": Vector2i(4, 3),
	},
	"gym": {
		"name": "社内ジム",
		"icon": "\U0001F4AA",
		"description": "ミニジムを設置。チームの健康とモチベーションが向上。",
		"cost": 300,
		"required_phase": 3,
		"effects": {"team_morale": 8, "incident_reduction": 5},
		"size_bonus": Vector2i(4, 4),
	},
	"rooftop": {
		"name": "屋上テラス",
		"icon": "\U0001F33F",
		"description": "屋上にテラスを設置。リラックスできる空間で創造性が向上。",
		"cost": 500,
		"required_phase": 4,
		"effects": {"team_morale": 10, "product_power": 3, "reputation": 3},
		"size_bonus": Vector2i(6, 4),
	},
}

# 購入済みゾーンIDリスト
var _purchased_zones: Array[String] = []

# 全ゾーン効果の合計キャッシュ
var _total_zone_effects: Dictionary = {}


func _ready() -> void:
	_recalculate_effects()


# --- 購入判定 ---

## ゾーンが購入可能か（フェーズ条件 + 資金 + 未購入）
func can_purchase_zone(zone_id: String) -> bool:
	if not ZONES.has(zone_id):
		return false
	if is_zone_purchased(zone_id):
		return false
	var zone: Dictionary = ZONES[zone_id]
	var required_phase: int = zone.get("required_phase", 0)
	var cost: int = zone.get("cost", 0)
	if GameState.current_phase < required_phase:
		return false
	if GameState.cash < cost:
		return false
	return true


## ゾーンを購入する。成功時 true を返す。
func purchase_zone(zone_id: String) -> bool:
	if not can_purchase_zone(zone_id):
		return false

	var zone: Dictionary = ZONES[zone_id]
	var cost: int = zone.get("cost", 0)

	# 資金を減らす
	GameState.cash -= cost

	# 購入済みに追加
	_purchased_zones.append(zone_id)

	# 効果を適用
	apply_zone_effects()

	zone_purchased.emit(zone_id)
	zone_effects_changed.emit()

	return true


# --- データ参照 ---

## ゾーン定義を取得
func get_zone(zone_id: String) -> Dictionary:
	if ZONES.has(zone_id):
		return ZONES[zone_id].duplicate(true)
	return {}


## 指定フェーズで利用可能なゾーン一覧（購入済み含む）
func get_available_zones(phase: int) -> Array:
	var result: Array = []
	for zone_id in ZONES:
		var zone: Dictionary = ZONES[zone_id]
		if zone.get("required_phase", 0) <= phase:
			result.append(zone_id)
	return result


## 購入済みゾーンIDリスト
func get_purchased_zones() -> Array[String]:
	return _purchased_zones.duplicate()


## ゾーンが購入済みか
func is_zone_purchased(zone_id: String) -> bool:
	return zone_id in _purchased_zones


## 全購入済みゾーンの size_bonus 合計
func get_total_size_bonus() -> Vector2i:
	var total := Vector2i.ZERO
	for zone_id in _purchased_zones:
		if ZONES.has(zone_id):
			var bonus: Vector2i = ZONES[zone_id].get("size_bonus", Vector2i.ZERO)
			total += bonus
	return total


## 全ゾーン効果の合計を取得
func get_total_effects() -> Dictionary:
	return _total_zone_effects.duplicate()


# --- 効果適用 ---

## 購入済み全ゾーンの効果を OfficeBuffManager に登録する
func apply_zone_effects() -> void:
	# 先に既存のゾーンバフを全て削除
	for zone_id in ZONES:
		var buff_key := "zone_%s" % zone_id
		OfficeBuffManager.remove_furniture_buff(buff_key)

	# 購入済みゾーンの効果を登録
	for zone_id in _purchased_zones:
		if ZONES.has(zone_id):
			var effects: Dictionary = ZONES[zone_id].get("effects", {})
			if not effects.is_empty():
				var buff_key := "zone_%s" % zone_id
				OfficeBuffManager.add_furniture_buff(buff_key, effects)

	_recalculate_effects()


## 効果合計を再計算（内部キャッシュ更新）
func _recalculate_effects() -> void:
	_total_zone_effects.clear()
	for zone_id in _purchased_zones:
		if ZONES.has(zone_id):
			var effects: Dictionary = ZONES[zone_id].get("effects", {})
			for effect_type in effects:
				if _total_zone_effects.has(effect_type):
					_total_zone_effects[effect_type] += effects[effect_type]
				else:
					_total_zone_effects[effect_type] = effects[effect_type]


# --- シリアライズ ---

## セーブ用にシリアライズ
func serialize() -> Dictionary:
	return {
		"purchased_zones": _purchased_zones.duplicate(),
	}


## セーブデータから復元
func deserialize(data: Dictionary) -> void:
	_purchased_zones.clear()
	var zones_data: Array = data.get("purchased_zones", [])
	for zone_id in zones_data:
		if zone_id is String and ZONES.has(zone_id):
			_purchased_zones.append(zone_id)

	# 効果を再適用
	apply_zone_effects()
	zone_effects_changed.emit()


## リセット
func reset() -> void:
	# OfficeBuffManager からゾーンバフを全て削除
	for zone_id in ZONES:
		var buff_key := "zone_%s" % zone_id
		OfficeBuffManager.remove_furniture_buff(buff_key)

	_purchased_zones.clear()
	_total_zone_effects.clear()
	zone_effects_changed.emit()
