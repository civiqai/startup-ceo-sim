extends Node
class_name EventManager
## ランダムイベントを管理（カテゴリ分け・選択肢・チェイン対応）

signal event_triggered(event_data: Dictionary)

enum Category {
	MANAGEMENT,  # 経営系
	TEAM,        # チーム系
	PRODUCT,     # プロダクト系
	MARKET,      # 市場系
	RANDOM,      # ランダム系
}

## イベントデータ構造:
## {
##   "id": String,                    # ユニークID
##   "title": String,
##   "description": String,
##   "category": Category,
##   "effect": Callable,              # 効果 (gs: GameState) -> String（効果説明を返す）
##   "choices": Array[Dictionary],    # 選択肢（空なら「OK」ボタンのみ）
##     choice: { "label": String, "effect": Callable, "chain_event_id": String }
##   "chain_event_id": String,        # 次ターンに発生する連鎖イベントID（空なら無し）
##   "condition": Callable,           # 発生条件 (gs: GameState) -> bool
##   "weight": float,                 # 発生重み（大きいほど出やすい）
## }

var events: Dictionary = {}  # id -> event_data
var pending_chain_events: Array[String] = []  # 次ターンに発生する連鎖イベントID


func _ready() -> void:
	_register_all_events()


## 連鎖イベントがあればそれを返し、なければ確率でランダムイベントを返す
func try_random_event() -> Dictionary:
	# 連鎖イベント優先
	if pending_chain_events.size() > 0:
		var chain_id = pending_chain_events.pop_front()
		if events.has(chain_id):
			return events[chain_id]

	# 40%の確率でイベント発生
	if randf() > 0.4:
		return {}

	var gs = GameState
	var candidates: Array[Dictionary] = []
	var total_weight := 0.0

	for event in events.values():
		# 連鎖専用イベント（chain_onlyフラグ）はランダムでは出ない
		if event.get("chain_only", false):
			continue
		# 条件チェック
		if event.has("condition") and event["condition"] is Callable:
			if not event["condition"].call(gs):
				continue
		candidates.append(event)
		total_weight += event.get("weight", 1.0)

	if candidates.is_empty():
		return {}

	# 重み付きランダム選択
	var roll = randf() * total_weight
	var cumulative := 0.0
	for event in candidates:
		cumulative += event.get("weight", 1.0)
		if roll <= cumulative:
			return event

	return candidates.back()


## イベント効果を適用（選択肢なしの場合）
func apply_event_effect(event_data: Dictionary) -> String:
	var effect_text := ""
	if event_data.has("effect") and event_data["effect"] is Callable:
		effect_text = event_data["effect"].call(GameState)
	# 連鎖イベント登録
	if event_data.get("chain_event_id", "") != "":
		pending_chain_events.append(event_data["chain_event_id"])
	return effect_text


## 選択肢の効果を適用
func apply_choice_effect(choice: Dictionary) -> String:
	var effect_text := ""
	if choice.has("effect") and choice["effect"] is Callable:
		effect_text = choice["effect"].call(GameState)
	# 連鎖イベント登録
	if choice.get("chain_event_id", "") != "":
		pending_chain_events.append(choice["chain_event_id"])
	return effect_text


## ゲームリセット時に連鎖イベントもクリア
func reset() -> void:
	pending_chain_events.clear()


func _register_all_events() -> void:
	_register_management_events()
	_register_team_events()
	_register_product_events()
	_register_market_events()
	_register_random_events()
	_register_bizdev_events()


