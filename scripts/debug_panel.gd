extends PanelContainer
## デバッグ/テストパネル: パラメータ編集・自動実行・バランスログ表示

signal panel_toggled(visible: bool)

var balance_logger: Node
var auto_simulator: Node
var _auto_play_active := false
var _auto_play_delay := 0.5
var _game_node: Node = null  # game.gd への参照
var _event_ids: Array = []   # イベントIDリスト（OptionButtonのインデックスに対応）

@onready var tab_container := $VBox/TabContainer
@onready var toggle_btn := $VBox/ToggleArea/ToggleBtn

# パラメータ編集タブ
@onready var cash_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/CashSpin
@onready var product_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/ProductSpin
@onready var team_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/TeamSpin
@onready var morale_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/MoraleSpin
@onready var users_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/UsersSpin
@onready var reputation_spin := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/ReputationSpin
@onready var apply_btn := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/ApplyBtn
@onready var valuation_label := $VBox/TabContainer/ParamTab/ScrollContainer/ParamGrid/ValuationBreakdown

# テストタブ
@onready var skip_btn := $VBox/TabContainer/TestTab/TestScroll/TestVBox/SkipBtn
@onready var event_option := $VBox/TabContainer/TestTab/TestScroll/TestVBox/EventOption
@onready var trigger_event_btn := $VBox/TabContainer/TestTab/TestScroll/TestVBox/TriggerEventBtn
@onready var win_btn := $VBox/TabContainer/TestTab/TestScroll/TestVBox/WinBtn
@onready var lose_btn := $VBox/TabContainer/TestTab/TestScroll/TestVBox/LoseBtn

# 速度制御タブ
@onready var speed_slider := $VBox/TabContainer/SpeedTab/SpeedVBox/SpeedSlider
@onready var speed_label := $VBox/TabContainer/SpeedTab/SpeedVBox/SpeedLabel
@onready var auto_play_btn := $VBox/TabContainer/SpeedTab/SpeedVBox/AutoPlayBtn
@onready var action_option := $VBox/TabContainer/SpeedTab/SpeedVBox/ActionOption
@onready var auto_status := $VBox/TabContainer/SpeedTab/SpeedVBox/AutoStatusLabel

# シミュレーションタブ
@onready var sim_count_spin := $VBox/TabContainer/SimTab/SimVBox/SimCountSpin
@onready var strategy_option := $VBox/TabContainer/SimTab/SimVBox/StrategyOption
@onready var run_sim_btn := $VBox/TabContainer/SimTab/SimVBox/RunSimBtn
@onready var run_all_btn := $VBox/TabContainer/SimTab/SimVBox/RunAllBtn
@onready var sim_result_label := $VBox/TabContainer/SimTab/SimVBox/SimResultLabel

# ログタブ
@onready var log_label := $VBox/TabContainer/LogTab/LogScroll/LogLabel


func _ready() -> void:
	balance_logger = preload("res://scripts/balance_logger.gd").new()
	add_child(balance_logger)

	var AutoSimulatorScript = load("res://scripts/auto_simulator.gd")
	auto_simulator = Node.new()
	auto_simulator.set_script(AutoSimulatorScript)
	add_child(auto_simulator)

	# 初期状態: パネル非表示（トグルボタンのみ表示）
	tab_container.visible = false

	# トグルボタン
	toggle_btn.pressed.connect(_on_toggle_pressed)

	# パラメータ適用
	apply_btn.pressed.connect(_on_apply_params)

	# テストボタン
	skip_btn.pressed.connect(_on_skip_10_turns)
	trigger_event_btn.pressed.connect(_on_trigger_event)
	win_btn.pressed.connect(_on_instant_win)
	lose_btn.pressed.connect(_on_instant_lose)

	# 速度制御
	speed_slider.value_changed.connect(_on_speed_changed)
	auto_play_btn.pressed.connect(_on_auto_play_toggled)

	# シミュレーション
	run_sim_btn.pressed.connect(_on_run_simulation)
	run_all_btn.pressed.connect(_on_run_all_simulations)

	# イベント選択肢を登録
	_populate_event_options()

	# アクション選択肢
	action_option.add_item("ランダム", 0)
	action_option.add_item("開発", 1)
	action_option.add_item("採用", 2)
	action_option.add_item("マーケティング", 3)
	action_option.add_item("資金調達", 4)
	action_option.add_item("チームケア", 5)

	# 戦略選択肢
	for key in auto_simulator.STRATEGY_NAMES:
		strategy_option.add_item(auto_simulator.STRATEGY_NAMES[key], key)

	# 初期状態を読み込み
	_sync_spinboxes_from_state()

	# 初期スナップショット
	balance_logger.record_snapshot(GameState)

	# 速度ラベル更新
	_on_speed_changed(speed_slider.value)


