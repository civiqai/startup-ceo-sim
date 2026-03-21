extends Node
## プロダクト開発管理 — 複数プロダクト・タイプ選択・機能開発・技術的負債・撤退

signal feature_completed(feature: Dictionary)
signal tech_debt_warning(debt_level: int)
signal product_created(product: Dictionary)
signal product_shutdown(product: Dictionary)

# プロダクトタイプ
const PRODUCT_TYPES := {
	"saas": {
		"name": "SaaS", "icon": "☁️",
		"description": "BtoB向けクラウドサービス",
		"base_mrr_multiplier": 1.5,
		"user_growth_rate": 0.8,
		"init_cost": 200,  # 初期費用200万
		"monthly_maintenance": 30,  # 月額メンテ30万
		"features": ["auth", "dashboard", "analytics", "api", "billing", "notification", "admin", "export"],
	},
	"game": {
		"name": "ゲーム", "icon": "🎮",
		"description": "モバイルゲーム",
		"base_mrr_multiplier": 2.0,
		"user_growth_rate": 1.5,
		"init_cost": 1000,  # 初期費用1000万
		"monthly_maintenance": 80,  # 月額メンテ80万
		"features": ["auth", "gacha", "pvp", "guild", "ranking", "event_system", "tutorial", "shop"],
	},
	"iot": {
		"name": "IoT", "icon": "📡",
		"description": "IoTプラットフォーム",
		"base_mrr_multiplier": 1.8,
		"user_growth_rate": 0.5,
		"init_cost": 1500,  # 初期費用1500万
		"monthly_maintenance": 100,  # 月額メンテ100万
		"features": ["auth", "dashboard", "api", "notification", "admin", "export", "analytics", "billing"],
	},
}

# テーマ（タイプ別）
const PRODUCT_THEMES := {
	"saas": [
		{"id": "hr", "name": "HR管理", "icon": "👥", "bonus": {"ux": 3, "margin": 2}},
		{"id": "accounting", "name": "会計・経理", "icon": "📊", "bonus": {"margin": 5}},
		{"id": "crm", "name": "CRM・営業支援", "icon": "🤝", "bonus": {"awareness": 3, "margin": 2}},
		{"id": "project", "name": "プロジェクト管理", "icon": "📋", "bonus": {"ux": 5}},
		{"id": "communication", "name": "コミュニケーション", "icon": "💬", "bonus": {"ux": 3, "design": 2}},
	],
	"game": [
		{"id": "rpg", "name": "RPG", "icon": "⚔️", "bonus": {"design": 5}},
		{"id": "puzzle", "name": "パズル", "icon": "🧩", "bonus": {"ux": 3, "margin": 2}},
		{"id": "social", "name": "ソーシャルゲーム", "icon": "🎭", "bonus": {"awareness": 3, "design": 2}},
		{"id": "casual", "name": "カジュアルゲーム", "icon": "🎯", "bonus": {"ux": 5}},
		{"id": "strategy", "name": "ストラテジー", "icon": "♟️", "bonus": {"design": 3, "margin": 2}},
	],
	"iot": [
		{"id": "smart_home", "name": "スマートホーム", "icon": "🏠", "bonus": {"ux": 3, "design": 2}},
		{"id": "industrial", "name": "産業IoT", "icon": "🏭", "bonus": {"margin": 5}},
		{"id": "healthcare", "name": "ヘルスケア", "icon": "🏥", "bonus": {"awareness": 3, "margin": 2}},
		{"id": "agriculture", "name": "スマート農業", "icon": "🌾", "bonus": {"margin": 3, "awareness": 2}},
		{"id": "logistics", "name": "物流IoT", "icon": "🚚", "bonus": {"ux": 2, "margin": 3}},
	],
}