# ============================================================
# 経営系イベント
# ============================================================
func _register_management_events() -> void:
	events["fundraise_success"] = {
		"id": "fundraise_success",
		"title": "資金調達成功",
		"description": "著名VCからの出資が決まった！大型ラウンドのクローズだ。",
		"category": Category.MANAGEMENT,
		"weight": 1.0,
		"condition": func(gs): return gs.reputation >= 40,
		"choices": [
			{
				"label": "全額受け入れる（資金+1500万、評判+10）",
				"effect": func(gs):
					gs.cash += 1500
					gs.reputation = mini(gs.reputation + 10, 100)
					return "1500万円の資金を調達した！",
			},
			{
				"label": "一部だけ受ける（資金+700万、評判+20）",
				"effect": func(gs):
					gs.cash += 700
					gs.reputation = mini(gs.reputation + 20, 100)
					return "慎重な姿勢が投資家に好印象を与えた。",
			},
		],
	}

	events["fundraise_failure"] = {
		"id": "fundraise_failure",
		"title": "資金調達失敗",
		"description": "投資家との交渉が決裂してしまった…市場の評価が厳しい。",
		"category": Category.MANAGEMENT,
		"weight": 1.0,
		"condition": func(gs): return gs.reputation < 50,
		"effect": func(gs):
			gs.reputation = maxi(gs.reputation - 10, 0)
			gs.team_morale = maxi(gs.team_morale - 10, 0)
			return "評判 -10、チーム士気 -10",
	}

	events["big_contract"] = {
		"id": "big_contract",
		"title": "大型契約",
		"description": "大手企業からエンタープライズ契約のオファーが来た！",
		"category": Category.MANAGEMENT,
		"weight": 0.8,
		"condition": func(gs): return gs.product_power >= 30 and gs.users >= 100,
		"choices": [
			{
				"label": "受注する（資金+2000万、プロダクト力-5）",
				"effect": func(gs):
					gs.cash += 2000
					gs.add_product_power(-5)
					return "大型契約を締結！カスタマイズ対応でプロダクト力が少し下がった。",
				"chain_event_id": "big_contract_followup",
			},
			{
				"label": "断る（評判+15）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 15, 100)
					return "自社プロダクトに集中する姿勢が評価された。",
			},
		],
	}

	events["big_contract_followup"] = {
		"id": "big_contract_followup",
		"title": "大型契約の余波",
		"description": "大手企業の要望対応に追われている。チームの負担が増している。",
		"category": Category.MANAGEMENT,
		"chain_only": true,
		"weight": 1.0,
		"choices": [
			{
				"label": "残業で乗り切る（士気-20、資金+500万）",
				"effect": func(gs):
					gs.team_morale = maxi(gs.team_morale - 20, 0)
					gs.cash += 500
					return "なんとか納品完了。しかしチームは疲弊している。",
			},
			{
				"label": "外注する（資金-300万、士気維持）",
				"effect": func(gs):
					gs.cash -= 300
					return "外注で対応。コストはかかったがチームへの負担は抑えられた。",
			},
		],
	}

	events["lawsuit"] = {
		"id": "lawsuit",
		"title": "訴訟リスク",
		"description": "競合他社から特許侵害の警告書が届いた。",
		"category": Category.MANAGEMENT,
		"weight": 0.5,
		"condition": func(gs): return gs.product_power >= 40,
		"choices": [
			{
				"label": "弁護士に相談する（資金-300万、安全に解決）",
				"effect": func(gs):
					gs.cash -= 300
					return "弁護士と共に対応し、問題を解決した。",
			},
			{
				"label": "無視する（50%で資金-800万）",
				"effect": func(gs):
					if randf() < 0.5:
						gs.cash -= 800
						gs.reputation = maxi(gs.reputation - 15, 0)
						return "訴訟に発展！大きな損害を被った。資金-800万、評判-15"
					else:
						return "幸い、先方が訴訟を取り下げた。事なきを得た。",
			},
		],
	}

	events["office_move"] = {
		"id": "office_move",
		"title": "オフィス移転",
		"description": "手狭になってきた。新しいオフィスに移転するチャンスだ。",
		"category": Category.MANAGEMENT,
		"weight": 0.7,
		"condition": func(gs): return gs.team_size >= 4,
		"choices": [
			{
				"label": "移転する（資金-500万、士気+20、評判+10）",
				"effect": func(gs):
					gs.cash -= 500
					gs.team_morale = mini(gs.team_morale + 20, 100)
					gs.reputation = mini(gs.reputation + 10, 100)
					return "新オフィスに移転！チームの士気と評判が上がった。",
			},
			{
				"label": "現状維持（士気-5）",
				"effect": func(gs):
					gs.team_morale = maxi(gs.team_morale - 5, 0)
					return "狭いオフィスでの作業が続き、少し士気が下がった。",
			},
		],
	}

	events["vc_direction_change"] = {
		"id": "vc_direction_change",
		"title": "VCからの方向転換要請",
		"description": "主要投資家から事業の方向転換を求められた。「もっとB2B寄りにピボットすべきだ」",
		"category": Category.MANAGEMENT,
		"weight": 0.8,
		"condition": func(gs): return gs.equity_share < 80.0 and gs.equity_share > 0,
		"choices": [
			{
				"label": "受け入れる（士気-15、評判+10）",
				"effect": func(gs):
					gs.team_morale = maxi(gs.team_morale - 15, 0)
					gs.reputation = mini(gs.reputation + 10, 100)
					return "VCの要請を受け入れた。チームの士気が下がった。",
			},
			{
				"label": "拒否する（評判-20）",
				"effect": func(gs):
					gs.reputation = maxi(gs.reputation - 20, 0)
					return "VCの要請を拒否。関係が悪化した。",
			},
		],
	}

	events["vc_board_seat"] = {
		"id": "vc_board_seat",
		"title": "取締役会の圧力",
		"description": "投資家が取締役の派遣を要求している。経営の自由度が制限される可能性が…",
		"category": Category.MANAGEMENT,
		"weight": 0.6,
		"condition": func(gs): return gs.equity_share < 60.0,
		"choices": [
			{
				"label": "受け入れる（評判+15、士気-10）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 15, 100)
					gs.team_morale = maxi(gs.team_morale - 10, 0)
					return "社外取締役を受け入れた。投資家との関係は改善したが…",
			},
			{
				"label": "拒否する（評判-10）",
				"effect": func(gs):
					gs.reputation = maxi(gs.reputation - 10, 0)
					return "自主独立を貫いた。",
			},
		],
	}

	events["loss_of_control"] = {
		"id": "loss_of_control",
		"title": "経営権の危機",
		"description": "持ち株比率が50%を切り、投資家陣営が経営陣の交代を要求している！",
		"category": Category.MANAGEMENT,
		"weight": 1.5,
		"condition": func(gs): return gs.equity_share < 50.0,
		"choices": [
			{
				"label": "株式の買い戻し（資金-2000万）",
				"effect": func(gs):
					if gs.cash >= 2000:
						gs.cash -= 2000
						gs.equity_share = minf(gs.equity_share + 10.0, 100.0)
						return "2000万円で10%%の株式を買い戻した。持株 %.1f%%" % gs.equity_share
					else:
						gs.team_morale = maxi(gs.team_morale - 20, 0)
						return "資金不足で買い戻せなかった…士気 -20",
			},
			{
				"label": "受け入れて経営を続ける（士気-25）",
				"effect": func(gs):
					gs.team_morale = maxi(gs.team_morale - 25, 0)
					return "投資家の影響力が増大。チーム全体が動揺している。",
			},
		],
	}

