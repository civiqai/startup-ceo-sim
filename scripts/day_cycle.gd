extends Node
## 24時間サイクルのシミュレーション管理
## 1ヶ月 = 22営業日、1日 = 出社(9:00)→作業→退社(18:00+)
## アクション選択後に月のシミュレーションが自動進行する

signal hour_changed(day: int, hour: float)
signal day_started(day: int)
signal day_ended(day: int)
signal month_completed()
signal productivity_updated(productivity: Dictionary)

const WORK_DAYS_PER_MONTH := 22
const WORK_START_HOUR := 9.0
const WORK_END_HOUR := 18.0
const OVERTIME_END_HOUR := 22.0
const HOURS_PER_SECOND := 36.0  # 基本速度: 1秒=36時間（1ヶ月≈6秒@1x）

var current_day: int = 1
var current_hour: float = 0.0
var is_running: bool = false
var is_paused: bool = false
var speed_multiplier: float = 1.0  # 1x, 2x, 4x
var overtime_enabled: bool = false
var monthly_action: String = ""

# 月間累積の生産性
var monthly_productivity: Dictionary = {
	"engineer": 0.0,
	"designer": 0.0,
	"marketer": 0.0,
	"bizdev": 0.0,
	"pm": 0.0,
}


func _process(delta: float) -> void:
	if not is_running or is_paused:
		return

	var time_advance = delta * HOURS_PER_SECOND * speed_multiplier
	var old_hour = current_hour
	current_hour += time_advance

	# 毎時処理（整数時刻を跨いだら）
	var old_int_hour = int(old_hour)
	var new_int_hour = int(current_hour)
	if new_int_hour > old_int_hour and current_hour >= WORK_START_HOUR:
		_process_work_hour()

	hour_changed.emit(current_day, current_hour)

	# 退社時刻チェック
	var end_hour = OVERTIME_END_HOUR if overtime_enabled else WORK_END_HOUR
	if current_hour >= end_hour:
		_end_day()


## 月のシミュレーションを開始
func start_month(action: String) -> void:
	monthly_action = action
	current_day = 1
	current_hour = 0.0
	is_running = true
	is_paused = false
	for key in monthly_productivity:
		monthly_productivity[key] = 0.0
	_start_day()


## 日の開始
func _start_day() -> void:
	current_hour = WORK_START_HOUR - 0.5  # 8:30出社開始
	day_started.emit(current_day)
	# TeamManagerの全メンバーを出社させる
	TeamManager.all_arrive()


## 1時間の作業処理
func _process_work_hour() -> void:
	if current_hour < WORK_START_HOUR:
		return
	var productivity := TeamManager.work_all_one_hour()
	for key in productivity:
		monthly_productivity[key] += productivity[key]
	productivity_updated.emit(productivity)

	# 残業中は士気が少し下がる
	if overtime_enabled and current_hour > WORK_END_HOUR:
		GameState.team_morale = maxi(GameState.team_morale - 1, 0)


## 日の終了
func _end_day() -> void:
	TeamManager.all_leave()
	day_ended.emit(current_day)

	# 夜間回復
	TeamManager.all_rest_overnight()

	current_day += 1
	if current_day > WORK_DAYS_PER_MONTH:
		_end_month()
	else:
		# 週末判定（5日ごとに休日）
		if current_day % 6 == 0:
			TeamManager.all_rest_full()
			current_day += 1
			if current_day > WORK_DAYS_PER_MONTH:
				_end_month()
				return
		_start_day()


## 月の終了
func _end_month() -> void:
	is_running = false
	_apply_monthly_productivity()
	month_completed.emit()


## 月間の生産性をGameStateに反映
func _apply_monthly_productivity() -> void:
	# エンジニアの生産性 → プロダクト力
	var eng_prod = monthly_productivity.get("engineer", 0.0)
	var product_gain = int(eng_prod * 0.5)
	GameState.add_product_power(product_gain)

	# デザイナーの生産性 → プロダクト力（少し）+ ブランド
	var design_prod = monthly_productivity.get("designer", 0.0)
	GameState.add_product_power(int(design_prod * 0.2))
	GameState.brand_value = mini(GameState.brand_value + int(design_prod * 0.3), 100)

	# マーケターの生産性 → ユーザー獲得
	var market_prod = monthly_productivity.get("marketer", 0.0)
	GameState.users += int(market_prod * GameState.product_power * 0.1)

	# ビズデブの生産性 → 評判
	var bizdev_prod = monthly_productivity.get("bizdev", 0.0)
	GameState.reputation = mini(GameState.reputation + int(bizdev_prod * 0.3), 100)

	# PMの生産性 → 全体効率（士気回復）
	var pm_prod = monthly_productivity.get("pm", 0.0)
	GameState.team_morale = mini(GameState.team_morale + int(pm_prod * 0.2), 100)


## 速度を変更
func set_speed(multiplier: float) -> void:
	speed_multiplier = multiplier


## 一時停止/再開
func toggle_pause() -> void:
	is_paused = not is_paused


## 残業モードの切り替え
func toggle_overtime() -> void:
	overtime_enabled = not overtime_enabled


## リセット
func reset() -> void:
	current_day = 1
	current_hour = 0.0
	is_running = false
	is_paused = false
	speed_multiplier = 1.0
	overtime_enabled = false
	monthly_action = ""
	for key in monthly_productivity:
		monthly_productivity[key] = 0.0
