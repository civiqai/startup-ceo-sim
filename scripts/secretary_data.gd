extends RefCounted
## 秘書・あかりの台詞データ定義


## チュートリアルシーケンス（初回起動時に表示）
static func get_tutorial_sequence() -> Array:
	return [
		{"id": "welcome", "icon": "👩‍💼", "name": "秘書・あかり", "text": "社長、はじめまして！秘書のあかりです。\n今日からあなたの経営をサポートします！"},
		{"id": "explain_goal", "icon": "👩‍💼", "name": "秘書・あかり", "text": "目標は時価総額100億円を達成してIPOすること。\n資金がゼロになるとゲームオーバーです。"},
		{"id": "explain_actions", "icon": "👩‍💼", "name": "秘書・あかり", "text": "毎月1つアクションを選べます。\n開発・採用・マーケティング・資金調達・チームケアの5つです。"},
		{"id": "explain_params", "icon": "👩‍💼", "name": "秘書・あかり", "text": "プロダクト力を上げてユーザーを集め、\n売上を伸ばしていきましょう！"},
		{"id": "first_advice", "icon": "👩‍💼", "name": "秘書・あかり", "text": "まずは「採用」で最初の仲間を見つけましょう！\nエンジニアがいないと開発が進みませんよ。"},
	]


## 状況に応じたアドバイス（条件を満たしたとき表示）
static func get_contextual_advices() -> Array:
	return [
		{"id": "low_cash", "condition": "cash_below_200", "icon": "👩‍💼", "name": "秘書・あかり", "text": "社長、資金が残りわずかです！\n資金調達を検討しましょう。", "priority": 10},
		{"id": "low_morale", "condition": "morale_below_30", "icon": "👩‍💼", "name": "秘書・あかり", "text": "チームの士気が低下しています…\nチームケアで立て直しましょう。", "priority": 9},
		{"id": "no_users_3turns", "condition": "no_users_3_months", "icon": "👩‍💼", "name": "秘書・あかり", "text": "まだユーザーがいませんね。\nマーケティングでユーザーを獲得しましょう！", "priority": 8},
		{"id": "no_team", "condition": "team_size_1_month_3", "icon": "👩‍💼", "name": "秘書・あかり", "text": "まだお一人ですね。\nそろそろ仲間を採用してみませんか？", "priority": 7},
		{"id": "high_product", "condition": "product_50_no_marketing", "icon": "👩‍💼", "name": "秘書・あかり", "text": "プロダクト力が十分です！\nマーケティングでユーザーを増やしましょう。", "priority": 6},
		{"id": "milestone_hint", "condition": "valuation_near_ipo", "icon": "👩‍💼", "name": "秘書・あかり", "text": "IPOが見えてきました！\nこの調子で売上とユーザーを伸ばしましょう！", "priority": 5},
	]