# ============================================================
# チーム系イベント
# ============================================================
func _register_team_events() -> void:
	events["ace_join"] = {
		"id": "ace_join",
		"title": "エース社員獲得",
		"description": "業界で有名なエンジニアが入社を希望している！",
		"category": Category.TEAM,
		"weight": 0.6,
		"condition": func(gs): return gs.reputation >= 50,
		"choices": [
			{
				"label": "高待遇で迎える（資金-400万、チーム+1、プロダクト力+15）",
				"effect": func(gs):
					gs.cash -= 400
					gs.add_random_member()
					gs.add_product_power(15)
					gs.team_morale = mini(gs.team_morale + 10, 100)
					return "エースエンジニアが参画！プロダクト力が大幅UP。",
			},
			{
				"label": "通常条件で提案（50%で入社）",
				"effect": func(gs):
					if randf() < 0.5:
						gs.add_random_member()
						gs.add_product_power(10)
						return "交渉成功！エースがチームに加わった。"
					else:
						return "条件が合わず、辞退されてしまった。",
			},
		],
	}

	events["team_conflict"] = {
		"id": "team_conflict",
		"title": "チーム内紛争",
		"description": "メンバー間で技術選定を巡って対立が起きている。",
		"category": Category.TEAM,
		"weight": 1.0,
		"condition": func(gs): return gs.team_size >= 3,
		"choices": [
			{
				"label": "話し合いの場を設ける（士気+5、プロダクト力-3）",
				"effect": func(gs):
					gs.team_morale = mini(gs.team_morale + 5, 100)
					gs.add_product_power(-3)
					return "時間はかかったが、チームの結束が強まった。",
			},
			{
				"label": "トップダウンで決める（士気-15、開発スピード維持）",
				"effect": func(gs):
					gs.team_morale = maxi(gs.team_morale - 15, 0)
					return "素早く方針を決定。しかし不満が残った。",
			},
		],
	}

	events["hackathon_win"] = {
		"id": "hackathon_win",
		"title": "ハッカソン優勝",
		"description": "チームメンバーが社外ハッカソンで優勝した！",
		"category": Category.TEAM,
		"weight": 0.7,
		"condition": func(gs): return gs.team_size >= 2 and gs.team_morale >= 50,
		"effect": func(gs):
			gs.reputation = mini(gs.reputation + 15, 100)
			gs.team_morale = mini(gs.team_morale + 10, 100)
			gs.add_product_power(5)
			return "評判+15、士気+10、プロダクト力+5",
	}

	events["burnout"] = {
		"id": "burnout",
		"title": "バーンアウト",
		"description": "長時間労働が続き、チーム全体に疲弊が広がっている…",
		"category": Category.TEAM,
		"weight": 1.2,
		"condition": func(gs): return gs.team_morale < 40,
		"choices": [
			{
				"label": "休暇を与える（プロダクト力-5、士気+25）",
				"effect": func(gs):
					gs.add_product_power(-5)
					gs.team_morale = mini(gs.team_morale + 25, 100)
					return "リフレッシュ休暇で士気が回復した。",
			},
			{
				"label": "そのまま続行（30%でメンバー離脱）",
				"effect": func(gs):
					if randf() < 0.3 and gs.team_size > 1:
						gs.remove_random_member()
						gs.team_morale = maxi(gs.team_morale - 10, 0)
						return "限界を迎えたメンバーが退職してしまった…"
					else:
						gs.team_morale = maxi(gs.team_morale - 5, 0)
						return "なんとか持ちこたえたが、士気はさらに下がった。",
			},
		],
	}

	events["member_leave"] = {
		"id": "member_leave",
		"title": "メンバー離脱",
		"description": "主要メンバーが退職を申し出てきた…",
		"category": Category.TEAM,
		"weight": 0.8,
		"condition": func(gs): return gs.team_size > 1,
		"choices": [
			{
				"label": "引き止める（資金-200万、残留）",
				"effect": func(gs):
					gs.cash -= 200
					gs.team_morale = mini(gs.team_morale + 5, 100)
					return "待遇改善で引き止めに成功した。",
			},
			{
				"label": "送り出す（チーム-1、士気-10）",
				"effect": func(gs):
					gs.remove_random_member()
					gs.team_morale = maxi(gs.team_morale - 10, 0)
					return "メンバーが去った。残されたチームの士気が下がった。",
			},
		],
	}

