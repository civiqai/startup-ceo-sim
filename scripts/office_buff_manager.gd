class_name OfficeBuffManager
extends Node

## オフィス家具によるバフ/効果の計算・適用を管理するシングルトン

signal buffs_changed

# 家具ID → 効果Dictionary のマッピング
var _active_buffs: Dictionary = {}
# 全バフの合計値キャッシュ
var _total_buffs: Dictionary = {}

# 効果タイプの日本語表示名
const EFFECT_DISPLAY_NAMES: Dictionary = {
	"product_power": "プロダクト力",
	"team_morale": "チーム士気",
	"reputation": "投資家評判",
	"incident_reduction": "障害軽減",
	"marketing_bonus": "マーケ効果",
	"design_bonus": "デザイン力",
}

# 効果タイプの絵文字アイコン
const EFFECT_ICONS: Dictionary = {
	"product_power": "💻",
	"team_morale": "😊",
	"reputation": "📈",
	"incident_reduction": "🛡️",
	"marketing_bonus": "📣",
	"design_bonus": "🎨",
}


func _ready() -> void:
	recalculate_totals()


# --- Core methods ---

## 家具のバフを追加
func add_furniture_buff(furniture_id: String, effects: Dictionary) -> void:
	_active_buffs[furniture_id] = effects.duplicate()
	recalculate_totals()
	buffs_changed.emit()


## 家具のバフを削除
func remove_furniture_buff(furniture_id: String) -> void:
	if _active_buffs.has(furniture_id):
		_active_buffs.erase(furniture_id)
		recalculate_totals()
		buffs_changed.emit()


## 全バフをクリア
func clear_all_buffs() -> void:
	_active_buffs.clear()
	recalculate_totals()
	buffs_changed.emit()


## 全アクティブバフの合計を再計算
func recalculate_totals() -> void:
	_total_buffs.clear()
	for furniture_id in _active_buffs:
		var effects: Dictionary = _active_buffs[furniture_id]
		for effect_type in effects:
			if _total_buffs.has(effect_type):
				_total_buffs[effect_type] += effects[effect_type]
			else:
				_total_buffs[effect_type] = effects[effect_type]


# --- Query methods ---

## 指定タイプのバフ合計値を取得
func get_total_buff(effect_type: String) -> float:
	if _total_buffs.has(effect_type):
		return _total_buffs[effect_type]
	return 0.0


## 全バフ合計のコピーを返す
func get_all_buffs() -> Dictionary:
	return _total_buffs.duplicate()


## アクティブな家具バフの数
func get_buff_count() -> int:
	return _active_buffs.size()


## 特定家具のバフを取得
func get_furniture_buffs(furniture_id: String) -> Dictionary:
	if _active_buffs.has(furniture_id):
		return _active_buffs[furniture_id].duplicate()
	return {}


# --- Application methods ---

## 月次バフをGameStateに適用し、適用内容を返す
func apply_monthly_buffs() -> Dictionary:
	var applied: Dictionary = {}

	# プロダクト力ボーナス（add_product_power で均等分配）
	var pp: float = get_total_buff("product_power")
	if pp != 0.0:
		GameState.add_product_power(int(pp))
		applied["product_power"] = pp

	# チーム士気ボーナス
	var tm: float = get_total_buff("team_morale")
	if tm != 0.0:
		GameState.team_morale = clampi(GameState.team_morale + int(tm), 0, 100)
		applied["team_morale"] = tm

	# 投資家評判ボーナス
	var rep: float = get_total_buff("reputation")
	if rep != 0.0:
		GameState.reputation = clampi(GameState.reputation + int(rep), 0, 100)
		applied["reputation"] = rep

	# 障害軽減率（直接適用はせず、イベント発生時に参照される）
	var ir: float = get_total_buff("incident_reduction")
	if ir != 0.0:
		applied["incident_reduction"] = ir

	# マーケ効果ボーナス（直接適用はせず、マーケティング実行時に参照される）
	var mb: float = get_total_buff("marketing_bonus")
	if mb != 0.0:
		applied["marketing_bonus"] = mb

	# デザイン力ボーナス（プロダクトのデザイン値を直接加算）
	var db: float = get_total_buff("design_bonus")
	if db != 0.0:
		var pm = GameState._get_product_manager()
		if pm:
			var p = pm._get_active_product()
			if not p.is_empty():
				p["design"] = mini(p.get("design", 0) + int(db), 100)
		applied["design_bonus"] = db

	return applied


## 障害軽減率を取得（0〜100のパーセンテージ）
func get_incident_reduction() -> float:
	return clampf(get_total_buff("incident_reduction"), 0.0, 100.0)


# --- Serialization ---

## セーブ用にシリアライズ
func serialize() -> Dictionary:
	var data: Dictionary = {}
	for furniture_id in _active_buffs:
		data[furniture_id] = _active_buffs[furniture_id].duplicate()
	return data


## セーブデータから復元
func deserialize(data: Dictionary) -> void:
	_active_buffs.clear()
	for furniture_id in data:
		_active_buffs[furniture_id] = data[furniture_id].duplicate()
	recalculate_totals()
	buffs_changed.emit()


# --- Display helpers ---

## 全バフの日本語サマリーテキストを生成
func get_buff_summary_text() -> String:
	if _total_buffs.is_empty():
		return "効果なし"

	var lines: PackedStringArray = []
	for effect_type in _total_buffs:
		var value: float = _total_buffs[effect_type]
		var icon: String = get_effect_icon(effect_type)
		var name: String = get_effect_display_name(effect_type)
		var sign: String = "+" if value >= 0 else ""
		if effect_type == "incident_reduction" or effect_type == "marketing_bonus":
			lines.append("%s %s: %s%.1f%%" % [icon, name, sign, value])
		else:
			lines.append("%s %s: %s%d" % [icon, name, sign, int(value)])

	return "\n".join(lines)


## 効果タイプの日本語表示名を返す
func get_effect_display_name(effect_type: String) -> String:
	if EFFECT_DISPLAY_NAMES.has(effect_type):
		return EFFECT_DISPLAY_NAMES[effect_type]
	return effect_type


## 効果タイプの絵文字アイコンを返す
func get_effect_icon(effect_type: String) -> String:
	if EFFECT_ICONS.has(effect_type):
		return EFFECT_ICONS[effect_type]
	return "❓"
