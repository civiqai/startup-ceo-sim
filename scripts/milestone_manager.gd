extends Node
## マイルストーン管理
## ゲーム進行中に達成条件をチェックし、初回達成時にシグナルを発火する

signal milestone_achieved(milestone_data: Dictionary)

# 達成済みマイルストーンIDリスト
var achieved: Array[String] = []

# マイルストーン定義
const MILESTONES := [
	{
		"id": "revenue_100",
		"title": "MRR 100万円突破！",
		"description": "月間売上が100万円を超えました。プロダクトが市場に受け入れられ始めています。",
		"icon": "💰",
		"field": "revenue",
		"threshold": 100,
	},
	{
		"id": "users_1000",
		"title": "ユーザー1,000人突破！",
		"description": "1,000人のユーザーがあなたのプロダクトを使っています。PMFの兆しです！",
		"icon": "👥",
		"field": "users",
		"threshold": 1000,
	},
	{
		"id": "users_10000",
		"title": "ユーザー10,000人突破！",
		"description": "1万ユーザー達成！グロースフェーズに突入しました。",
		"icon": "🚀",
		"field": "users",
		"threshold": 10000,
	},
	{
		"id": "team_10",
		"title": "チーム10人達成！",
		"description": "組織が拡大し、本格的なスタートアップになってきました。",
		"icon": "🏢",
		"field": "team_size",
		"threshold": 10,
	},
	{
		"id": "raised_5000",
		"title": "シリーズA調達完了！",
		"description": "累計5,000万円の調達に成功。事業拡大のための資金が整いました。",
		"icon": "💵",
		"field": "total_raised",
		"threshold": 5000,
	},
	{
		"id": "valuation_100000",
		"title": "時価総額10億円突破！",
		"description": "企業価値が10億円を超えました。IPOが視野に入ってきます。",
		"icon": "📈",
		"field": "valuation",
		"threshold": 100000,
	},
	{
		"id": "brand_50",
		"title": "ブランド力50突破！",
		"description": "業界での認知度が高まり、強いブランドが確立されてきました。",
		"icon": "⭐",
		"field": "brand_value",
		"threshold": 50,
	},
]


## GameStateの現在値をチェックし、未達成のマイルストーンで初めて条件を満たしたものを返す
## 1ターンに1つずつ表示するため、最初に見つかった1つだけ返す
func check_milestones(gs) -> Dictionary:
	for m in MILESTONES:
		var mid: String = m["id"]
		if mid in achieved:
			continue
		var field: String = m["field"]
		var threshold: int = m["threshold"]
		var current_value: int = gs.get(field)
		if current_value >= threshold:
			achieved.append(mid)
			var data := {
				"id": mid,
				"title": m["title"],
				"description": m["description"],
				"icon": m["icon"],
			}
			milestone_achieved.emit(data)
			return data
	return {}


## ゲームリセット時に達成状況もクリア
func reset() -> void:
	achieved.clear()