## イベント後の秘書コメンタリー（イベントID → 解説テキスト＋優先度）
const EVENT_COMMENTARY := {
	"fundraise_success": {
		"text": "資金調達おめでとうございます！大事なのは調達した資金の使い道です。闇雲に使わず、プロダクト開発かチーム強化に集中投資しましょう。",
		"priority": 2,
	},
	"fundraise_failure": {
		"text": "資金調達に失敗しても大丈夫です。プロダクトの数字を伸ばせば、投資家の方から声がかかります。まずはユーザー獲得に集中しましょう。",
		"priority": 3,
	},
	"big_contract": {
		"text": "大型契約はキャッシュフローの改善に最適ですが、カスタマイズに時間を取られるリスクもあります。プロダクトの方向性とのバランスを考えましょう。",
		"priority": 2,
	},
	"team_conflict": {
		"text": "チーム内の対立は成長痛です。対話で解決するのが一番ですが、放置すると離職に繋がります。早めの対応を。",
		"priority": 3,
	},
	"ace_join": {
		"text": "優秀な人材の採用は会社の成長を加速します。ただし、高待遇での採用はバーンレートを上げるので、ランウェイに注意してください。",
		"priority": 2,
	},
	"bug_outbreak": {
		"text": "バグの多発は技術的負債のサインです。定期的にリファクタリングの時間を確保しましょう。CTOがいると効率が上がります。",
		"priority": 3,
	},
	"viral_feature": {
		"text": "バイラルの波に乗れました！この機会を逃さず、マーケティング施策を打ちましょう。ユーザー獲得コストが通常より安く済みます。",
		"priority": 2,
	},
	"member_leave": {
		"text": "メンバーの離脱は辛いですが、チームケアで残ったメンバーの士気を回復しましょう。士気が低いと連鎖離脱のリスクがあります。",
		"priority": 3,
	},
	"competitor_news": {
		"text": "競合の動きに注目しましょう。ただし、競合に振り回されすぎず、自社の強みを磨くことが大切です。",
		"priority": 1,
	},
	"lawsuit": {
		"text": "訴訟リスクは事業が大きくなると避けられません。弁護士への相談費用は保険と考えましょう。無視は最悪の選択肢です。",
		"priority": 3,
	},
	"vc_direction_change": {
		"text": "VCからの方向転換要請は、株式を渡しすぎた結果です。持ち株比率は最低でも51%以上を維持するのが理想です。",
		"priority": 3,
	},
	"loss_of_control": {
		"text": "経営権の危機です！持ち株比率が50%を切ると、投資家に経営を左右されます。今後のエクイティ調達は慎重に。",
		"priority": 4,
	},
	"minor_bug": {
		"text": "技術的負債が溜まってきています。「開発に集中」でリファクタリングを選ぶか、CTOの採用を検討しましょう。",
		"priority": 3,
	},
	"major_incident": {
		"text": "重大障害はユーザー離脱に直結します。技術的負債の返済を最優先にしてください。これ以上放置すると取り返しがつきません。",
		"priority": 4,
	},
	"system_down": {
		"text": "大規模障害は会社の信用を大きく損ないます。全力でリファクタリングに取り組んでください。エンジニアの増員も検討を。",
		"priority": 5,
	},
}


## 状況別アドバイス（GameStateの状態に応じた定期アドバイス）
const SITUATION_ADVICE := [
	{
		"id": "low_cash",
		"condition_desc": "資金残り3ヶ月以内",
		"text": "資金がかなり厳しい状況です！受託開発で一時的な収入を確保するか、資金調達を検討しましょう。不要な人員の整理も選択肢に入れてください。",
		"priority": 5,
		"cooldown": 3,
	},
	{
		"id": "no_product",
		"condition_desc": "プロダクト未作成",
		"text": "まだプロダクトがありません。PMを採用して、SaaSプロダクトの立ち上げを検討しましょう。初期費用が少なく始められます。",
		"priority": 4,
		"cooldown": 5,
	},
	{
		"id": "high_morale",
		"condition_desc": "士気80以上",
		"text": "チームの士気が高いですね！この状態なら開発効率が最大です。今がプロダクト強化のチャンスです。",
		"priority": 1,
		"cooldown": 6,
	},
	{
		"id": "low_morale",
		"condition_desc": "士気30以下",
		"text": "チームの士気が危険な水準です。チームケアアクションを実行するか、ムードメーカー気質のメンバーを採用しましょう。放置すると離職が増えます。",
		"priority": 4,
		"cooldown": 3,
	},
	{
		"id": "no_revenue",
		"condition_desc": "月6以降で売上0",
		"text": "6ヶ月経っても売上がゼロです。ユーザー獲得のためにマーケティングを強化するか、プロダクトの利益率を上げましょう。",
		"priority": 4,
		"cooldown": 4,
	},
	{
		"id": "team_growing",
		"condition_desc": "チーム5人以上",
		"text": "チームが大きくなってきました。リーダーやマネージャーへの昇進を検討して、組織体制を整えましょう。",
		"priority": 2,
		"cooldown": 8,
	},
	{
		"id": "high_debt",
		"condition_desc": "技術的負債60以上",
		"text": "技術的負債が危険水準です。放置するとシステム障害が頻発し、ユーザー離脱に繋がります。リファクタリングを最優先にしてください。",
		"priority": 4,
		"cooldown": 3,
	},
	{
		"id": "equity_warning",
		"condition_desc": "持ち株70%以下",
		"text": "持ち株比率が下がってきています。これ以上のエクイティ調達は経営権リスクが高まります。銀行融資や受託開発での資金確保も検討しましょう。",
		"priority": 3,
		"cooldown": 6,
	},
	{
		"id": "first_hire_hint",
		"condition_desc": "月2でチーム1人",
		"text": "一人で頑張っていますね。リファラル経由で最初のメンバーを採用しましょう。エンジニアを採用すると開発速度が上がります。",
		"priority": 3,
		"cooldown": 5,
	},
	{
		"id": "marketing_unlocked",
		"condition_desc": "マーケティング解放時",
		"text": "マーケティングが解放されました！コンテンツマーケティングは低コストで始められます。まずは小さく始めてユーザー獲得を目指しましょう。",
		"priority": 3,
		"cooldown": 99,
	},
]


