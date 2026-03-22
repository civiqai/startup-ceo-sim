extends Node
## オフィス家具データ定義（Autoloadシングルトン）
## 全30種の家具アイテムとカテゴリ情報を管理する

# カテゴリ定義
const CATEGORIES: Dictionary = {
	"desk": {"name": "デスク・ワークステーション", "icon": "🖥️"},
	"meeting": {"name": "会議・コミュニケーション", "icon": "🤝"},
	"infra": {"name": "インフラ・サーバー", "icon": "🔧"},
	"comfort": {"name": "快適性・福利厚生", "icon": "☕"},
	"decor": {"name": "インテリア・装飾", "icon": "🎨"},
	"special": {"name": "特殊・レア", "icon": "⭐"},
}

# 全家具データ
var _items: Dictionary = {}


func _ready() -> void:
	_init_items()


func _init_items() -> void:
	# === デスク・ワークステーション (6) ===
	_register({
		"id": "desk_basic",
		"name": "折りたたみデスク",
		"category": "desk",
		"cost": 5,
		"effects": {"product_power": 1},
		"description": "スタートアップの原点。折りたたみ式の簡易デスク。最低限の作業スペースを確保できる。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_desk/Desk_1_Tile.png",
		"upgrade_to": "desk_standing",
		"required_phase": 0,
	})
	_register({
		"id": "desk_standing",
		"name": "スタンディングデスク",
		"category": "desk",
		"cost": 30,
		"effects": {"product_power": 2, "team_morale": 2},
		"description": "立って作業できる昇降式デスク。健康的な働き方で士気もアップ。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_desk/Desk_1_B_Tile.png",
		"upgrade_to": "desk_executive",
		"required_phase": 1,
	})
	_register({
		"id": "desk_executive",
		"name": "エグゼクティブデスク",
		"category": "desk",
		"cost": 80,
		"effects": {"reputation": 3, "team_morale": 1},
		"description": "重厚な木製の高級デスク。来客時の印象が格段にアップする。",
		"size": Vector2i(4, 3),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_5.png",
		"upgrade_to": "",
		"required_phase": 3,
	})
	_register({
		"id": "monitor_hd",
		"name": "HDモニター",
		"category": "desk",
		"cost": 15,
		"effects": {"product_power": 2},
		"description": "フルHD解像度の標準的なモニター。開発効率が少し向上する。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/OldImac_A_Tile.png",
		"upgrade_to": "monitor_4k",
		"required_phase": 0,
	})
	_register({
		"id": "monitor_4k",
		"name": "4Kモニター",
		"category": "desk",
		"cost": 50,
		"effects": {"product_power": 4, "design_bonus": 5},
		"description": "4K高解像度モニター。細部まで確認でき、デザイン作業の品質が向上。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/NewImac_A_Tile.png",
		"upgrade_to": "monitor_ultrawide",
		"required_phase": 2,
	})
	_register({
		"id": "monitor_ultrawide",
		"name": "ウルトラワイドモニター",
		"category": "desk",
		"cost": 100,
		"effects": {"product_power": 6, "design_bonus": 8},
		"description": "超横長のウルトラワイドモニター。複数ウィンドウを並べて最高の開発環境を実現。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/BendedScreen_A_Tile.png",
		"upgrade_to": "",
		"required_phase": 3,
	})

	# === 会議・コミュニケーション (5) ===
	_register({
		"id": "whiteboard",
		"name": "ホワイトボード",
		"category": "meeting",
		"cost": 10,
		"effects": {"product_power": 1, "team_morale": 1},
		"description": "アイデアを自由に書き出せるホワイトボード。ブレストの必需品。",
		"size": Vector2i(3, 3),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_15.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "meeting_table",
		"name": "ミーティングテーブル",
		"category": "meeting",
		"cost": 40,
		"effects": {"team_morale": 3, "reputation": 2},
		"description": "しっかりとした会議用テーブル。チームの議論が活発になり、来客対応もスムーズに。",
		"size": Vector2i(4, 3),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_1.png",
		"upgrade_to": "",
		"required_phase": 1,
	})
	_register({
		"id": "projector",
		"name": "プロジェクター",
		"category": "meeting",
		"cost": 60,
		"effects": {"reputation": 4, "marketing_bonus": 3},
		"description": "プレゼン用プロジェクター。投資家へのピッチや社内発表に威力を発揮。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_20.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "video_conf",
		"name": "ビデオ会議システム",
		"category": "meeting",
		"cost": 80,
		"effects": {"reputation": 3, "team_morale": 2},
		"description": "高品質なビデオ会議システム。リモートワーク対応で採用力もアップ。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/RotationScreen_A_Tile.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "phone_booth",
		"name": "集中ブース",
		"category": "meeting",
		"cost": 50,
		"effects": {"product_power": 3},
		"description": "防音仕様の一人用ブース。集中して作業やWeb会議ができる。",
		"size": Vector2i(3, 3),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_30.png",
		"upgrade_to": "",
		"required_phase": 2,
	})

	# === インフラ・サーバー (5) ===
	_register({
		"id": "router_basic",
		"name": "Wi-Fiルーター",
		"category": "infra",
		"cost": 5,
		"effects": {"incident_reduction": 5},
		"description": "基本的なWi-Fiルーター。ネットワーク障害のリスクを少し軽減。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/PcTower_Tile.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "server_rack",
		"name": "サーバーラック",
		"category": "infra",
		"cost": 100,
		"effects": {"incident_reduction": 15, "product_power": 3},
		"description": "自社サーバーラック。高い可用性と開発環境の自由度を両立。",
		"size": Vector2i(2, 3),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/OldPC_A_Tile.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "ups_battery",
		"name": "無停電電源装置(UPS)",
		"category": "infra",
		"cost": 40,
		"effects": {"incident_reduction": 10},
		"description": "停電時もサーバーを守るUPS。突然の電源トラブルから業務を守る。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/OldPC_B_Tile.png",
		"upgrade_to": "",
		"required_phase": 1,
	})
	_register({
		"id": "firewall",
		"name": "ファイアウォール装置",
		"category": "infra",
		"cost": 70,
		"effects": {"incident_reduction": 20, "reputation": 2},
		"description": "高性能ファイアウォール。セキュリティインシデントのリスクを大幅に低減。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/NewImac_B_Tile.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "nas_storage",
		"name": "NASストレージ",
		"category": "infra",
		"cost": 50,
		"effects": {"incident_reduction": 8, "product_power": 2},
		"description": "ネットワーク接続ストレージ。データのバックアップと共有を効率化。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/PcTower_Tile.png",
		"upgrade_to": "",
		"required_phase": 1,
	})

	# === 快適性・福利厚生 (6) ===
	_register({
		"id": "plant_small",
		"name": "小さな観葉植物",
		"category": "comfort",
		"cost": 3,
		"effects": {"team_morale": 1},
		"description": "デスクに置ける小さな観葉植物。オフィスに緑のある癒しの空間を。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_plants/Cactus_1.png",
		"upgrade_to": "plant_large",
		"required_phase": 0,
	})
	_register({
		"id": "plant_large",
		"name": "大きな観葉植物",
		"category": "comfort",
		"cost": 15,
		"effects": {"team_morale": 3},
		"description": "存在感のある大きな観葉植物。オフィスの雰囲気が一気に良くなる。",
		"size": Vector2i(2, 3),
		"sprite_path": "res://assets/images/furniture/tinyhouse_plants/Plant_5.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "coffee_machine",
		"name": "コーヒーマシン",
		"category": "comfort",
		"cost": 20,
		"effects": {"team_morale": 3, "product_power": 1},
		"description": "本格的なコーヒーマシン。カフェインでチームの生産性と士気が向上。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/livingroom/Living_Room_Singles_32x32_10.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "snack_bar",
		"name": "スナックバー",
		"category": "comfort",
		"cost": 30,
		"effects": {"team_morale": 4},
		"description": "お菓子や軽食が並ぶスナックバー。小腹が空いた時の強い味方。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/livingroom/Living_Room_Singles_32x32_15.png",
		"upgrade_to": "",
		"required_phase": 1,
	})
	_register({
		"id": "nap_space",
		"name": "仮眠スペース",
		"category": "comfort",
		"cost": 60,
		"effects": {"team_morale": 5, "incident_reduction": 5},
		"description": "仮眠用のリクライニングスペース。適度な休憩で集中力を回復し、ミスも減少。",
		"size": Vector2i(4, 3),
		"sprite_path": "res://assets/images/furniture/livingroom/Living_Room_Singles_32x32_1.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "game_corner",
		"name": "ゲームコーナー",
		"category": "comfort",
		"cost": 45,
		"effects": {"team_morale": 6, "product_power": -1},
		"description": "ゲーム機やボードゲームが揃うコーナー。士気は爆上がりだが、少しサボりがちに…。",
		"size": Vector2i(3, 3),
		"sprite_path": "res://assets/images/furniture/tinyhouse_pc/NES_4_Tile.png",
		"upgrade_to": "",
		"required_phase": 2,
	})

	# === インテリア・装飾 (5) ===
	_register({
		"id": "poster_motivational",
		"name": "モチベーションポスター",
		"category": "decor",
		"cost": 5,
		"effects": {"team_morale": 1},
		"description": "「Stay Hungry, Stay Foolish」的な名言ポスター。壁に彩りを添える。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_poster/Poster_16.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "portrait_jobs",
		"name": "ジョブズの肖像画",
		"category": "decor",
		"cost": 50,
		"effects": {"product_power": 3, "reputation": 2},
		"description": "スティーブ・ジョブズの肖像画。プロダクトへのこだわりが自然と高まる。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_poster/Poster_17.png",
		"upgrade_to": "",
		"required_phase": 1,
	})
	_register({
		"id": "portrait_bezos",
		"name": "ベゾスの肖像画",
		"category": "decor",
		"cost": 50,
		"effects": {"marketing_bonus": 5, "reputation": 2},
		"description": "ジェフ・ベゾスの肖像画。顧客第一主義の精神がチームに浸透する。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_poster/Poster_16.png",
		"upgrade_to": "",
		"required_phase": 1,
	})
	_register({
		"id": "bookshelf",
		"name": "技術書棚",
		"category": "decor",
		"cost": 25,
		"effects": {"product_power": 2, "team_morale": 1},
		"description": "技術書がぎっしり並んだ本棚。エンジニアの知識欲を刺激する。",
		"size": Vector2i(2, 3),
		"sprite_path": "res://assets/images/furniture/livingroom/Living_Room_Singles_32x32_100.png",
		"upgrade_to": "",
		"required_phase": 0,
	})
	_register({
		"id": "award_trophy",
		"name": "受賞トロフィー",
		"category": "decor",
		"cost": 100,
		"effects": {"reputation": 8},
		"description": "スタートアップアワードのトロフィー。投資家への説得力が段違い。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_45.png",
		"upgrade_to": "",
		"required_phase": 3,
	})

	# === 特殊・レア (3) ===
	_register({
		"id": "ping_pong",
		"name": "卓球台",
		"category": "special",
		"cost": 35,
		"effects": {"team_morale": 5, "reputation": 1},
		"description": "シリコンバレー定番の卓球台。スタートアップ感が一気にアップ。",
		"size": Vector2i(5, 3),
		"sprite_path": "res://assets/images/furniture/conference/Conference_Hall_Singles_32x32_50.png",
		"upgrade_to": "",
		"required_phase": 2,
	})
	_register({
		"id": "aquarium",
		"name": "アクアリウム",
		"category": "special",
		"cost": 80,
		"effects": {"team_morale": 4, "reputation": 3},
		"description": "美しい熱帯魚のアクアリウム。来客の目を引き、チームの癒しにもなる。",
		"size": Vector2i(3, 2),
		"sprite_path": "res://assets/images/furniture/livingroom/Living_Room_Singles_32x32_50.png",
		"upgrade_to": "",
		"required_phase": 3,
	})
	_register({
		"id": "massage_chair",
		"name": "マッサージチェア",
		"category": "special",
		"cost": 120,
		"effects": {"team_morale": 7, "incident_reduction": 3},
		"description": "高級マッサージチェア。疲労回復で士気が大幅アップし、ヒューマンエラーも減少。",
		"size": Vector2i(2, 2),
		"sprite_path": "res://assets/images/furniture/tinyhouse_chair/Chair_2_A_Tile.png",
		"upgrade_to": "",
		"required_phase": 3,
	})