# 技術スタック
const TECH_STACKS := [
	{"id": "react_node", "name": "React + Node.js", "icon": "⚛️", "bonus": {"ux": 3}, "description": "モダンなWeb開発。UX重視。"},
	{"id": "flutter", "name": "Flutter", "icon": "📱", "bonus": {"design": 3}, "description": "クロスプラットフォーム。デザイン重視。"},
	{"id": "python_django", "name": "Python + Django", "icon": "🐍", "bonus": {"margin": 2, "ux": 1}, "description": "高速開発。利益率重視。"},
	{"id": "golang", "name": "Go + gRPC", "icon": "🔷", "bonus": {"margin": 3}, "description": "高パフォーマンス。利益率重視。"},
	{"id": "unity", "name": "Unity", "icon": "🎮", "bonus": {"design": 2, "ux": 1}, "description": "ゲーム開発に最適。"},
	{"id": "rails", "name": "Ruby on Rails", "icon": "💎", "bonus": {"ux": 2, "awareness": 1}, "description": "スタートアップ向け高速開発。"},
]

# 機能の定義（共通）— ステータス別効果付き
# ux: UX品質, design: デザイン, margin: 利益率, awareness: 知名度
const FEATURES := {
	"auth": {"name": "認証・ログイン", "cost": 0, "power": 5, "months": 1, "icon": "🔐",
		"effects": {"ux": 8, "margin": 3}},
	"dashboard": {"name": "ダッシュボード", "cost": 100, "power": 8, "months": 2, "icon": "📊",
		"effects": {"ux": 12, "design": 5, "margin": 5}},
	"analytics": {"name": "分析機能", "cost": 150, "power": 10, "months": 2, "icon": "📈",
		"effects": {"ux": 6, "margin": 10, "awareness": 5}},
	"api": {"name": "API公開", "cost": 200, "power": 12, "months": 3, "icon": "🔌",
		"effects": {"ux": 5, "margin": 12, "awareness": 8}},
	"billing": {"name": "課金システム", "cost": 250, "power": 15, "months": 3, "icon": "💳",
		"effects": {"margin": 20, "ux": 5}},
	"notification": {"name": "通知機能", "cost": 80, "power": 6, "months": 1, "icon": "🔔",
		"effects": {"ux": 10, "awareness": 5}},
	"admin": {"name": "管理画面", "cost": 120, "power": 7, "months": 2, "icon": "⚙️",
		"effects": {"ux": 8, "margin": 5}},
	"export": {"name": "データ出力", "cost": 100, "power": 5, "months": 1, "icon": "📤",
		"effects": {"ux": 6, "margin": 6}},
	"gacha": {"name": "ガチャ", "cost": 200, "power": 15, "months": 2, "icon": "🎰",
		"effects": {"margin": 18, "awareness": 8}},
	"pvp": {"name": "対戦機能", "cost": 300, "power": 18, "months": 3, "icon": "⚔️",
		"effects": {"ux": 10, "design": 8, "awareness": 12}},
	"guild": {"name": "ギルド", "cost": 200, "power": 12, "months": 2, "icon": "🏰",
		"effects": {"ux": 8, "design": 5, "awareness": 8}},
	"ranking": {"name": "ランキング", "cost": 100, "power": 8, "months": 1, "icon": "🏆",
		"effects": {"ux": 6, "awareness": 10}},
	"event_system": {"name": "イベント機能", "cost": 150, "power": 10, "months": 2, "icon": "🎪",
		"effects": {"ux": 8, "awareness": 10, "margin": 5}},
	"tutorial": {"name": "チュートリアル", "cost": 80, "power": 5, "months": 1, "icon": "📖",
		"effects": {"ux": 12, "design": 5}},
	"shop": {"name": "ショップ", "cost": 150, "power": 10, "months": 2, "icon": "🏪",
		"effects": {"margin": 15, "design": 5, "ux": 5}},
}

# 複数プロダクト管理
var products: Array[Dictionary] = []

# 現在選択中のプロダクトインデックス（開発・マーケティング対象）
var active_product_index: int = -1

# 後方互換: selected_product_type は最初のアクティブプロダクトのタイプを返す
var selected_product_type: String:
	get:
		for p in products:
			if p.get("active", true):
				return p["type"]
		return ""

# 後方互換: developed_features は選択中プロダクトの機能リスト
var developed_features: Array[String]:
	get:
		var p = _get_active_product()
		if p.is_empty():
			return [] as Array[String]
		var result: Array[String] = []
		for f in p.get("developed_features", []):
			result.append(f)
		return result

# 後方互換: developing_feature は選択中プロダクトの開発中機能
var developing_feature: String:
	get:
		var p = _get_active_product()
		if p.is_empty():
			return ""
		return p.get("developing_feature", "")