## 段階的チュートリアル（最初の6ヶ月はガイド付き強制フロー）
const TUTORIAL_STEPS := [
	{
		"id": "month_0",
		"trigger": "game_start",
		"forced_action": "hire",
		"messages": [
			"社長、はじめまして！秘書のあかりです。",
			"これからスタートアップを大きくしていきましょう！目標はIPOです。",
			"まずは仲間が必要です。「採用する」ボタンを押して、PMを採用しましょう！",
			"PMがいないとプロダクトを作れません。最初の採用はとても大事です。",
		],
	},
	{
		"id": "month_1",
		"trigger": "month_1",
		"forced_action": "develop",
		"messages": [
			"PMを採用できましたね！素晴らしい第一歩です。",
			"次はプロダクトを作りましょう。「開発に集中」を選んでSaaSプロダクトを立ち上げます。",
			"初期費用は200万円。認証機能付きのSaaSが立ち上がります。",
		],
	},
	{
		"id": "month_2",
		"trigger": "month_2",
		"forced_action": "hire",
		"messages": [
			"プロダクトの土台ができました！",
			"開発を加速するためにエンジニアを採用しましょう。",
			"リファラル（紹介）経由で候補者を探します。",
		],
	},
	{
		"id": "month_3",
		"trigger": "month_3",
		"forced_action": "develop",
		"messages": [
			"チームが増えました！開発力がアップしています。",
			"「開発に集中」でプロダクトの機能を追加しましょう。",
			"UXやデザインの品質が上がると、ユーザー獲得に繋がります。",
		],
	},
	{
		"id": "month_4",
		"trigger": "month_4",
		"forced_action": "team_care",
		"messages": [
			"開発が進んでいますね。でもチームの士気にも気を配りましょう。",
			"「チームケア」を実行して、メンバーのモチベーションを上げます。",
			"士気が高いと開発効率もアップしますよ！",
		],
	},
	{
		"id": "month_5_free",
		"trigger": "month_5",
		"forced_action": "",
		"messages": [
			"基本操作のチュートリアルは以上です！お疲れさまでした。",
			"ここからは自由に経営できます。マーケティングや資金調達も使えるようになります。",
			"わからないことがあれば、私がアドバイスしますね。頑張りましょう！",
		],
	},
]


## 条件IDに対して現在のゲーム状態が合致するか判定
## gs: GameState シングルトン
## month_with_no_users: ユーザーが0のまま経過した月数
static func check_condition(condition_id: String, gs, month_with_no_users: int) -> bool:
	match condition_id:
		"cash_below_200":
			return gs.cash < 200 and gs.cash > 0
		"morale_below_30":
			return gs.team_morale < 30
		"no_users_3_months":
			return gs.users == 0 and month_with_no_users >= 3
		"team_size_1_month_3":
			return gs.team_size <= 1 and gs.month >= 3
		"product_50_no_marketing":
			return gs.product_power >= 50 and gs.users < 100
		"valuation_near_ipo":
			# 時価総額がIPO目標の70%以上
			return gs.valuation >= int(gs.IPO_THRESHOLD * 0.7)
	return false