# ============================================================
# プロダクト系イベント
# ============================================================
func _register_product_events() -> void:
	events["bug_outbreak"] = {
		"id": "bug_outbreak",
		"title": "バグ大発生",
		"description": "本番環境で重大なバグが見つかった！ユーザーから苦情が殺到している。",
		"category": Category.PRODUCT,
		"weight": 1.0,
		"condition": func(gs):
			var pm = gs.get_node_or_null("/root/Main/Game/ProductManager")
			var debt = pm.tech_debt if pm != null else 30
			return gs.users >= 50 and debt >= 30,
		"choices": [
			{
				"label": "全力で修正（プロダクト力-5、ユーザー減少小）",
				"effect": func(gs):
					gs.add_product_power(-5)
					var lost = randi_range(10, 30)
					gs.users = maxi(gs.users - lost, 0)
					gs.brand_value = maxi(gs.brand_value - 5, 0)
					return "緊急パッチをリリース。ユーザー -%d人" % lost,
			},
			{
				"label": "段階的に修正（プロダクト力維持、ユーザー減少大）",
				"effect": func(gs):
					var lost = randi_range(50, 150)
					gs.users = maxi(gs.users - lost, 0)
					gs.reputation = maxi(gs.reputation - 5, 0)
					gs.brand_value = maxi(gs.brand_value - 5, 0)
					return "対応が遅れ、多くのユーザーが離脱。ユーザー -%d人" % lost,
			},
		],
	}

	events["patent"] = {
		"id": "patent",
		"title": "特許取得",
		"description": "申請していた技術特許が認められた！",
		"category": Category.PRODUCT,
		"weight": 0.5,
		"condition": func(gs): return gs.product_power >= 50,
		"effect": func(gs):
			gs.reputation = mini(gs.reputation + 20, 100)
			gs.add_product_power(5)
			return "評判+20、プロダクト力+5。技術力が広く認められた！",
	}

	events["api_down"] = {
		"id": "api_down",
		"title": "外部APIダウン",
		"description": "依存している外部APIが長時間ダウンしている！",
		"category": Category.PRODUCT,
		"weight": 0.8,
		"choices": [
			{
				"label": "代替APIに切り替え（資金-150万）",
				"effect": func(gs):
					gs.cash -= 150
					return "代替APIへの移行完了。サービスは復旧した。",
			},
			{
				"label": "復旧を待つ（ユーザー減少リスク）",
				"effect": func(gs):
					if randf() < 0.6:
						var lost = randi_range(30, 100)
						gs.users = maxi(gs.users - lost, 0)
						return "復旧まで時間がかかり、ユーザーが離脱。-%d人" % lost
					else:
						return "幸い短時間で復旧し、大きな影響はなかった。",
			},
		],
	}

	events["user_surge"] = {
		"id": "user_surge",
		"title": "ユーザー急増",
		"description": "口コミでプロダクトが話題になり、ユーザーが急増している！",
		"category": Category.PRODUCT,
		"weight": 0.7,
		"condition": func(gs): return gs.product_power >= 40 and gs.users >= 100,
		"choices": [
			{
				"label": "サーバー増強する（資金-200万、安定成長）",
				"effect": func(gs):
					gs.cash -= 200
					var gain = randi_range(300, 800)
					gs.users += gain
					return "インフラを増強しユーザーを受け入れた！ユーザー +%d人" % gain,
			},
			{
				"label": "現状のまま受け入れ（無料だがサービス不安定）",
				"effect": func(gs):
					var gain = randi_range(100, 300)
					gs.users += gain
					gs.reputation = maxi(gs.reputation - 5, 0)
					return "サーバーが不安定に。ユーザー+%d人だが評判-5" % gain,
				"chain_event_id": "server_trouble",
			},
		],
	}

	events["server_trouble"] = {
		"id": "server_trouble",
		"title": "サーバー障害",
		"description": "先月のユーザー急増の影響でサーバーがダウンした！",
		"category": Category.PRODUCT,
		"chain_only": true,
		"weight": 1.0,
		"effect": func(gs):
			gs.cash -= 100
			gs.reputation = maxi(gs.reputation - 10, 0)
			var lost = randi_range(50, 150)
			gs.users = maxi(gs.users - lost, 0)
			gs.brand_value = maxi(gs.brand_value - 5, 0)
			return "緊急対応費 -100万円、評判-10、ユーザー -%d人" % lost,
	}

	events["feature_viral"] = {
		"id": "feature_viral",
		"title": "新機能がバズった",
		"description": "リリースした新機能がSNSでバズっている！",
		"category": Category.PRODUCT,
		"weight": 0.6,
		"condition": func(gs): return gs.product_power >= 35,
		"effect": func(gs):
			var gain = randi_range(200, 600)
			gs.users += gain
			gs.reputation = mini(gs.reputation + 10, 100)
			gs.brand_value = mini(gs.brand_value + 5, 100)
			return "ユーザー +%d人、評判+10" % gain,
	}

	events["minor_bug"] = {
		"id": "minor_bug",
		"title": "バグ報告",
		"description": "ユーザーから複数のバグ報告が上がっている。技術的負債の影響か…",
		"category": Category.PRODUCT,
		"weight": 1.2,
		"condition": func(gs):
			var pm = gs.get_node_or_null("/root/Main/Game/ProductManager")
			return pm != null and pm.tech_debt >= 50 and pm.tech_debt < 70,
		"effect": func(gs):
			var lost = randi_range(50, 200)
			gs.users = maxi(gs.users - lost, 0)
			gs.team_morale = maxi(gs.team_morale - 5, 0)
			return "ユーザー離脱 -%d人、士気 -5" % lost,
	}

	events["major_incident"] = {
		"id": "major_incident",
		"title": "重大システム障害",
		"description": "サービスが数時間ダウンした！技術的負債が限界に達している。",
		"category": Category.PRODUCT,
		"weight": 1.5,
		"condition": func(gs):
			var pm = gs.get_node_or_null("/root/Main/Game/ProductManager")
			return pm != null and pm.tech_debt >= 70 and pm.tech_debt < 90,
		"choices": [
			{
				"label": "緊急対応する（資金-300万、負債-20）",
				"effect": func(gs):
					gs.cash -= 300
					var pm = gs.get_node_or_null("/root/Main/Game/ProductManager")
					if pm: pm.tech_debt = maxi(pm.tech_debt - 20, 0)
					gs.users = maxi(gs.users - randi_range(200, 500), 0)
					return "緊急パッチで復旧。ユーザー離脱あり。",
			},
			{
				"label": "様子を見る（ユーザー大量離脱）",
				"effect": func(gs):
					var lost = randi_range(500, 1500)
					gs.users = maxi(gs.users - lost, 0)
					gs.reputation = maxi(gs.reputation - 10, 0)
					return "復旧に時間がかかり、%d人のユーザーが離脱。評判 -10" % lost,
			},
		],
	}

	events["system_down"] = {
		"id": "system_down",
		"title": "大規模システムダウン",
		"description": "技術的負債が爆発！サービス全体が丸1日停止した。ニュースにもなっている…",
		"category": Category.PRODUCT,
		"weight": 2.0,
		"condition": func(gs):
			var pm = gs.get_node_or_null("/root/Main/Game/ProductManager")
			return pm != null and pm.tech_debt >= 90,
		"effect": func(gs):
			var lost = randi_range(1000, 5000)
			gs.users = maxi(gs.users - lost, 0)
			gs.reputation = maxi(gs.reputation - 20, 0)
			gs.brand_value = maxi(gs.brand_value - 15, 0)
			gs.team_morale = maxi(gs.team_morale - 15, 0)
			return "大規模障害で%d人離脱！評判-20、ブランド-15、士気-15" % lost,
	}