func _register(data: Dictionary) -> void:
	_items[data["id"]] = data


# === ヘルパーメソッド ===

## 指定IDの家具データを取得
func get_item(id: String) -> Dictionary:
	if _items.has(id):
		return _items[id]
	push_warning("FurnitureData: 不明な家具ID '%s'" % id)
	return {}


## 指定カテゴリの家具一覧を取得
func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for item in _items.values():
		if item["category"] == category:
			result.append(item)
	# コスト順にソート
	result.sort_custom(func(a, b): return a["cost"] < b["cost"])
	return result


## 現在のフェーズと資金で購入可能な家具一覧を取得
func get_available_items(phase: int, cash: int) -> Array:
	var result: Array = []
	for item in _items.values():
		if item["required_phase"] <= phase and item["cost"] <= cash:
			result.append(item)
	result.sort_custom(func(a, b): return a["cost"] < b["cost"])
	return result


## アップグレードチェーンを取得（指定IDから最終アップグレードまで）
func get_upgrade_chain(id: String) -> Array:
	var chain: Array = []
	var current_id := id
	# まず逆方向に辿って最初のアイテムを見つける
	var root_id := _find_upgrade_root(id)
	# ルートから順方向に辿る
	current_id = root_id
	while current_id != "":
		var item := get_item(current_id)
		if item.is_empty():
			break
		chain.append(item)
		current_id = item.get("upgrade_to", "")
	return chain


## アップグレードチェーンのルート（最初のアイテム）を探す
func _find_upgrade_root(id: String) -> String:
	# 全アイテムを走査して、upgrade_toが指定IDを指すものを探す
	for item in _items.values():
		if item["upgrade_to"] == id:
			return _find_upgrade_root(item["id"])
	return id


## カテゴリの表示名を取得
func get_category_name(category: String) -> String:
	if CATEGORIES.has(category):
		return CATEGORIES[category]["name"]
	return category


## 全カテゴリ一覧を取得（IDと表示名のペア）
func get_all_categories() -> Array:
	var result: Array = []
	for cat_id in CATEGORIES:
		result.append({
			"id": cat_id,
			"name": CATEGORIES[cat_id]["name"],
			"icon": CATEGORIES[cat_id]["icon"],
		})
	return result