func set_game_node(game: Node) -> void:
	_game_node = game
	# game_nodeが設定されたらイベント選択肢を構築
	_rebuild_event_options()


func _populate_event_options() -> void:
	# game_nodeのturn_managerからイベントを取得（_readyではまだ無いのでハードコード）
	# 後でset_game_node時に再構築する
	_event_ids = []


## game_nodeが設定された後にイベント選択肢を再構築
func _rebuild_event_options() -> void:
	event_option.clear()
	_event_ids = []
	if not _game_node or not _game_node.turn_manager:
		return
	var em = _game_node.turn_manager.event_manager
	var idx := 0
	for event_id in em.events:
		var event_data: Dictionary = em.events[event_id]
		event_option.add_item(event_data.get("title", event_id), idx)
		_event_ids.append(event_id)
		idx += 1


func _on_toggle_pressed() -> void:
	tab_container.visible = not tab_container.visible
	if tab_container.visible:
		toggle_btn.text = "デバッグパネルを閉じる"
		_sync_spinboxes_from_state()
		_update_valuation_breakdown()
	else:
		toggle_btn.text = "デバッグパネル"
	panel_toggled.emit(tab_container.visible)


func _sync_spinboxes_from_state() -> void:
	cash_spin.value = GameState.cash
	product_spin.value = GameState.product_power
	team_spin.value = GameState.team_size
	morale_spin.value = GameState.team_morale
	users_spin.value = GameState.users
	reputation_spin.value = GameState.reputation


func _update_valuation_breakdown() -> void:
	var user_component := GameState.users * GameState.product_power
	var rep_component := GameState.reputation * 100
	var total := user_component + rep_component
	valuation_label.text = (
		"時価総額内訳:\n" +
		"  ユーザー(%d) x プロダクト力(%d) = %d\n" % [GameState.users, GameState.product_power, user_component] +
		"  評判(%d) x 100 = %d\n" % [GameState.reputation, rep_component] +
		"  合計: %d万円 (IPO: %d万円)\n" % [total, GameState.IPO_THRESHOLD] +
		"  月間コスト: %d万円 (チーム%d人 x 50万)" % [GameState.monthly_cost, GameState.team_size]
	)


func _on_apply_params() -> void:
	GameState.cash = int(cash_spin.value)
	GameState.product_power = int(product_spin.value)
	GameState.team_size = int(team_spin.value)
	GameState.team_morale = int(morale_spin.value)
	GameState.users = int(users_spin.value)
	GameState.reputation = int(reputation_spin.value)
	GameState.state_changed.emit()
	_update_valuation_breakdown()


func _on_skip_10_turns() -> void:
	if not _game_node:
		return
	skip_btn.disabled = true
	var actions := ["develop", "hire", "marketing", "fundraise", "team_care"]
	for i in 10:
		if GameState.cash <= 0 or GameState.valuation >= GameState.IPO_THRESHOLD:
			break
		var action = actions[randi() % actions.size()]
		# 高速実行: アクション適用 + イベント適用 + 月末処理を直接呼ぶ
		_execute_turn_fast(action)
		balance_logger.record_snapshot(GameState)
		await get_tree().create_timer(0.05).timeout
	_game_node._update_ui()
	skip_btn.disabled = false
	_sync_spinboxes_from_state()
	_update_valuation_breakdown()
	_refresh_log_tab()


## ターンを高速実行（ポップアップなし、直接処理）
func _execute_turn_fast(action: String) -> void:
	# アクション実行
	var result := GameState.apply_action(action)
	_game_node._add_log(result)

	# イベント処理（ポップアップなし）
	var em = _game_node.turn_manager.event_manager
	var event_data: Dictionary = em.try_random_event()
	if not event_data.is_empty():
		var effect_text := ""
		var choices = event_data.get("choices", [])
		if choices.size() > 0:
			# 自動選択: 最初の選択肢を選ぶ
			effect_text = em.apply_choice_effect(choices[0])
		else:
			effect_text = em.apply_event_effect(event_data)
		var title: String = event_data.get("title", "")
		_game_node._add_log("[color=#FFD966]【%s】%s[/color]" % [title, effect_text])

	# 月末処理
	GameState.advance_month()