# ============================================================
# 市場系イベント
# ============================================================
func _register_market_events() -> void:
	events["recession"] = {
		"id": "recession",
		"title": "景気後退",
		"description": "マクロ経済の悪化で投資環境が冷え込んでいる。",
		"category": Category.MARKET,
		"weight": 0.6,
		"effect": func(gs):
			gs.reputation = maxi(gs.reputation - 15, 0)
			gs.cash -= randi_range(100, 300)
			gs.cash = maxi(gs.cash, 0)
			return "評判-15、資金減少。冬の時代を耐えよう。",
		"chain_event_id": "recession_followup",
	}

	events["recession_followup"] = {
		"id": "recession_followup",
		"title": "不況の長期化",
		"description": "景気後退が続いている。取引先からの支払いも遅延気味だ。",
		"category": Category.MARKET,
		"chain_only": true,
		"weight": 1.0,
		"choices": [
			{
				"label": "コスト削減する（チーム-1、資金節約）",
				"effect": func(gs):
					if gs.team_size > 1:
						gs.remove_random_member()
						gs.team_morale = maxi(gs.team_morale - 15, 0)
						return "苦渋の決断でリストラを実施。"
					else:
						gs.team_morale = maxi(gs.team_morale - 5, 0)
						return "一人しかいないため削減できない…",
			},
			{
				"label": "耐える（資金-200万）",
				"effect": func(gs):
					gs.cash -= 200
					gs.cash = maxi(gs.cash, 0)
					return "歯を食いしばって耐えた。資金-200万。",
			},
		],
	}

	events["regulation_change"] = {
		"id": "regulation_change",
		"title": "規制変更",
		"description": "業界に新しい規制が導入されることになった。",
		"category": Category.MARKET,
		"weight": 0.5,
		"choices": [
			{
				"label": "素早く対応する（資金-200万、評判+15）",
				"effect": func(gs):
					gs.cash -= 200
					gs.reputation = mini(gs.reputation + 15, 100)
					return "いち早く規制に対応。業界でのポジションが向上した。",
			},
			{
				"label": "様子を見る（後で対応コスト増のリスク）",
				"effect": func(gs):
					if randf() < 0.4:
						gs.cash -= 400
						gs.reputation = maxi(gs.reputation - 10, 0)
						return "対応が遅れ、追加コストが発生。資金-400万、評判-10"
					else:
						return "規制の影響は思ったより小さく、大きな問題にはならなかった。",
			},
		],
	}

	events["industry_conference"] = {
		"id": "industry_conference",
		"title": "業界カンファレンス",
		"description": "大規模な業界カンファレンスへの登壇依頼が来た。",
		"category": Category.MARKET,
		"weight": 0.8,
		"condition": func(gs): return gs.reputation >= 30,
		"choices": [
			{
				"label": "登壇する（評判+20、ユーザー増）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 20, 100)
					var gain = randi_range(100, 300)
					gs.users += gain
					gs.brand_value = mini(gs.brand_value + 10, 100)
					return "カンファレンスで大注目！評判+20、ユーザー+%d人" % gain,
			},
			{
				"label": "見送る（開発に集中、プロダクト力+5）",
				"effect": func(gs):
					gs.add_product_power(5)
					return "登壇を見送り開発に集中した。プロダクト力+5",
			},
		],
	}

	events["competitor_acquisition"] = {
		"id": "competitor_acquisition",
		"title": "競合が買収された",
		"description": "主要な競合他社が大手企業に買収された。市場が動いている。",
		"category": Category.MARKET,
		"weight": 0.5,
		"choices": [
			{
				"label": "攻勢に出る（資金-300万、ユーザー急増）",
				"effect": func(gs):
					gs.cash -= 300
					var gain = randi_range(200, 500)
					gs.users += gain
					return "競合の顧客を獲得！ユーザー +%d人" % gain,
			},
			{
				"label": "慎重に様子を見る（評判+5）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 5, 100)
					return "市場の動向を慎重に分析した。評判+5",
			},
		],
	}