# 後方互換: dev_remaining_months
var dev_remaining_months: int:
	get:
		var p = _get_active_product()
		if p.is_empty():
			return 0
		return p.get("dev_remaining_months", 0)

# 後方互換: tech_debt（全アクティブプロダクトの最大値）
var tech_debt: int:
	get:
		var max_debt := 0
		for p in products:
			if p.get("active", true):
				max_debt = maxi(max_debt, p.get("tech_debt", 0))
		return max_debt
	set(value):
		# 選択中プロダクトの tech_debt を設定（イベント等での直接書き込み対応）
		var p = _get_active_product()
		if not p.is_empty():
			p["tech_debt"] = value


## 現在選択中のアクティブプロダクトを取得
func _get_active_product() -> Dictionary:
	if active_product_index >= 0 and active_product_index < products.size():
		var p = products[active_product_index]
		if p.get("active", true):
			return p
	# フォールバック: 最初のアクティブプロダクト
	for i in products.size():
		if products[i].get("active", true):
			active_product_index = i
			return products[i]
	return {}


## アクティブプロダクト一覧を取得
func get_active_products() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in products:
		if p.get("active", true):
			result.append(p)
	return result


## プロダクトを新規作成
func create_product(type_id: String) -> String:
	if not PRODUCT_TYPES.has(type_id):
		return "不明なプロダクトタイプ"
	if not TeamManager.has_cxo("pm") and TeamManager.get_members_by_skill("pm").is_empty():
		return "PM(プロダクトマネージャー)が必要です"
	var type_data = PRODUCT_TYPES[type_id]
	var init_cost = type_data.get("init_cost", 0)
	if GameState.cash < init_cost:
		return "初期費用%d万円が不足しています" % init_cost
	# SaaS以外は資金制約チェック
	if type_id != "saas" and GameState.cash < init_cost + 500:
		return "資金に余裕がありません（推奨: %d万円以上）" % (init_cost + 500)
	GameState.cash -= init_cost
	var product := {
		"type": type_id,
		"name": type_data["name"],
		"ux": 5,
		"design": 5,
		"margin": 0,
		"awareness": 0,
		"developed_features": ["auth"],
		"developing_feature": "",
		"dev_remaining_months": 0,
		"tech_debt": 0,
		"users": 0,
		"revenue": 0,
		"active": true,
	}
	products.append(product)
	active_product_index = products.size() - 1
	product_created.emit(product)
	return "%s %sを立ち上げました！（初期費用: %d万円）" % [type_data["icon"], type_data["name"], init_cost]


## プロダクトを設定付きで新規作成（create_product_popup から呼ばれる）
func create_product_with_config(config: Dictionary) -> String:
	var type_id = config.get("type", "")
	if not PRODUCT_TYPES.has(type_id):
		return "不明なプロダクトタイプ"
	if not TeamManager.has_cxo("pm") and TeamManager.get_members_by_skill("pm").is_empty():
		return "PM(プロダクトマネージャー)が必要です"
	var active = get_active_products()
	if active.size() >= 3:
		return "プロダクトは最大3つまでです"
	var type_data = PRODUCT_TYPES[type_id]
	var init_cost = type_data.get("init_cost", 0)
	if GameState.cash < init_cost:
		return "初期費用%d万円が不足しています" % init_cost
	GameState.cash -= init_cost
	var theme = config.get("theme", {})
	var stack = config.get("tech_stack", {})
	var product_name = "%s（%s）" % [type_data["name"], theme.get("name", "")]
	var product := {
		"type": type_id,
		"name": product_name,
		"theme_id": theme.get("id", ""),
		"tech_stack_id": stack.get("id", ""),
		"ux": config.get("initial_ux", 5),
		"design": config.get("initial_design", 5),
		"margin": config.get("initial_margin", 0),
		"awareness": config.get("initial_awareness", 0),
		"developed_features": ["auth"],
		"developing_feature": "",
		"dev_remaining_months": 0,
		"tech_debt": 0,
		"users": 0,
		"revenue": 0,
		"active": true,
	}
	products.append(product)
	active_product_index = products.size() - 1
	product_created.emit(product)
	return "%s %sを立ち上げました！（初期費用: %d万円）" % [type_data["icon"], product_name, init_cost]


