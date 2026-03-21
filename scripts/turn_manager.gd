extends Node
## ターン進行を管理

signal turn_started(month: int)
signal action_resolved(result_text: String)
signal event_triggered(event_data: Dictionary)
signal event_resolved(effect_text: String)
signal turn_ended

var game_state: Node
var event_manager: Node


func _ready() -> void:
	game_state = get_node("/root/GameState")
	event_manager = preload("res://scripts/event_manager.gd").new()
	add_child(event_manager)


func execute_turn(action: String) -> void:
	turn_started.emit(game_state.month + 1)

	# 1. アクション実行
	var result = game_state.apply_action(action)
	action_resolved.emit(result)

	# 2. ランダムイベント（チュートリアル中はブロック）
	if game_state.tutorial_month < 0:
		var event_data = event_manager.try_random_event()
		if not event_data.is_empty():
			event_triggered.emit(event_data)
			return

	_finish_turn()


## イベントポップアップが閉じられた後に呼ばれる
func finish_after_event(effect_text: String) -> void:
	if effect_text != "":
		event_resolved.emit(effect_text)
	_finish_turn()


func _finish_turn() -> void:
	# 月末処理（コスト支払い・勝敗判定）
	game_state.advance_month()
	turn_ended.emit()


## 双六など、アクション効果が既に適用済みの場合のターン実行
func execute_turn_with_result(action_result: String) -> void:
	turn_started.emit(game_state.month + 1)
	action_resolved.emit(action_result)

	# チュートリアル中はランダムイベントをブロック
	if game_state.tutorial_month < 0:
		var event_data = event_manager.try_random_event()
		if not event_data.is_empty():
			event_triggered.emit(event_data)
			return

	_finish_turn()


## ゲームリセット時
func reset() -> void:
	event_manager.reset()