# ============================================================
# ランダム系イベント
# ============================================================
func _register_random_events() -> void:
	events["typhoon"] = {
		"id": "typhoon",
		"title": "台風で出社不能",
		"description": "大型台風が直撃！オフィスに行けない…",
		"category": Category.RANDOM,
		"weight": 0.6,
		"choices": [
			{
				"label": "リモートワークに切り替え（プロダクト力-3）",
				"effect": func(gs):
					gs.add_product_power(-3)
					return "リモートで対応したが、開発効率は少し落ちた。",
			},
			{
				"label": "休みにする（士気+10）",
				"effect": func(gs):
					gs.team_morale = mini(gs.team_morale + 10, 100)
					return "思い切って休日にした。チームのリフレッシュに。",
			},
		],
	}

	events["celebrity_tweet"] = {
		"id": "celebrity_tweet",
		"title": "有名人がツイート",
		"description": "有名インフルエンサーがプロダクトを絶賛ツイートした！",
		"category": Category.RANDOM,
		"weight": 0.5,
		"condition": func(gs): return gs.users >= 50,
		"effect": func(gs):
			var gain = randi_range(500, 1500)
			gs.users += gain
			gs.reputation = mini(gs.reputation + 10, 100)
			gs.brand_value = mini(gs.brand_value + 8, 100)
			return "バズが発生！ユーザー +%d人、評判+10" % gain,
		"chain_event_id": "media_coverage",
	}

	events["media_coverage"] = {
		"id": "media_coverage",
		"title": "取材依頼",
		"description": "SNSでの話題を受けて、テックメディアから取材依頼が来た。",
		"category": Category.RANDOM,
		"chain_only": true,
		"weight": 1.0,
		"choices": [
			{
				"label": "取材を受ける（評判+15、ユーザー増）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 15, 100)
					var gain = randi_range(200, 500)
					gs.users += gain
					gs.brand_value = mini(gs.brand_value + 7, 100)
					return "メディア掲載で知名度UP！評判+15、ユーザー+%d人" % gain,
			},
			{
				"label": "丁重にお断り（ステルスモード維持）",
				"effect": func(gs):
					gs.add_product_power(3)
					return "開発に集中。プロダクト力+3",
			},
		],
	}

	events["intern_discovery"] = {
		"id": "intern_discovery",
		"title": "インターン生の大発見",
		"description": "インターン生が画期的なアルゴリズムを発見した！",
		"category": Category.RANDOM,
		"weight": 0.4,
		"condition": func(gs): return gs.team_size >= 3,
		"effect": func(gs):
			gs.add_product_power(10)
			gs.team_morale = mini(gs.team_morale + 10, 100)
			return "プロダクト力+10、士気+10。若い才能に脱帽！",
	}

	events["lucky_encounter"] = {
		"id": "lucky_encounter",
		"title": "幸運な出会い",
		"description": "カフェで偶然、業界の重鎮と隣り合わせになった。",
		"category": Category.RANDOM,
		"weight": 0.5,
		"effect": func(gs):
			gs.reputation = mini(gs.reputation + randi_range(5, 15), 100)
			return "名刺交換に成功。人脈が広がった！",
	}

	events["office_pet"] = {
		"id": "office_pet",
		"title": "オフィスに猫が住み着いた",
		"description": "どこからか猫がオフィスに住み着いた。チームのアイドルになっている。",
		"category": Category.RANDOM,
		"weight": 0.4,
		"effect": func(gs):
			gs.team_morale = mini(gs.team_morale + 15, 100)
			return "士気+15。猫の癒し効果は絶大だ。",
	}

	events["power_outage"] = {
		"id": "power_outage",
		"title": "大規模停電",
		"description": "地域一帯で大規模停電が発生！サーバーも開発環境も止まった。",
		"category": Category.RANDOM,
		"weight": 0.5,
		"effect": func(gs):
			gs.add_product_power(-3)
			var lost = randi_range(10, 50)
			gs.users = maxi(gs.users - lost, 0)
			return "プロダクト力-3、ユーザー-%d人。復旧に丸一日かかった。" % lost,
	}