## チーム構成に応じた配分ポイント数を計算
func get_allocation_points() -> int:
	var points := 10
	for m in TeamManager.members:
		match m.skill_type:
			"engineer":
				points += 2
			"designer":
				points += 2
			"pm":
				points += 3
	return points


## サービス撤退（シャットダウン）
func shutdown_product(index: int) -> String:
	if index < 0 or index >= products.size():
		return "無効なプロダクト"
	var p = products[index]
	if not p.get("active", true):
		return "既にサービス終了しています"
	p["active"] = false
	p["developing_feature"] = ""
	p["dev_remaining_months"] = 0
	product_shutdown.emit(p)
	# active_product_indexがシャットダウンしたものなら再選択
	if active_product_index == index:
		active_product_index = -1
		_get_active_product()  # フォールバックで再選択
	return "%sをサービス終了しました。メンテコストが削減されます。" % p["name"]


## 月額メンテコスト合計を取得
func get_total_maintenance_cost() -> int:
	var total := 0
	for p in products:
		if p.get("active", true):
			var type_data = PRODUCT_TYPES.get(p["type"], {})
			total += type_data.get("monthly_maintenance", 0)
	return total


## プロダクトタイプを選択（後方互換 + 自動プロダクト作成）
func select_product_type(type_id: String) -> void:
	if PRODUCT_TYPES.has(type_id):
		# 既存プロダクトがない場合は新規作成（旧API互換）
		if products.is_empty():
			var product := {
				"type": type_id,
				"name": PRODUCT_TYPES[type_id]["name"],
				"ux": 5,
				"design": 5,
				"margin": 0,
				"awareness": 0,
				"developed_features": ["auth"],
				"developing_feature": "",
				"dev_remaining_months": 0,
				"tech_debt": 0,
				"users": 0,
				"revenue": 0,
				"active": true,
			}
			products.append(product)
			active_product_index = 0


## アクティブプロダクトを選択（インデックス指定）
func select_active_product(index: int) -> void:
	if index >= 0 and index < products.size() and products[index].get("active", true):
		active_product_index = index


## 開発可能な機能一覧を取得（選択中プロダクト）
func get_available_features() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var p = _get_active_product()
	if p.is_empty():
		return result
	var type_data = PRODUCT_TYPES.get(p["type"], {})
	var feats = p.get("developed_features", [])
	var dev_feat = p.get("developing_feature", "")
	for feat_id in type_data.get("features", []):
		if feat_id in feats or feat_id == dev_feat:
			continue
		if FEATURES.has(feat_id):
			var feat = FEATURES[feat_id].duplicate()
			feat["id"] = feat_id
			result.append(feat)
	return result


## 機能開発を開始（選択中プロダクト）
func start_feature_dev(feature_id: String) -> bool:
	var p = _get_active_product()
	if p.is_empty():
		return false
	if not FEATURES.has(feature_id):
		return false
	if feature_id in p.get("developed_features", []):
		return false
	var feat = FEATURES[feature_id]
	if GameState.cash < feat["cost"]:
		return false
	GameState.cash -= feat["cost"]
	p["developing_feature"] = feature_id
	p["dev_remaining_months"] = feat["months"]
	return true


