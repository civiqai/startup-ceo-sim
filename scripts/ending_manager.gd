extends Node
## エンディング分岐管理

signal ending_triggered(ending_data: Dictionary)

const ENDINGS := {
	"ipo": {
		"id": "ipo",
		"name": "IPO達成", "icon": "👑",
		"title": "株式公開おめでとうございます！",
		"color": Color(0.95, 0.85, 0.30),
		"epilogue": "あなたの会社は東証に上場し、世間の注目を浴びた。\n長い道のりだったが、チーム全員の努力が実を結んだ。\nこれからは上場企業の経営者として、新たな挑戦が始まる。\n\n— IT社長物語 GOOD END —",
		"rank": "S",
	},
	"acquisition": {
		"id": "acquisition",
		"name": "大型買収", "icon": "🤝",
		"title": "買収提案を受諾！",
		"color": Color(0.55, 0.80, 0.90),
		"epilogue": "大手企業からの買収提案を受け入れた。\n創業からの日々を振り返ると感慨深いものがある。\nチームは新たな環境で更なる成長を遂げるだろう。\n得られた資金で、次の挑戦に向けて準備を始めた。\n\n— IT社長物語 GOOD END —",
		"rank": "A",
	},
	"mbo": {
		"id": "mbo",
		"name": "MBO（経営陣買収）", "icon": "🏢",
		"title": "MBO成立！",
		"color": Color(0.60, 0.85, 0.55),
		"epilogue": "経営陣による株式買取が成立した。\n投資家の期待に応え、独立した経営を手に入れた。\n安定した経営基盤のもと、マイペースで成長を続ける。\n小さくても強い、そんな会社を目指して。\n\n— IT社長物語 NORMAL END —",
		"rank": "B",
	},
	"overseas": {
		"id": "overseas",
		"name": "海外展開", "icon": "🌏",
		"title": "グローバル進出！",
		"color": Color(0.45, 0.75, 0.95),
		"epilogue": "ブランド力とユーザー基盤を武器に、海外市場へ進出。\n言語の壁、文化の違い…だが挑戦は止まらない。\nシリコンバレーの風を感じながら、世界を目指す。\n日本発のグローバルスタートアップの誕生だ。\n\n— IT社長物語 GOOD END —",
		"rank": "A",
	},
	"bankruptcy": {
		"id": "bankruptcy",
		"name": "倒産", "icon": "💀",
		"title": "資金が尽きました…",
		"color": Color(0.90, 0.30, 0.30),
		"epilogue": "資金が底をつき、会社は倒産した。\n夢は潰えたが、ここで得た経験は無駄にならない。\n多くの仲間と出会い、多くを学んだ。\nいつかまた、再起を期して…。\n\n— IT社長物語 BAD END —",
		"rank": "D",
	},
	"voluntary": {
		"id": "voluntary",
		"name": "自主解散", "icon": "🚪",
		"title": "会社を解散しました",
		"color": Color(0.60, 0.60, 0.65),
		"epilogue": "自らの判断で会社を畳むことを決めた。\n無理に続けるよりも、ここで区切りをつけるのが最善だと。\nメンバーにはそれぞれの道を歩んでもらう。\n社長としての日々は、かけがえのない財産になった。\n\n— IT社長物語 NORMAL END —",
		"rank": "C",
	},
}


## ゲームクリア時のエンディング判定
func determine_ending(gs) -> Dictionary:
	# IPO（最優先）
	if gs.valuation >= gs.IPO_THRESHOLD:
		return ENDINGS["ipo"]
	# 倒産
	if gs.cash <= 0:
		return ENDINGS["bankruptcy"]
	return ENDINGS.get("voluntary", {})


## 特殊エンディングの発生チェック（毎ターン末に呼ぶ）
## 条件を満たした特殊エンディングがあれば選択肢として返す
func check_special_endings(gs) -> Array[Dictionary]:
	var available: Array[Dictionary] = []

	# 買収提案（時価総額50万+ AND 評判70+）
	if gs.valuation >= 500000 and gs.reputation >= 70:
		available.append(ENDINGS["acquisition"])

	# MBO（60ヶ月+ AND 資金5000+ AND 士気80+）
	if gs.month >= 60 and gs.cash >= 5000 and gs.team_morale >= 80:
		available.append(ENDINGS["mbo"])

	# 海外展開（ユーザー8万+ AND ブランド60+ AND 評判60+）
	if gs.users >= 80000 and gs.brand_value >= 60 and gs.reputation >= 60:
		available.append(ENDINGS["overseas"])

	return available


## 自主解散が選べるか（12ヶ月以降）
func can_voluntary_dissolve(gs) -> bool:
	return gs.month >= 12


func get_ending(ending_id: String) -> Dictionary:
	return ENDINGS.get(ending_id, {})
