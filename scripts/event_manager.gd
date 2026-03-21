extends Node
## ランダムイベントを管理

class Event:
	var title: String
	var description: String
	var effect: Callable

	func _init(t: String, d: String, e: Callable) -> void:
		title = t
		description = d
		effect = e


var events: Array[Event] = []


func _ready() -> void:
	_register_events()


func _register_events() -> void:
	events.append(Event.new(
		"メディア掲載",
		"テックメディアに取り上げられた！",
		func(gs): gs.users += randi_range(100, 500); gs.reputation += 10
	))
	events.append(Event.new(
		"競合出現",
		"強力な競合が同じ市場に参入してきた。",
		func(gs): gs.users -= randi_range(30, 100); gs.users = maxi(gs.users, 0)
	))
	events.append(Event.new(
		"メンバー離脱",
		"主要メンバーが退職してしまった…",
		func(gs):
			if gs.team_size > 1:
				gs.team_size -= 1
				gs.team_morale -= 15
	))
	events.append(Event.new(
		"サーバー障害",
		"本番サーバーがダウン！緊急対応に追われた。",
		func(gs): gs.cash -= 100; gs.reputation -= 5
	))
	events.append(Event.new(
		"大型案件",
		"大企業から提携のオファーが来た！",
		func(gs): gs.cash += 500; gs.reputation += 15
	))
	events.append(Event.new(
		"SNS炎上",
		"SNSで炎上してしまった…",
		func(gs): gs.reputation -= 20; gs.reputation = maxi(gs.reputation, 0); gs.users += randi_range(50, 200)
	))
	events.append(Event.new(
		"エンジニア紹介",
		"知人から優秀なエンジニアを紹介された。",
		func(gs): gs.team_size += 1; gs.team_morale += 5
	))
	events.append(Event.new(
		"投資家ミーティング",
		"有名VCとの面談が実現した。",
		func(gs): gs.reputation += randi_range(5, 20)
	))


## 30%の確率でイベント発生。発生しなければnullを返す
func try_random_event() -> Event:
	if randf() > 0.3:
		return null
	return events[randi() % events.size()]