## 毎月の開発進捗処理（全アクティブプロダクト）
func advance_month() -> String:
	var results: Array[String] = []
	for i in products.size():
		var p = products[i]
		if not p.get("active", true):
			continue
		var dev_feat = p.get("developing_feature", "")
		if dev_feat == "":
			continue
		p["dev_remaining_months"] = p.get("dev_remaining_months", 0) - 1

		# CTOがいれば開発速度UP
		if TeamManager.has_cxo("engineer") and p["dev_remaining_months"] > 0:
			if randf() < 0.3:
				p["dev_remaining_months"] -= 1

		if p["dev_remaining_months"] <= 0:
			var feats: Array = p.get("developed_features", [])
			feats.append(dev_feat)
			p["developed_features"] = feats
			var feat = FEATURES.get(dev_feat, {})
			# ステータス別効果を直接プロダクトに適用
			var effects: Dictionary = feat.get("effects", {})
			var applied_effects: Dictionary = {}
			for stat_key in effects:
				var gain: int = effects[stat_key]
				var old_val: int = p.get(stat_key, 0)
				p[stat_key] = mini(old_val + gain, 100)
				applied_effects[stat_key] = p[stat_key] - old_val
			# 技術的負債の増加
			p["tech_debt"] = mini(p.get("tech_debt", 0) + randi_range(3, 8), 100)
			var product_label: String = ""
			if products.size() > 1:
				product_label = "[%s] " % p.get("name", "")
			var result_text: String = "%s%s %sが完成！" % [
				product_label, feat.get("icon", ""), feat.get("name", "")]
			var completed_feat: Dictionary = feat.duplicate()
			completed_feat["id"] = dev_feat
			completed_feat["applied_effects"] = applied_effects
			completed_feat["product_name"] = p.get("name", "")
			feature_completed.emit(completed_feat)
			p["developing_feature"] = ""
			p["dev_remaining_months"] = 0
			if p.get("tech_debt", 0) >= 60:
				tech_debt_warning.emit(p.get("tech_debt", 0))
			results.append(result_text)
	return "\n".join(results)


## 技術的負債の返済（選択中プロダクト、1ターン消費）
func pay_tech_debt() -> String:
	var p = _get_active_product()
	if p.is_empty():
		return "対象プロダクトがありません"
	var reduction = randi_range(15, 30)
	# CTOボーナス
	if TeamManager.has_cxo("engineer"):
		reduction += 10
	p["tech_debt"] = maxi(p.get("tech_debt", 0) - reduction, 0)
	return "技術的負債を返済。負債 -%d（残り: %d）" % [reduction, p.get("tech_debt", 0)]


## 技術的負債によるバグ確率
func get_bug_probability() -> float:
	return tech_debt / 200.0  # 最大50%


## 開発済み機能数に応じたプロダクト力ボーナス
func get_feature_bonus() -> int:
	var total := 0
	for p in products:
		if p.get("active", true):
			total += p.get("developed_features", []).size()
	return total * 2


## MRR倍率を取得（全アクティブプロダクトの加重平均）
func get_mrr_multiplier() -> float:
	var active = get_active_products()
	if active.is_empty():
		return 1.0
	var total := 0.0
	for p in active:
		var type_data = PRODUCT_TYPES.get(p["type"], {})
		total += type_data.get("base_mrr_multiplier", 1.0)
	return total / active.size()


## リセット
func reset() -> void:
	products.clear()
	active_product_index = -1


## セーブ用
func to_dict() -> Dictionary:
	return {
		"products": products.duplicate(true),
		"active_product_index": active_product_index,
		# 後方互換
		"selected_product_type": selected_product_type,
	}


## ロード用
func from_dict(data: Dictionary) -> void:
	# 新フォーマット
	if data.has("products"):
		products.clear()
		for p in data["products"]:
			# 旧プロダクトデータにux/design等がない場合のデフォルト値を補完
			if not p.has("ux"):
				p["ux"] = 5
			if not p.has("design"):
				p["design"] = 5
			if not p.has("margin"):
				p["margin"] = 0
			if not p.has("awareness"):
				p["awareness"] = 0
			if not p.has("revenue"):
				p["revenue"] = 0
			products.append(p)
		active_product_index = data.get("active_product_index", -1)
		if active_product_index < 0:
			_get_active_product()
	else:
		# 旧フォーマットからの移行
		products.clear()
		var old_type = data.get("selected_product_type", "")
		if old_type != "":
			var feats: Array = []
			for f in data.get("developed_features", []):
				feats.append(f)
			var product := {
				"type": old_type,
				"name": PRODUCT_TYPES.get(old_type, {}).get("name", old_type),
				"ux": 5,
				"design": 5,
				"margin": 0,
				"awareness": 0,
				"developed_features": feats,
				"developing_feature": data.get("developing_feature", ""),
				"dev_remaining_months": data.get("dev_remaining_months", 0),
				"tech_debt": data.get("tech_debt", 0),
				"users": 0,
				"revenue": 0,
				"active": true,
			}
			products.append(product)
			active_product_index = 0
		else:
			active_product_index = -1
