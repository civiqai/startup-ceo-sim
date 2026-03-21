extends Node
## 競合・市場システム — 見えない競合AIと市場シェア

signal competitor_news(news_text: String)
signal market_share_changed(player_share: float)

# 競合企業定義
const COMPETITORS := [
	{
		"name": "TechNova", "icon": "🔷",
		"style": "aggressive",  # aggressive, steady, innovative
		"base_growth": 1.2,
		"description": "潤沢な資金で急成長するメガベンチャー",
	},
	{
		"name": "SmartFlow", "icon": "🟢",
		"style": "steady",
		"base_growth": 0.8,
		"description": "堅実な経営で着実にシェアを伸ばす老舗",
	},
	{
		"name": "DisruptX", "icon": "🟠",
		"style": "innovative",
		"base_growth": 1.5,
		"description": "革新的な技術で市場を揺さぶるスタートアップ",
	},
]

# 競合ニューステンプレート
const NEWS_TEMPLATES := {
	"aggressive": [
		"%sが大型資金調達を完了、事業拡大へ",
		"%sが新オフィスを開設、社員数が倍増",
		"%sがTVCMを開始、認知度向上を狙う",
		"%sが海外展開を発表",
	],
	"steady": [
		"%sが黒字化を達成、安定経営をアピール",
		"%sが新機能をリリース、既存顧客の満足度UP",
		"%sが業界団体の理事に就任",
		"%sがセキュリティ認証を取得",
	],
	"innovative": [
		"%sがAI新機能を発表、業界に衝撃",
		"%sの特許出願数が業界トップに",
		"%sのCTOが技術カンファレンスで基調講演",
		"%sがオープンソースプロジェクトを公開",
	],
}

var competitor_scores: Array[float] = []  # 各競合のスコア（市場シェア計算用）
var total_market_size: float = 10000.0    # 市場全体のサイズ
var market_growth_rate: float = 1.05      # 市場成長率（月次）
var news_cooldown: int = 0


func _ready() -> void:
	# 競合スコア初期化
	competitor_scores.clear()
	for comp in COMPETITORS:
		competitor_scores.append(randf_range(500, 1500))


## 毎月の処理
func advance_month(gs) -> Array[String]:
	var news_list: Array[String] = []

	# 市場全体の成長
	total_market_size *= market_growth_rate

	# 競合の成長
	for i in COMPETITORS.size():
		var comp = COMPETITORS[i]
		var growth = comp["base_growth"]
		# ランダム変動
		growth *= randf_range(0.7, 1.3)
		# スタイル別の特殊処理
		match comp["style"]:
			"aggressive":
				# 資金力で押す → ユーザー数で勝負
				competitor_scores[i] += growth * randf_range(50, 150)
			"steady":
				# 安定成長
				competitor_scores[i] += growth * randf_range(30, 80)
			"innovative":
				# ハイリスクハイリターン
				if randf() < 0.2:
					competitor_scores[i] += growth * randf_range(200, 500)
				else:
					competitor_scores[i] += growth * randf_range(20, 60)

	# ニュース生成（2ヶ月に1回程度）
	news_cooldown -= 1
	if news_cooldown <= 0:
		var comp_idx = randi() % COMPETITORS.size()
		var comp = COMPETITORS[comp_idx]
		var templates = NEWS_TEMPLATES.get(comp["style"], [])
		if templates.size() > 0:
			var template = templates[randi() % templates.size()]
			var news = "%s %s" % [comp["icon"], template % comp["name"]]
			news_list.append(news)
			competitor_news.emit(news)
		news_cooldown = randi_range(1, 3)

	# 市場シェア更新
	var player_share = get_player_market_share(gs)
	market_share_changed.emit(player_share)

	return news_list


## プレイヤーの市場シェアを計算
func get_player_market_share(gs) -> float:
	var player_score = float(gs.users) * (gs.product_power / 50.0) * (1.0 + gs.brand_value / 100.0)
	var total_score = player_score
	for score in competitor_scores:
		total_score += score
	if total_score <= 0:
		return 0.0
	return player_score / total_score * 100.0


## 各競合の市場シェアを取得
func get_competitor_shares(gs) -> Array[Dictionary]:
	var player_score = float(gs.users) * (gs.product_power / 50.0) * (1.0 + gs.brand_value / 100.0)
	var total_score = player_score
	for score in competitor_scores:
		total_score += score
	if total_score <= 0:
		return []

	var result: Array[Dictionary] = []
	result.append({
		"name": "自社", "icon": "⭐",
		"share": player_score / total_score * 100.0,
	})
	for i in COMPETITORS.size():
		result.append({
			"name": COMPETITORS[i]["name"],
			"icon": COMPETITORS[i]["icon"],
			"share": competitor_scores[i] / total_score * 100.0,
		})
	# シェア降順ソート
	result.sort_custom(func(a, b): return a["share"] > b["share"])
	return result


## 競合の動向でプレイヤーに影響を与えるイベント判定
func check_competitive_events(gs) -> Dictionary:
	# 競合がプレイヤーを大きく引き離している場合
	var player_share = get_player_market_share(gs)
	if player_share < 10.0 and gs.users > 0:
		if randf() < 0.15:
			return {
				"title": "市場シェアの危機",
				"description": "競合他社にシェアを奪われている。巻き返しが必要だ。",
				"effect": "reputation",
				"value": -5,
			}
	# プレイヤーがトップの場合
	if player_share > 40.0:
		if randf() < 0.1:
			return {
				"title": "市場リーダーの座",
				"description": "業界トップのポジションを確立しつつある！",
				"effect": "reputation",
				"value": 10,
			}
	return {}


## リセット
func reset() -> void:
	competitor_scores.clear()
	for comp in COMPETITORS:
		competitor_scores.append(randf_range(500, 1500))
	total_market_size = 10000.0
	news_cooldown = 0


## セーブ用
func to_dict() -> Dictionary:
	return {
		"competitor_scores": competitor_scores.duplicate(),
		"total_market_size": total_market_size,
		"news_cooldown": news_cooldown,
	}


## ロード用
func from_dict(data: Dictionary) -> void:
	var scores = data.get("competitor_scores", [])
	competitor_scores.clear()
	for s in scores:
		competitor_scores.append(s)
	while competitor_scores.size() < COMPETITORS.size():
		competitor_scores.append(randf_range(500, 1500))
	total_market_size = data.get("total_market_size", 10000.0)
	news_cooldown = data.get("news_cooldown", 0)