# ============================================================
# BizDev協業イベント（BizDevメンバーがいる場合に発生）
# ============================================================
func _register_bizdev_events() -> void:
	events["bizdev_collab_saas"] = {
		"id": "bizdev_collab_saas",
		"title": "SaaS企業との協業提案",
		"description": "大手SaaS企業から、API連携による協業の提案が来た。BizDevチームが交渉中だ。",
		"category": Category.MANAGEMENT,
		"weight": 0.8,
		"condition": func(gs): return TeamManager.get_skill_bonus("bizdev") >= 2,
		"choices": [
			{
				"label": "協業する（売上+150万、ブランド+8、開発工数あり）",
				"effect": func(gs):
					gs.cash += 150
					gs.brand_value = mini(gs.brand_value + 8, 100)
					gs.add_product_power(-3)
					return "SaaS協業が成立！売上+150万、ブランド+8（開発工数で力-3）",
			},
			{
				"label": "見送る（評判+5）",
				"effect": func(gs):
					gs.reputation = mini(gs.reputation + 5, 100)
					return "慎重な判断が評価された。評判+5",
			},
		],
	}

	events["bizdev_reseller"] = {
		"id": "bizdev_reseller",
		"title": "代理店契約のオファー",
		"description": "販売代理店が自社プロダクトを取り扱いたいと申し出ている。",
		"category": Category.MANAGEMENT,
		"weight": 0.7,
		"condition": func(gs): return TeamManager.get_skill_bonus("bizdev") >= 3 and gs.product_power >= 25,
		"choices": [
			{
				"label": "契約する（毎月の売上基盤UP、ユーザー+200）",
				"effect": func(gs):
					var revenue_boost = randi_range(100, 250)
					gs.cash += revenue_boost
					gs.users += 200
					gs.brand_value = mini(gs.brand_value + 5, 100)
					return "代理店契約成立！売上+%d万、ユーザー+200、ブランド+5" % revenue_boost,
			},
			{
				"label": "条件交渉する（50%で好条件、50%で破談）",
				"effect": func(gs):
					if randf() < 0.5:
						var revenue_boost = randi_range(200, 400)
						gs.cash += revenue_boost
						gs.users += 300
						gs.brand_value = mini(gs.brand_value + 8, 100)
						return "好条件で合意！売上+%d万、ユーザー+300" % revenue_boost
					else:
						gs.reputation = maxi(gs.reputation - 5, 0)
						return "交渉決裂…評判-5",
			},
		],
	}

	events["bizdev_govt_contract"] = {
		"id": "bizdev_govt_contract",
		"title": "官公庁案件",
		"description": "BizDevチームが自治体のDX案件を発見。入札に参加できそうだ。",
		"category": Category.MANAGEMENT,
		"weight": 0.5,
		"condition": func(gs): return TeamManager.get_skill_bonus("bizdev") >= 4 and gs.reputation >= 40,
		"choices": [
			{
				"label": "入札する（資金-100万、70%で大型案件獲得）",
				"effect": func(gs):
					gs.cash -= 100
					if randf() < 0.7:
						var contract_value = randi_range(500, 1000)
						gs.cash += contract_value
						gs.reputation = mini(gs.reputation + 15, 100)
						return "落札成功！官公庁案件 +%d万円、評判+15" % contract_value
					else:
						return "惜しくも落選…入札費用-100万",
			},
			{
				"label": "見送る",
				"effect": func(gs):
					return "今回は見送った。",
			},
		],
	}

	events["bizdev_overseas_lead"] = {
		"id": "bizdev_overseas_lead",
		"title": "海外企業からの問い合わせ",
		"description": "海外のテック企業から製品への問い合わせが来た。BizDevが対応している。",
		"category": Category.MARKET,
		"weight": 0.6,
		"condition": func(gs): return TeamManager.get_skill_bonus("bizdev") >= 3 and gs.users >= 1000,
		"choices": [
			{
				"label": "商談を進める（売上+200万、ブランド+10）",
				"effect": func(gs):
					gs.cash += 200
					gs.brand_value = mini(gs.brand_value + 10, 100)
					gs.reputation = mini(gs.reputation + 8, 100)
					gs.users += randi_range(100, 300)
					return "海外との取引が成立！売上+200万、ブランド+10、海外ユーザー獲得",
			},
			{
				"label": "国内に集中する",
				"effect": func(gs):
					gs.add_product_power(3)
					return "国内市場に集中。プロダクト力+3",
			},
		],
	}

	events["bizdev_revenue_share"] = {
		"id": "bizdev_revenue_share",
		"title": "レベニューシェア提案",
		"description": "有力企業からレベニューシェアモデルでの提携を持ちかけられた。",
		"category": Category.MANAGEMENT,
		"weight": 0.7,
		"condition": func(gs): return TeamManager.get_skill_bonus("bizdev") >= 2 and gs.product_power >= 30,
		"choices": [
			{
				"label": "提携する（売上シェア開始、ユーザー大幅増）",
				"effect": func(gs):
					var user_gain = randi_range(200, 500)
					var rev_share = randi_range(80, 200)
					gs.users += user_gain
					gs.cash += rev_share
					gs.brand_value = mini(gs.brand_value + 6, 100)
					return "レベニューシェア提携成立！ユーザー+%d、売上+%d万" % [user_gain, rev_share],
			},
			{
				"label": "独自路線を貫く（プロダクト力+5）",
				"effect": func(gs):
					gs.add_product_power(5)
					return "独立した路線で勝負。プロダクト力+5",
			},
		],
	}

	# COOがいる場合のボーナスイベント
	events["coo_optimization"] = {
		"id": "coo_optimization",
		"title": "COOによる業務改善",
		"description": "COOが業務プロセスの最適化を提案。コスト削減と効率化が見込める。",
		"category": Category.MANAGEMENT,
		"weight": 0.8,
		"condition": func(gs): return TeamManager.has_cxo("bizdev"),
		"effect": func(gs):
			var cost_save = randi_range(50, 150)
			gs.cash += cost_save
			gs.team_morale = mini(gs.team_morale + 5, 100)
			return "業務最適化でコスト削減 +%d万円、士気+5" % cost_save,
	}