func _on_trigger_event() -> void:
	if not _game_node:
		return
	var event_idx = event_option.get_selected_id()
	if event_idx < 0 or event_idx >= _event_ids.size():
		return
	var event_id: String = _event_ids[event_idx]
	var em = _game_node.turn_manager.event_manager
	if not em.events.has(event_id):
		return
	var event_data: Dictionary = em.events[event_id]
	# 選択肢なしイベントの場合はeffectを直接呼ぶ
	var effect_text = em.apply_event_effect(event_data)
	GameState.state_changed.emit()
	var title: String = event_data.get("title", event_id)
	var desc: String = event_data.get("description", "")
	_game_node._add_log("[color=cyan][デバッグ] イベント発動: %s - %s[/color]" % [title, effect_text])
	_sync_spinboxes_from_state()
	_update_valuation_breakdown()
	balance_logger.record_snapshot(GameState)
	_refresh_log_tab()


func _on_instant_win() -> void:
	GameState.users = 20000
	GameState.product_power = 100
	GameState.reputation = 100
	GameState.state_changed.emit()
	GameState.game_clear.emit("【デバッグ】即座にIPO達成！")


func _on_instant_lose() -> void:
	GameState.cash = 0
	GameState.state_changed.emit()
	GameState.game_over.emit("【デバッグ】即座に倒産！")


# --- 速度制御 ---

func _on_speed_changed(value: float) -> void:
	_auto_play_delay = value
	speed_label.text = "間隔: %.1f秒" % value


func _on_auto_play_toggled() -> void:
	_auto_play_active = not _auto_play_active
	if _auto_play_active:
		auto_play_btn.text = "自動プレイ停止"
		auto_status.text = "自動プレイ中..."
		_run_auto_play()
	else:
		auto_play_btn.text = "自動プレイ開始"
		auto_status.text = "停止中"


func _run_auto_play() -> void:
	if not _game_node:
		_auto_play_active = false
		return

	while _auto_play_active:
		if GameState.cash <= 0 or GameState.valuation >= GameState.IPO_THRESHOLD:
			_auto_play_active = false
			auto_play_btn.text = "自動プレイ開始"
			auto_status.text = "ゲーム終了"
			break

		var action := _get_auto_play_action()
		_execute_turn_fast(action)
		balance_logger.record_snapshot(GameState)
		_game_node._update_ui()

		auto_status.text = "自動プレイ中... %dヶ月目" % GameState.month
		await get_tree().create_timer(_auto_play_delay).timeout

	_refresh_log_tab()


func _get_auto_play_action() -> String:
	var selected = action_option.get_selected_id()
	var actions := ["develop", "hire", "marketing", "fundraise", "team_care"]
	if selected == 0:
		return actions[randi() % actions.size()]
	else:
		return actions[selected - 1]


# --- シミュレーション ---

func _on_run_simulation() -> void:
	run_sim_btn.disabled = true
	run_all_btn.disabled = true
	sim_result_label.text = "シミュレーション実行中..."

	var num_games := int(sim_count_spin.value)
	var strategy: int = strategy_option.get_selected_id()

	# 非同期で実行（UIブロック回避のためprocess_frameを挟む）
	await get_tree().process_frame
	var stats = auto_simulator.run_simulation(strategy, num_games)
	sim_result_label.text = auto_simulator.format_stats(stats)

	run_sim_btn.disabled = false
	run_all_btn.disabled = false


func _on_run_all_simulations() -> void:
	run_sim_btn.disabled = true
	run_all_btn.disabled = true
	sim_result_label.text = "全戦略シミュレーション実行中..."

	await get_tree().process_frame
	var all_stats = auto_simulator.run_all_strategies(int(sim_count_spin.value))
	sim_result_label.text = auto_simulator.format_all_stats(all_stats)

	run_sim_btn.disabled = false
	run_all_btn.disabled = false


# --- ログ ---

func _refresh_log_tab() -> void:
	log_label.text = balance_logger.generate_full_report()


## ターン終了時に呼ばれる（game.gdから接続）
func on_turn_ended() -> void:
	balance_logger.record_snapshot(GameState)
	if tab_container.visible:
		_sync_spinboxes_from_state()
		_update_valuation_breakdown()
		_refresh_log_tab()
