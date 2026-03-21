extends Node
## ターン進行を管理

signal turn_started(month: int)
signal action_resolved(result_text: String)
signal event_occurred(title: String, description: String)
signal turn_ended

var game_state: Node
var event_manager: EventManager


func _ready() -> void:
	game_state = get_node("/root/GameState")
	event_manager = EventManager.new()
	add_child(event_manager)


func execute_turn(action: String) -> void:
	turn_started.emit(game_state.month + 1)

	# 1. アクション実行
	var result = game_state.apply_action(action)
	action_resolved.emit(result)

	# 2. ランダムイベント
	var event = event_manager.try_random_event()
	if event:
		event.effect.call(game_state)
		event_occurred.emit(event.title, event.description)

	# 3. 月末処理（コスト支払い・勝敗判定）
	game_state.advance_month()

	turn_ended.emit()
