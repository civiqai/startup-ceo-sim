extends Control
## メインゲーム画面

const FundraiseTypes = preload("res://scripts/fundraise_types.gd")
const MarketingChannels = preload("res://scripts/marketing_channels.gd")
const TeamMemberClass = preload("res://scripts/team_member.gd")

var turn_manager: Node
var log_text: String = ""
var debug_panel: Node = null
var sugoroku_popup: Node
var fundraise_select_popup: Node
var marketing_select_popup: Node
var hire_popup: Node
var team_list_popup: Node
var member_detail_popup: Node
var milestone_manager: Node
var milestone_popup: Node
var secretary_popup: Node
var save_load_popup: Node
var day_cycle: Node
var phase_manager: Node
var product_manager: Node
var product_dev_popup: Node
var investor_manager: Node
var competitor_manager: Node
var achievement_manager: Node
var achievement_popup: Node
var ending_manager: Node
var create_product_popup: Node
var action_menu_popup: Node
var history_popup: Node
var furniture_shop_popup: Node
var furniture_detail_popup: Node
var furniture_placement: Node  # FurniturePlacement node on OfficeTilemap
var office_expansion_popup: Node
var monthly_log: Array[Dictionary] = []
var _current_month_events: Array = []

@onready var month_label := $VBox/Header/HBox/MonthLabel
@onready var cash_label := $VBox/Header/HBox/CashLabel
@onready var office_view := $VBox/OfficeView
@onready var log_label := $VBox/LogTicker/LogPanel/LogLabel
@onready var log_expand_btn := $VBox/LogTicker/ExpandBtn
var _log_expanded := false
@onready var action_btn := $VBox/ActionBar/HBox/ActionBtn
@onready var team_btn := $VBox/ActionBar/HBox/TeamBtn
@onready var day_label := $VBox/Header/HBox/DayLabel
@onready var speed_bar := $VBox/SpeedBar
var event_popup: Node
var _pending_marketing_result: Dictionary = {}
var _pending_contract_selection: bool = false

# TileMapオフィス関連
@onready var office_viewport_container := $VBox/OfficeViewport
@onready var office_viewport := $VBox/OfficeViewport/SubViewport
@onready var office_tilemap := $VBox/OfficeViewport/SubViewport/OfficeTilemap
@onready var office_camera := $VBox/OfficeViewport/SubViewport/Camera
var office_ui_overlay: Node = null
var _use_tilemap_office := true  # TileMapオフィスの有効/無効切替


func _ready() -> void:
	turn_manager = preload("res://scripts/turn_manager.gd").new()
	turn_manager.name = "TurnManager"
	add_child(turn_manager)

	# 24時間サイクル管理
	day_cycle = preload("res://scripts/day_cycle.gd").new()
	day_cycle.name = "DayCycle"
	add_child(day_cycle)
	day_cycle.hour_changed.connect(_on_hour_changed)
	day_cycle.day_started.connect(_on_day_started)
	day_cycle.day_ended.connect(_on_day_ended)
	day_cycle.month_completed.connect(_on_month_completed)

	# フェーズ管理
	phase_manager = preload("res://scripts/phase_manager.gd").new()
	phase_manager.name = "PhaseManager"
	add_child(phase_manager)
	phase_manager.phase_changed.connect(_on_phase_changed)

	# 速度制御ボタン（シーンにある場合のみ接続）
	if has_node("VBox/SpeedBar"):
		speed_bar.get_node("Speed1x").pressed.connect(_on_speed_1x_pressed)
		speed_bar.get_node("Speed2x").pressed.connect(_on_speed_2x_pressed)
		speed_bar.get_node("Speed4x").pressed.connect(_on_speed_4x_pressed)
		speed_bar.get_node("PauseBtn").pressed.connect(_on_pause_pressed)
		speed_bar.get_node("OvertimeBtn").pressed.connect(_on_overtime_pressed)
		speed_bar.visible = false  # シミュレーション中のみ表示

	# EventPopupをCanvasLayerとしてコードから生成（最前面保証）
	var EventPopupScript = load("res://scripts/event_popup.gd")
	event_popup = CanvasLayer.new()
	event_popup.set_script(EventPopupScript)
	add_child(event_popup)

	turn_manager.action_resolved.connect(_on_action_resolved)
	turn_manager.event_triggered.connect(_on_event_triggered)
	turn_manager.event_resolved.connect(_on_event_resolved)
	turn_manager.turn_ended.connect(_on_turn_ended)

	GameState.game_over.connect(_on_game_over)
	GameState.game_clear.connect(_on_game_clear)
	GameState.emergency_fundraise_triggered.connect(_on_emergency_fundraise)

	# アクションメニューポップアップ（CanvasLayer）
	var ActionMenuScript = load("res://scripts/action_menu_popup.gd")
	action_menu_popup = CanvasLayer.new()
	action_menu_popup.set_script(ActionMenuScript)
	add_child(action_menu_popup)
	action_menu_popup.action_selected.connect(_do_action)
	action_menu_popup.menu_closed.connect(_on_action_menu_closed)

	# アクションメニュートグル
	action_btn.pressed.connect(_toggle_action_menu)

	# 経営ログ展開トグル
	log_expand_btn.pressed.connect(_toggle_log_expand)

	# チーム一覧ボタン
	team_btn.pressed.connect(_on_team_btn_pressed)

	event_popup.popup_closed.connect(_on_event_popup_closed)

	# 双六ポップアップ
	var SugorokuPopupScript = load("res://scripts/sugoroku_popup.gd")
	sugoroku_popup = CanvasLayer.new()
	sugoroku_popup.set_script(SugorokuPopupScript)
	add_child(sugoroku_popup)
	sugoroku_popup.popup_closed.connect(_on_sugoroku_closed)

	# 資金調達タイプ選択ポップアップ
	var FundraiseSelectScript = load("res://scripts/fundraise_select_popup.gd")
	fundraise_select_popup = CanvasLayer.new()
	fundraise_select_popup.set_script(FundraiseSelectScript)
	add_child(fundraise_select_popup)
	fundraise_select_popup.type_selected.connect(_on_fundraise_type_selected)
	fundraise_select_popup.cancelled.connect(_on_fundraise_cancelled)

	# マーケティングチャネル選択ポップアップ
	var MarketingSelectScript = load("res://scripts/marketing_select_popup.gd")
	marketing_select_popup = CanvasLayer.new()
	marketing_select_popup.set_script(MarketingSelectScript)
	add_child(marketing_select_popup)
	marketing_select_popup.channel_selected.connect(_on_marketing_channel_selected)
	marketing_select_popup.cancelled.connect(_on_marketing_cancelled)

	# 採用ポップアップ
	var HirePopupScript = load("res://scripts/hire_popup.gd")
	hire_popup = CanvasLayer.new()
	hire_popup.set_script(HirePopupScript)
	add_child(hire_popup)
	hire_popup.hire_completed.connect(_on_hire_completed)
	hire_popup.hire_with_fire_completed.connect(_on_hire_with_fire_completed)
	hire_popup.hire_cancelled.connect(_on_hire_cancelled)

	# チーム一覧ポップアップ
	var TeamListScript = load("res://scripts/team_list_popup.gd")
	team_list_popup = CanvasLayer.new()
	team_list_popup.set_script(TeamListScript)
	add_child(team_list_popup)
	team_list_popup.member_selected.connect(_on_team_member_selected)
	team_list_popup.popup_closed.connect(_on_team_list_closed)

	# メンバー詳細ポップアップ
	var MemberDetailScript = load("res://scripts/member_detail_popup.gd")
	member_detail_popup = CanvasLayer.new()
	member_detail_popup.set_script(MemberDetailScript)
	add_child(member_detail_popup)
	member_detail_popup.member_promoted.connect(_on_member_promoted)
	member_detail_popup.member_fired.connect(_on_member_fired)
	member_detail_popup.popup_closed.connect(_on_member_detail_closed)

	# マイルストーン管理
	var MilestoneManagerScript = load("res://scripts/milestone_manager.gd")
	milestone_manager = Node.new()
	milestone_manager.set_script(MilestoneManagerScript)
	add_child(milestone_manager)

	# マイルストーンポップアップ
	var MilestonePopupScript = load("res://scripts/milestone_popup.gd")
	milestone_popup = CanvasLayer.new()
	milestone_popup.set_script(MilestonePopupScript)
	add_child(milestone_popup)
	milestone_popup.popup_closed.connect(_on_milestone_popup_closed)

	# 秘書ポップアップ
	var SecretaryPopupScript = load("res://scripts/secretary_popup.gd")
	secretary_popup = CanvasLayer.new()
	secretary_popup.set_script(SecretaryPopupScript)
	add_child(secretary_popup)
	secretary_popup.dialogue_finished.connect(_on_secretary_finished)

	# セーブ/ロードポップアップ
	var SaveLoadScript = load("res://scripts/save_load_popup.gd")
	save_load_popup = CanvasLayer.new()
	save_load_popup.set_script(SaveLoadScript)
	add_child(save_load_popup)
	save_load_popup.save_completed.connect(_on_save_completed)
	save_load_popup.load_completed.connect(_on_load_completed)

	# プロダクト開発管理
	product_manager = preload("res://scripts/product_manager.gd").new()
	product_manager.name = "ProductManager"
	add_child(product_manager)
	product_manager.feature_completed.connect(_on_feature_completed)
	product_manager.tech_debt_warning.connect(_on_tech_debt_warning)

	# プロダクト開発ポップアップ
	var ProductDevScript = load("res://scripts/product_dev_popup.gd")
	product_dev_popup = CanvasLayer.new()
	product_dev_popup.set_script(ProductDevScript)
	add_child(product_dev_popup)
	product_dev_popup.set_product_manager(product_manager)
	product_dev_popup.feature_selected.connect(_on_feature_dev_selected)
	product_dev_popup.debt_repair_selected.connect(_on_debt_repair_selected)
	product_dev_popup.cancelled.connect(_on_product_dev_cancelled)

	# プロダクト作成ポップアップ
	var CreateProductScript = load("res://scripts/create_product_popup.gd")
	create_product_popup = CanvasLayer.new()
	create_product_popup.set_script(CreateProductScript)
	add_child(create_product_popup)
	create_product_popup.set_product_manager(product_manager)
	create_product_popup.product_creation_completed.connect(_on_product_creation_completed)
	create_product_popup.cancelled.connect(_on_create_product_cancelled)

	# 投資家管理
	investor_manager = preload("res://scripts/investor_manager.gd").new()
	investor_manager.name = "InvestorManager"
	add_child(investor_manager)
	investor_manager.investor_mood_changed.connect(_on_investor_mood_changed)

	# 競合・市場管理
	competitor_manager = preload("res://scripts/competitor_manager.gd").new()
	competitor_manager.name = "CompetitorManager"
	add_child(competitor_manager)
	competitor_manager.competitor_news.connect(_on_competitor_news)

	# 実績管理
	achievement_manager = preload("res://scripts/achievement_manager.gd").new()
	achievement_manager.name = "AchievementManager"
	add_child(achievement_manager)

	# 実績ポップアップ
	var AchievementPopupScript = load("res://scripts/achievement_popup.gd")
	achievement_popup = CanvasLayer.new()
	achievement_popup.set_script(AchievementPopupScript)
	add_child(achievement_popup)

	# エンディング管理
	ending_manager = preload("res://scripts/ending_manager.gd").new()
	ending_manager.name = "EndingManager"
	add_child(ending_manager)

	# 履歴ポップアップ
	var HistoryPopupScript = load("res://scripts/history_popup.gd")
	history_popup = CanvasLayer.new()
	history_popup.set_script(HistoryPopupScript)
	add_child(history_popup)

	# 家具ショップポップアップ
	var FurnitureShopScript = load("res://scripts/furniture_shop_popup.gd")
	furniture_shop_popup = CanvasLayer.new()
	furniture_shop_popup.set_script(FurnitureShopScript)
	add_child(furniture_shop_popup)
	furniture_shop_popup.furniture_purchased.connect(_on_furniture_purchased)
	furniture_shop_popup.placement_requested.connect(_on_furniture_placement_requested)
	furniture_shop_popup.popup_closed.connect(_on_furniture_shop_closed)

	# 家具詳細ポップアップ
	var FurnitureDetailScript = load("res://scripts/furniture_detail_popup.gd")
	furniture_detail_popup = CanvasLayer.new()
	furniture_detail_popup.set_script(FurnitureDetailScript)
	add_child(furniture_detail_popup)
	furniture_detail_popup.furniture_sold.connect(_on_furniture_sold)
	furniture_detail_popup.furniture_moved.connect(_on_furniture_move_requested)
	furniture_detail_popup.furniture_upgraded.connect(_on_furniture_upgraded)
	furniture_detail_popup.popup_closed.connect(_on_furniture_detail_closed)

	# オフィス拡張ポップアップ
	var ExpansionPopupScript = load("res://scripts/office_expansion_popup.gd")
	office_expansion_popup = CanvasLayer.new()
	office_expansion_popup.set_script(ExpansionPopupScript)
	add_child(office_expansion_popup)
	office_expansion_popup.zone_purchased.connect(_on_zone_purchased)
	office_expansion_popup.popup_closed.connect(_on_expansion_popup_closed)

	# オフィスビューのメンバータップ → 詳細ポップアップ
	office_view.member_tapped.connect(_on_team_member_selected)

	# TileMapオフィスの初期化
	_setup_tilemap_office()

	_add_log("さあ、経営を始めよう！")
	_update_ui()
	AudioManager.play_bgm("game")

	# 秘書の状態をリセットしてチュートリアル開始
	secretary_popup.reset()
	# チュートリアルガイドモード: tutorial_month == 0 なら game_start トリガー発火
	if GameState.tutorial_month == 0:
		secretary_popup.check_tutorial(GameState, "game_start")

	# デバッグパネルを追加
	_setup_debug_panel()


func _setup_tilemap_office() -> void:
	if not _use_tilemap_office:
		return
	if office_tilemap == null or office_camera == null:
		push_warning("TileMapオフィスノードが見つかりません。従来のOfficeViewを使用します。")
		_use_tilemap_office = false
		return

	# 旧OfficeViewをステータス表示専用モードにし、新TileMapオフィスを有効化
	office_view.tilemap_mode = true
	office_view.custom_minimum_size = Vector2(0, 180)  # ステータス分のみ
	office_viewport_container.visible = true
	print("[TileMapOffice] setup: viewport_container=%s, tilemap=%s, camera=%s" % [office_viewport_container, office_tilemap, office_camera])
	print("[TileMapOffice] viewport size=%s, container size=%s" % [office_viewport.size, office_viewport_container.size])

	# TileMapオフィスを構築
	var phase := _get_current_phase_index()
	office_tilemap.build_office(phase)
	office_tilemap.update_members()
	print("[TileMapOffice] build_office phase=%d, room_px=%s" % [phase, office_tilemap.get_room_pixel_size()])

	# カメラの境界をオフィスサイズに合わせる
	_update_office_camera_bounds()
	print("[TileMapOffice] camera pos=%s, zoom=%s, bounds=%s" % [office_camera.position, office_camera.zoom, office_camera.map_bounds])

	# メンバータップシグナルを接続
	office_tilemap.member_tapped.connect(_on_team_member_selected)

	# UIオーバーレイは一旦無効（既存のVBox内UIと重複するため）
	# TODO: Phase 2でオフィス専用画面として独立させる際に有効化
	#var OverlayScript = load("res://scripts/office_ui_overlay.gd")
	#office_ui_overlay = CanvasLayer.new()
	#office_ui_overlay.set_script(OverlayScript)
	#add_child(office_ui_overlay)

	# 家具配置システムのセットアップ
	var FurniturePlacementScript = load("res://scripts/furniture_placement.gd")
	furniture_placement = Node2D.new()
	furniture_placement.set_script(FurniturePlacementScript)
	office_tilemap.add_child(furniture_placement)
	furniture_placement.placement_completed.connect(_on_furniture_placement_completed)
	furniture_placement.placement_cancelled.connect(_on_furniture_placement_cancelled)
	furniture_placement.furniture_tapped.connect(_on_furniture_tapped)
	# 配置済み家具をレンダリング
	furniture_placement.render_all_furniture()

	# 家具ショップボタン（オフィスビューポートの左下に配置）
	_build_shop_button()


func _update_office_camera_bounds() -> void:
	if office_camera == null or office_tilemap == null:
		return
	var room_px: Vector2 = office_tilemap.get_room_pixel_size()
	# 部屋の範囲 + 大きめの余白（スクロール自由度のため）
	var margin := maxf(200.0, room_px.x)
	office_camera.map_bounds = Rect2(
		-margin, -margin,
		room_px.x + margin * 2, room_px.y + margin * 2
	)
	# カメラを部屋の中央に移動
	office_camera.position = room_px / 2.0

	# デフォルトズーム: タイルが見やすいサイズに拡大
	var default_zoom := 2.0
	office_camera.zoom = Vector2(default_zoom, default_zoom)


func _build_shop_button() -> void:
	var btn := Button.new()
	btn.name = "ShopButton"
	btn.text = "🛒 家具"
	btn.custom_minimum_size = Vector2(100, 44)
	btn.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.48, 0.32, 0.9)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal", style)
	btn.position = Vector2(8, 36)
	btn.pressed.connect(_on_shop_button_pressed)
	office_viewport_container.add_child(btn)

	var expand_btn := Button.new()
	expand_btn.name = "ExpandButton"
	expand_btn.text = "🏗️ 拡張"
	expand_btn.custom_minimum_size = Vector2(100, 44)
	expand_btn.add_theme_font_size_override("font_size", 16)
	var expand_style := StyleBoxFlat.new()
	expand_style.bg_color = Color(0.45, 0.35, 0.15, 0.9)
	expand_style.set_corner_radius_all(6)
	expand_style.content_margin_left = 8.0
	expand_style.content_margin_right = 8.0
	expand_style.content_margin_top = 4.0
	expand_style.content_margin_bottom = 4.0
	expand_btn.add_theme_stylebox_override("normal", expand_style)
	expand_btn.position = Vector2(116, 36)
	expand_btn.pressed.connect(_on_expand_button_pressed)
	office_viewport_container.add_child(expand_btn)


func _get_current_phase_index() -> int:
	var team = GameState.team_size
	if team <= 3:
		return 0
	elif team <= 6:
		return 1
	elif team <= 10:
		return 2
	elif team <= 15:
		return 3
	elif team <= 25:
		return 4
	else:
		return 5


func _refresh_tilemap_office() -> void:
	if not _use_tilemap_office or office_tilemap == null:
		return
	var phase := _get_current_phase_index()
	var old_size: Vector2i = office_tilemap.get_room_size()
	office_tilemap.build_office(phase)
	if office_tilemap.get_room_size() != old_size:
		_update_office_camera_bounds()
	office_tilemap.update_members()
	if furniture_placement:
		furniture_placement.render_all_furniture()
	if office_ui_overlay and office_ui_overlay.has_method("refresh"):
		office_ui_overlay.refresh()


func _setup_debug_panel() -> void:
	var panel_scene = load("res://scenes/debug_panel.tscn")
	if not panel_scene:
		return
	debug_panel = panel_scene.instantiate()
	if not debug_panel:
		return
	debug_panel.visible = false
	add_child(debug_panel)
	if debug_panel.has_method("set_game_node"):
		debug_panel.set_game_node(self)
	if debug_panel.has_method("on_turn_ended"):
		turn_manager.turn_ended.connect(debug_panel.on_turn_ended)


func _toggle_action_menu() -> void:
	AudioManager.play_sfx("click")
	if action_menu_popup.is_open():
		action_menu_popup.hide_menu()
		action_btn.text = "アクション選択 ▲"
	else:
		action_menu_popup.show_menu()
		action_btn.text = "閉じる ▼"


func _on_action_menu_closed() -> void:
	action_btn.text = "アクション選択 ▲"


func _do_action(action: String) -> void:
	action_btn.text = "アクション選択 ▲"
	action_btn.disabled = true

	# チュートリアル中の厳格なアクション制限
	if GameState.tutorial_month >= 0 and action != "history":
		var forced = secretary_popup.get_tutorial_forced_action_for_month(GameState.tutorial_month)
		if forced != null and forced != "" and action != forced:
			_add_log("[color=#E85555]チュートリアル中です。秘書の指示に従ってください。[/color]")
			action_btn.disabled = false
			return

	# チャレンジモードのアクション制限
	if not DifficultyManager.is_action_allowed(action):
		_add_log("[color=#E85555]このチャレンジではそのアクションは使えません。[/color]")
		action_btn.disabled = false
		return

	if action == "history":
		history_popup.show_history(monthly_log)
		action_btn.disabled = false
		return

	if action == "create_product":
		create_product_popup.show_creation()
		return
	elif action == "contract_work":
		_show_contract_selection()
		return
	elif action == "fundraise":
		fundraise_select_popup.show_selection()
	elif action == "hire":
		# 採用ポップアップを表示
		hire_popup.show_candidates([])
	elif action == "marketing":
		marketing_select_popup.show_selection()
	else:
		if action == "develop" and product_manager.get_active_products().size() > 0:
			product_dev_popup.show_features()
		else:
			# 即時実行（develop/team_care等）
			turn_manager.execute_turn(action)


func _show_contract_selection() -> void:
	var choices = []

	# チュートリアル中（月2）は確実に資金を得られる案件のみ
	if GameState.tutorial_month == 2:
		var tutorial_job = {"name": "知人のWebサイトリニューアル", "reward": 1000, "months": 1, "eng_bonus": 2}
		choices.append({
			"label": "%s\n💰%d万円 / %dヶ月（初心者向け）" % [tutorial_job["name"], tutorial_job["reward"], tutorial_job["months"]],
			"effect": func(gs):
				gs.contract_work_remaining = tutorial_job["months"]
				gs.contract_work_name = tutorial_job["name"]
				gs.contract_work_reward = tutorial_job["reward"]
				return "%sを受注！1ヶ月で1000万円の確実な収入です。" % tutorial_job["name"],
		})
	else:
		var jobs = GameState.CONTRACT_JOBS.duplicate()
		jobs.shuffle()
		var selected = jobs.slice(0, 3)
		for job in selected:
			var j = job  # capture for closure
			choices.append({
				"label": "%s\n💰%d万円 / %dヶ月" % [j["name"], j["reward"], j["months"]],
				"effect": func(gs):
					gs.contract_work_remaining = j["months"]
					gs.contract_work_name = j["name"]
					gs.contract_work_reward = j["reward"]
					return "%sを受注！%dヶ月間プロダクト開発が停止します。" % [j["name"], j["months"]],
			})
		choices.append({
			"label": "やめておく",
			"effect": func(gs): return "受託を見送った。",
		})

	var desc_text = "プロダクト開発は停止しますが、確実な収入とエンジニアの成長が得られます。"
	if GameState.tutorial_month == 2:
		desc_text = "知り合いからの簡単な案件です。1ヶ月で完了し、1000万円の報酬がもらえます。"
	var event_data = {
		"title": "🏗️ 受託開発案件",
		"description": desc_text,
		"choices": choices,
	}
	_pending_contract_selection = true
	event_popup.show_event(event_data)


func _on_action_resolved(result_text: String) -> void:
	_add_log(result_text)


func _on_event_triggered(event_data: Dictionary) -> void:
	AudioManager.play_sfx("notification")
	event_popup.show_event(event_data)


func _on_fundraise_type_selected(type_id: String) -> void:
	sugoroku_popup.show_board(type_id)


func _on_fundraise_cancelled() -> void:
	action_btn.disabled = false


# --- マーケティングポップアップコールバック ---

func _on_marketing_channel_selected(channel_id: String) -> void:
	var result := MarketingChannels.apply_effect(channel_id, GameState)
	_update_ui()
	# 結果をイベントポップアップで表示
	var event_data := {
		"title": result.get("title", "マーケティング結果"),
		"description": result.get("description", ""),
		"category": 3,  # 市場カテゴリ
		"choices": [],
	}
	# ポップアップを閉じた後にターン処理を行うため、一時変数に保存
	_pending_marketing_result = result
	event_popup.show_event(event_data)
	# effect_labelを直接セット（choicesが空なのでshow_eventで自動表示される）
	event_popup._effect_label.text = "💰 コスト: %d万円\n\n%s" % [result.get("cost", 0), result.get("effect_text", "")]


func _on_marketing_cancelled() -> void:
	action_btn.disabled = false


func _on_sugoroku_closed(result_text: String) -> void:
	var type_id = sugoroku_popup._selected_type
	var square_idx = sugoroku_popup._target_position
	var square = FundraiseTypes.get_square(type_id, square_idx)
	var type_data = FundraiseTypes.get_type(type_id)
	var log_msg = "🎲 %s: 【%s】→ %s" % [type_data.get("name", ""), square.get("name", ""), result_text]
	_update_ui()
	turn_manager.execute_turn_with_result(log_msg)


# --- 採用ポップアップコールバック ---

func _on_hire_completed(member_data: Dictionary, channel: String, total_cost: int) -> void:
	if GameState.cash < total_cost:
		_add_log("[color=#E85555]資金が足りず採用できなかった。（必要: %d万円）[/color]" % total_cost)
		action_btn.disabled = false
		return

	# TeamMember リソースを作成して採用
	var member := TeamMemberClass.new()
	member.member_name = member_data.get("name", "名無し")
	member.skill_type = member_data.get("skill_type", "engineer")
	member.skill_level = member_data.get("skill_level", 1)
	member.personality = member_data.get("personality", "diligent")
	member.avatar_id = member_data.get("avatar_id", randi_range(1, 70))
	member.role = "member"
	member.months_employed = 0
	member.calculate_salary()

	GameState.cash -= total_cost
	TeamManager.hire(member)
	GameState.team_morale -= 3  # 新人加入による軽い士気低下
	GameState.team_morale = maxi(GameState.team_morale, 0)

	var skill_label := TeamMemberClass.get_skill_label(member.skill_type)
	var personality_label := TeamMemberClass.get_personality_label(member.personality)
	var channel_names := {"agent": "エージェント", "referral": "リファラル", "scout": "スカウト"}
	var channel_name: String = channel_names.get(channel, channel)
	var log_msg := "%s（%s Lv.%d / %s）を%s経由で採用！（採用費 %d万円）" % [
		member.member_name, skill_label, member.skill_level, personality_label, channel_name, total_cost
	]
	# 新メンバーからの挨拶をログメッセージに含める
	var greeting: String = TeamMemberClass.get_greeting(member.member_name, member.skill_type, member.personality)
	var full_msg := log_msg + "\n[color=#88BBDD]💬 %s「%s」[/color]" % [member.member_name, greeting]
	AudioManager.play_sfx("success")
	_update_ui()
	turn_manager.execute_turn_with_result(full_msg)


func _on_hire_with_fire_completed(member_data: Dictionary, fire_member_index: int, channel: String, total_cost: int) -> void:
	if GameState.cash < total_cost:
		_add_log("[color=#E85555]資金が足りず採用できなかった。（必要: %d万円）[/color]" % total_cost)
		action_btn.disabled = false
		return

	# 解雇するメンバー
	if fire_member_index < 0 or fire_member_index >= TeamManager.members.size():
		action_btn.disabled = false
		return
	var fired = TeamManager.members[fire_member_index]
	var fired_name: String = fired.member_name
	var fired_skill: String = TeamMemberClass.get_skill_label(fired.skill_type)
	TeamManager.fire(fired)

	# 新メンバー作成・採用
	var member := TeamMemberClass.new()
	member.member_name = member_data.get("name", "名無し")
	member.skill_type = member_data.get("skill_type", "engineer")
	member.skill_level = member_data.get("skill_level", 1)
	member.personality = member_data.get("personality", "diligent")
	member.avatar_id = member_data.get("avatar_id", randi_range(1, 70))
	member.role = "member"
	member.months_employed = 0
	member.calculate_salary()

	GameState.cash -= total_cost
	TeamManager.hire(member)
	GameState.team_morale -= 5  # 入れ替えによる士気低下（通常より大きい）
	GameState.team_morale = maxi(GameState.team_morale, 0)

	var skill_label := TeamMemberClass.get_skill_label(member.skill_type)
	var personality_label := TeamMemberClass.get_personality_label(member.personality)
	var channel_names := {"agent": "エージェント", "referral": "リファラル", "scout": "スカウト"}
	var channel_name: String = channel_names.get(channel, channel)
	var log_msg := "[color=#E88855]%s（%s）を解雇[/color] → %s（%s Lv.%d / %s）を%s経由で採用！（採用費 %d万円）" % [
		fired_name, fired_skill, member.member_name, skill_label, member.skill_level, personality_label, channel_name, total_cost
	]
	var greeting: String = TeamMemberClass.get_greeting(member.member_name, member.skill_type, member.personality)
	var full_msg := log_msg + "\n[color=#88BBDD]💬 %s「%s」[/color]" % [member.member_name, greeting]
	AudioManager.play_sfx("success")
	_update_ui()
	turn_manager.execute_turn_with_result(full_msg)


func _on_hire_cancelled() -> void:
	action_btn.disabled = false


# --- チーム一覧コールバック ---

func _on_team_btn_pressed() -> void:
	AudioManager.play_sfx("click")
	var members_data: Array = []
	for m in TeamManager.members:
		members_data.append({
			"member_name": m.member_name,
			"skill_type": m.skill_type,
			"skill_level": m.skill_level,
			"personality": m.personality,
			"role": m.role,
			"salary": m.salary,
			"months_employed": m.months_employed,
		})
	team_list_popup.show_team(members_data)


func _on_team_member_selected(member_index: int) -> void:
	if member_index < 0 or member_index >= TeamManager.members.size():
		return
	var m = TeamManager.members[member_index]
	var data := {
		"member_name": m.member_name,
		"skill_type": m.skill_type,
		"skill_level": m.skill_level,
		"personality": m.personality,
		"role": m.role,
		"salary": m.salary,
		"months_employed": m.months_employed,
		"cxo_exists_for_skill": TeamManager.has_cxo(m.skill_type),
	}
	member_detail_popup.show_member(data, member_index)


func _on_team_list_closed() -> void:
	pass


func _on_member_promoted(member_index: int, new_role: String) -> void:
	if member_index < 0 or member_index >= TeamManager.members.size():
		return
	var m = TeamManager.members[member_index]
	var old_role_label := TeamMemberClass.get_role_label(m.role)
	TeamManager.promote(m, new_role)
	var new_role_label: String
	if new_role == "cxo":
		new_role_label = TeamMemberClass.get_cxo_title(m.skill_type)
	else:
		new_role_label = TeamMemberClass.get_role_label(new_role)
	_add_log("🎉 %sが%sから%sに昇進！" % [m.member_name, old_role_label, new_role_label])
	_update_ui()


func _on_member_fired(member_index: int) -> void:
	if member_index < 0 or member_index >= TeamManager.members.size():
		return
	var m = TeamManager.members[member_index]
	var name_str: String = m.member_name
	TeamManager.fire(m)
	_add_log("👋 %sが退職しました。" % name_str)
	_update_ui()


func _on_member_detail_closed() -> void:
	# チーム一覧を再表示
	_on_team_btn_pressed()


func _on_event_popup_closed(_choice_index: int) -> void:
	# 受託開発選択ポップアップの場合
	if _pending_contract_selection:
		_pending_contract_selection = false
		var effect_text = event_popup.get_effect_text()
		if effect_text != "":
			_add_log("[color=#DDA055]🏗️ %s[/color]" % effect_text)
		_update_ui()
		turn_manager.execute_turn_with_result(effect_text)
		return

	# マーケティング結果ポップアップの場合
	if not _pending_marketing_result.is_empty():
		AudioManager.play_sfx("success")
		var r = _pending_marketing_result
		var log_msg := "📢 %s%s: %s" % [r.get("channel_icon", ""), r.get("channel_name", ""), r.get("rating", "")]
		_pending_marketing_result = {}
		_update_ui()
		turn_manager.execute_turn_with_result(log_msg)
		return

	var effect_text = event_popup.get_effect_text()
	var event_title = event_popup._event_data.get("title", "")
	if event_title != "":
		_add_log("[color=#FFD966]【イベント】%s[/color]" % event_title)
	if effect_text != "":
		_add_log("[color=#FFD966]→ %s[/color]" % effect_text)
	_update_ui()
	turn_manager.finish_after_event(effect_text)

	# イベント後の秘書コメンタリー
	var event_id = event_popup._event_data.get("id", "")
	if event_id != "" and secretary_popup.has_method("show_event_commentary"):
		secretary_popup.show_event_commentary(event_id)


func _on_event_resolved(_effect_text: String) -> void:
	pass


func _on_turn_ended() -> void:
	AudioManager.play_sfx("turn_advance")

	# 月別ログを記録
	monthly_log.append({
		"month": GameState.month,
		"cash": GameState.cash,
		"users": GameState.users,
		"revenue": GameState.revenue,
		"team_size": GameState.team_size,
		"events": _current_month_events.duplicate(),
	})
	_current_month_events.clear()

	# 受託開発完了チェック
	if GameState.contract_just_completed:
		AudioManager.play_sfx("cash")
		_add_log("[color=#55CC70]💰 受託開発完了！報酬 %d万円を獲得！[/color]" % GameState.contract_completed_reward)
	# 受託開発中の表示
	elif GameState.contract_work_remaining > 0:
		_add_log("[color=#DDA055]🏗️ 受託開発中: %s（残%dヶ月）[/color]" % [GameState.contract_work_name, GameState.contract_work_remaining])
	var loan_payment := GameState.get_monthly_loan_payment()
	if loan_payment > 0:
		_add_log("[color=#8899AA]— 月末: 固定費 %d万円 / 売上 %d万円 / 返済 %d万円（残債 %d万円）—[/color]" % [GameState.monthly_cost, GameState.revenue, loan_payment, GameState.total_loan_balance])
	else:
		_add_log("[color=#8899AA]— 月末: 固定費 %d万円 / 売上 %d万円 —[/color]" % [GameState.monthly_cost, GameState.revenue])
	_update_ui()

	# プロダクト開発進捗
	var dev_result = product_manager.advance_month()
	if dev_result != "":
		_add_log("[color=#55CC70]%s[/color]" % dev_result)

	# 家具バフの月次適用
	var buff_result = OfficeBuffManager.apply_monthly_buffs()
	if not buff_result.is_empty():
		var buff_text := OfficeBuffManager.get_buff_summary_text()
		if buff_text != "効果なし":
			_add_log("[color=#88CCAA]🪑 オフィス家具効果: %s[/color]" % buff_text)

	# オートセーブ（3ターンごと）
	if GameState.month > 0 and GameState.month % 3 == 0:
		SaveManager.auto_save()

	# 四半期イベント（3ヶ月ごと、チュートリアル後から）
	if GameState.month >= 9 and GameState.month % 3 == 0:
		_trigger_quarterly_event()

	# フェーズ昇格チェック
	var phase_up = phase_manager.check_phase_up(GameState)
	if not phase_up.is_empty():
		AudioManager.play_sfx("success")
		var phase_name = "%s %s" % [phase_up.get("icon", ""), phase_up.get("name", "")]
		_add_log("[color=#FFD966]🎊 フェーズ昇格: %s[/color]" % phase_name)
		GameState.current_phase = phase_manager.current_phase

	# 投資家・メンター月次処理
	var inv_results = investor_manager.advance_month(GameState)
	for r in inv_results:
		if r["type"] == "board_meeting":
			var meeting = r["data"]
			_add_log("[color=#8899CC]%s[/color]" % meeting["title"])
			for msg in meeting["messages"]:
				_add_log("[color=#8899CC]  %s[/color]" % msg)
			GameState.team_morale = clampi(GameState.team_morale + meeting["morale_effect"], 0, 100)
		elif r["type"] == "mentor_met":
			var mentor = r["data"]
			_add_log("[color=#FFD966]%s %sと出会った！「%s」[/color]" % [
				mentor.get("icon", ""), mentor.get("name", ""), mentor.get("advice", "")])
			investor_manager.hire_mentor(mentor["id"])

	# 競合・市場月次処理
	var comp_news = competitor_manager.advance_month(GameState)
	for news in comp_news:
		_add_log("[color=#7799BB]📰 %s[/color]" % news)
	# 競争イベントチェック
	var comp_event = competitor_manager.check_competitive_events(GameState)
	if not comp_event.is_empty():
		_add_log("[color=#DDA055]📊 %s[/color]" % comp_event["title"])
		var effect_type = comp_event.get("effect", "")
		var effect_val = comp_event.get("value", 0)
		if effect_type == "reputation":
			GameState.reputation = clampi(GameState.reputation + effect_val, 0, 100)

	# スピードランタイムリミットチェック
	if DifficultyManager.check_time_limit(GameState):
		GameState.game_over.emit("タイムリミット！12ヶ月以内にIPOできなかった…")
		return

	# 特殊エンディングチェック
	var special_endings = ending_manager.check_special_endings(GameState)
	if not special_endings.is_empty():
		# 最初の特殊エンディングを提案（イベントポップアップ形式）
		var se = special_endings[0]
		var event_data = {
			"title": "📩 " + se.get("name", "") + "の提案",
			"description": se.get("title", "") + "\nこの提案を受け入れますか？",
			"choices": [
				{
					"label": "受け入れる",
					"effect": func(gs):
						gs.set_meta("forced_ending", se.get("id", ""))
						return se.get("name", "") + "を選択！",
				},
				{
					"label": "断って経営を続ける",
					"effect": func(gs):
						return "提案を断り、経営を続ける。",
				},
			],
		}
		event_popup.show_event(event_data)
		return

	# マイルストーンチェック
	var milestone = milestone_manager.check_milestones(GameState)
	if not milestone.is_empty():
		_add_log("[color=#FFD966]🎉 %s[/color]" % milestone.get("title", ""))
		milestone_popup.show_milestone(milestone)
		# ポップアップが閉じてからaction_btnを有効化
		return

	# 実績チェック
	var ach_extra := {}
	var comp_mgr_node = get_node_or_null("CompetitorManager")
	if comp_mgr_node:
		ach_extra["market_share"] = comp_mgr_node.get_player_market_share(GameState)
	ach_extra["met_mentors_count"] = investor_manager.met_mentors.size()
	if product_manager.selected_product_type != "":
		var type_data = product_manager.PRODUCT_TYPES.get(product_manager.selected_product_type, {})
		var total_feats = type_data.get("features", []).size()
		ach_extra["all_features_done"] = product_manager.developed_features.size() >= total_feats
	var new_achievements = achievement_manager.check(GameState, ach_extra)
	for ach in new_achievements:
		achievement_popup.show_achievement(ach)
		_add_log("[color=#FFD966]🏆 実績解除: %s %s[/color]" % [ach.get("icon", ""), ach.get("name", "")])

	# チュートリアル進行
	if GameState.tutorial_month >= 0:
		GameState.tutorial_month += 1
		if GameState.tutorial_month >= 7:
			GameState.tutorial_month = -1  # チュートリアル完了
			secretary_popup._tutorial_completed = true
		else:
			var trigger = "month_%d" % GameState.tutorial_month
			secretary_popup.check_tutorial(GameState, trigger)
		# チュートリアル進行後にメニュー制限を更新
		_update_ui()

	# 秘書アドバイスチェック（状況別アドバイス優先）
	if secretary_popup.check_situation_advice(GameState):
		return

	action_btn.disabled = false


func _on_milestone_popup_closed() -> void:
	# マイルストーン後に秘書アドバイスをチェック
	if secretary_popup.check_situation_advice(GameState):
		return
	action_btn.disabled = false


# --- 投資家コールバック ---

func _on_investor_mood_changed(investor_id: String, mood: String) -> void:
	var inv = investor_manager.INVESTORS.get(investor_id, {})
	var name_str = inv.get("name", "投資家")
	match mood:
		"unhappy":
			AudioManager.play_sfx("negative")
			_add_log("[color=#E85555]😠 %sの不満が高まっている…[/color]" % name_str)
		"happy":
			_add_log("[color=#55CC70]😊 %sが成長に満足しています[/color]" % name_str)


# --- 競合・市場コールバック ---

func _on_competitor_news(news_text: String) -> void:
	pass  # ニュースは advance_month で処理済み


# --- 秘書コールバック ---

func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	var new_data = phase_manager.get_phase_data(new_phase)
	_add_log("[color=#55CC70]%s %s — %s[/color]" % [
		new_data.get("icon", ""), new_data.get("name", ""),
		new_data.get("description", "")])

	# フェーズ進行に連動したチュートリアル
	secretary_popup.check_tutorial(GameState, "phase_%d" % new_phase)


func _on_secretary_finished() -> void:
	action_btn.disabled = false


# --- セーブ/ロードコールバック ---

func _on_save_completed(slot: String) -> void:
	var slot_names := {"slot_1": "スロット1", "slot_2": "スロット2", "slot_3": "スロット3", "auto_save": "オートセーブ"}
	_add_log("[color=#55CC70]💾 %sにセーブしました。[/color]" % slot_names.get(slot, slot))


func _on_load_completed(_slot: String) -> void:
	# ロード後にUI全体を更新
	_update_ui()
	log_text = ""
	_add_log("📂 セーブデータをロードしました。")
	# マイルストーンの達成状況をリセット（ロードしたデータに合わせて再チェック不要）
	milestone_manager.reset()

	# 家具配置を再描画
	if furniture_placement:
		furniture_placement.render_all_furniture()


# --- 24時間サイクルコールバック ---

func _on_hour_changed(day: int, hour: float) -> void:
	var h = int(hour)
	var m = int((hour - h) * 60)
	if day_label:
		day_label.text = "Day %d  %02d:%02d" % [day, h, m]
	office_view.queue_redraw()
	_refresh_tilemap_office()


func _on_day_started(day: int) -> void:
	pass


func _on_day_ended(day: int) -> void:
	pass


func _on_month_completed() -> void:
	# スピードバーを非表示
	if speed_bar:
		speed_bar.visible = false
	if day_label:
		day_label.text = ""
	# 月末処理（既存のターン処理に委譲）
	var action = day_cycle.monthly_action
	if action == "develop":
		var result = "開発に集中した月。チームの成果がプロダクトに反映された。"
		turn_manager.execute_turn_with_result(result)
	elif action == "team_care":
		var gain = randi_range(10, 20)
		GameState.team_morale = mini(GameState.team_morale + gain, 100)
		turn_manager.execute_turn_with_result("チームケアの月。士気 +%d" % gain)
	else:
		turn_manager.execute_turn_with_result(day_cycle.monthly_action)


func _on_speed_1x_pressed() -> void:
	AudioManager.play_sfx("click")
	day_cycle.set_speed(1.0)
	_update_speed_buttons(1.0)

func _on_speed_2x_pressed() -> void:
	AudioManager.play_sfx("click")
	day_cycle.set_speed(2.0)
	_update_speed_buttons(2.0)

func _on_speed_4x_pressed() -> void:
	AudioManager.play_sfx("click")
	day_cycle.set_speed(4.0)
	_update_speed_buttons(4.0)

func _on_pause_pressed() -> void:
	AudioManager.play_sfx("click")
	day_cycle.toggle_pause()

func _on_overtime_pressed() -> void:
	AudioManager.play_sfx("click")
	day_cycle.toggle_overtime()
	GameState.overtime_enabled = day_cycle.overtime_enabled
	if speed_bar:
		var btn = speed_bar.get_node("OvertimeBtn")
		btn.text = "残業ON" if day_cycle.overtime_enabled else "残業OFF"

func _update_speed_buttons(current: float) -> void:
	if not speed_bar:
		return
	for child in speed_bar.get_children():
		if child is Button:
			child.disabled = false
	# Highlight the active speed button
	match current:
		1.0:
			speed_bar.get_node("Speed1x").disabled = true
		2.0:
			speed_bar.get_node("Speed2x").disabled = true
		4.0:
			speed_bar.get_node("Speed4x").disabled = true


# --- プロダクト開発コールバック ---

func _on_feature_dev_selected(feature_id: String) -> void:
	if product_manager.start_feature_dev(feature_id):
		var feat = product_manager.FEATURES.get(feature_id, {})
		_add_log("🔨 %s %sの開発を開始（%dヶ月予定）" % [
			feat.get("icon", ""), feat.get("name", ""), feat.get("months", 1)])
	# 即時ターン実行（パラメータ変化を表示）
	var result: String = GameState.apply_action("develop")
	AudioManager.play_sfx("success")
	_update_ui()
	turn_manager.execute_turn_with_result(result)


func _on_debt_repair_selected() -> void:
	var result = product_manager.pay_tech_debt()
	_add_log("🔧 " + result)
	turn_manager.execute_turn_with_result(result)


func _on_product_dev_cancelled() -> void:
	action_btn.disabled = false


# --- プロダクト作成コールバック ---

func _on_product_creation_completed(config: Dictionary) -> void:
	var result = product_manager.create_product_with_config(config)
	_add_log("📦 " + result)
	_update_ui()
	turn_manager.execute_turn_with_result(result)


func _on_create_product_cancelled() -> void:
	action_btn.disabled = false


func _on_feature_completed(feature: Dictionary) -> void:
	AudioManager.play_sfx("success")
	var feat_name: String = "%s %s" % [feature.get("icon", ""), feature.get("name", "")]
	_add_log("[color=#55CC70]✅ %sが完成！[/color]" % feat_name)

	# 効果詳細モーダルを表示
	var effects: Dictionary = feature.get("applied_effects", {})
	var stat_labels := {"ux": "UX品質", "design": "デザイン", "margin": "利益率", "awareness": "知名度"}
	var stat_icons := {"ux": "⚡", "design": "🎨", "margin": "💰", "awareness": "📢"}
	var effect_lines: Array[String] = []
	for key in effects:
		if effects[key] > 0:
			effect_lines.append("%s %s +%d" % [stat_icons.get(key, ""), stat_labels.get(key, key), effects[key]])
	var product_name: String = feature.get("product_name", "")
	var desc: String = ""
	if product_name != "":
		desc += "%sの新機能が完成しました！\n\n" % product_name
	if effect_lines.is_empty():
		desc += "プロダクトが強化されました。"
	else:
		desc += "【ステータス変化】\n" + "\n".join(effect_lines)
		desc += "\n\n利益率の上昇はMRR（月間売上）に直結します！"
	var event_data := {
		"title": "✅ 機能完成: %s" % feat_name,
		"description": desc,
		"choices": [],
	}
	event_popup.show_event(event_data)


func _on_tech_debt_warning(debt_level: int) -> void:
	AudioManager.play_sfx("negative")
	_add_log("[color=#E85555]⚠️ 技術的負債が危険水準に！(%d/100)[/color]" % debt_level)


func _on_emergency_fundraise(amount: int, dilution: float) -> void:
	AudioManager.play_sfx("notification")
	_add_log("[color=#FFD966]⚠️ 資金が底をつきそうに！緊急資金調達を実施しました。[/color]")
	_add_log("[color=#FFD966]💵 調達額: %d万円（持株 -%.1f%%）[/color]" % [amount, dilution])
	_update_ui()


func _on_game_over(reason: String) -> void:
	AudioManager.play_sfx("fail")
	_add_log("[color=#E85555]%s[/color]" % reason)
	action_btn.disabled = true
	GameState.set_meta("forced_ending", "bankruptcy")
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _on_game_clear(reason: String) -> void:
	AudioManager.play_sfx("cash")
	_add_log("[color=#55CC70]%s[/color]" % reason)
	action_btn.disabled = true
	if not GameState.has_meta("forced_ending") or GameState.get_meta("forced_ending") == "":
		GameState.set_meta("forced_ending", "ipo")
	# ゲームクリア時の実績チェック
	var clear_achievements = achievement_manager.check_on_clear(GameState)
	for ach in clear_achievements:
		achievement_popup.show_achievement(ach)
	await get_tree().create_timer(2.0).timeout
	get_node("/root/Main").change_scene("res://scenes/result.tscn")


func _update_ui() -> void:
	# フェーズ表示
	month_label.text = "%s %dヶ月目" % [phase_manager.get_phase_name(), GameState.month + 1]

	# 資金 - 色を残高で変える
	var cash_color: Color
	if GameState.cash <= 200:
		cash_color = Color(0.90, 0.40, 0.35)
	elif GameState.cash <= 500:
		cash_color = Color(0.90, 0.75, 0.30)
	else:
		cash_color = Color(0.55, 0.85, 0.55)
	cash_label.text = "💰 %d万円" % GameState.cash
	cash_label.add_theme_color_override("font_color", cash_color)

	# オフィスビジュアル更新
	office_view.refresh()
	_refresh_tilemap_office()

	# チームボタンのメンバー数表示
	team_btn.text = "👥 %d人" % GameState.team_size

	# アクションメニューポップアップの状態更新
	if action_menu_popup:
		action_menu_popup.update_hire_btn()
		action_menu_popup.update_fundraise_btn(GameState.fundraise_cooldown)
		action_menu_popup.update_contract_state(GameState)
		# プロダクト作成ボタン状態更新
		var active_products = product_manager.get_active_products()
		var has_pm = TeamManager.has_cxo("pm") or not TeamManager.get_members_by_skill("pm").is_empty()
		action_menu_popup.update_create_product_btn(active_products.size(), has_pm)

		# チュートリアル中のアクション制限（最後に呼ぶことで他のupdateを上書き）
		if GameState.tutorial_month >= 0:
			var forced = secretary_popup.get_tutorial_forced_action_for_month(GameState.tutorial_month)
			if forced != null and forced != "":
				action_menu_popup.update_tutorial_state(forced)
			elif forced == "":
				# 全解放（チュートリアル完了）
				GameState.tutorial_month = -1
				secretary_popup._tutorial_completed = true


func _toggle_log_expand() -> void:
	_log_expanded = not _log_expanded
	if _log_expanded:
		log_label.custom_minimum_size.y = 400
		log_expand_btn.text = "▼ 経営ログ（タップで縮小）"
	else:
		log_label.custom_minimum_size.y = 100
		log_expand_btn.text = "▲ 経営ログ（タップで拡大）"


func _add_log(text: String) -> void:
	log_text += text + "\n"
	log_label.text = log_text
	# BBCodeタグを除去して履歴用に保存
	var plain = text
	var regex = RegEx.new()
	regex.compile("\\[/?[a-zA-Z_=# 0-9]*\\]")
	plain = regex.sub(plain, "", true)
	_current_month_events.append(plain)
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count())


var _first_quarterly_done := false

func _trigger_quarterly_event() -> void:
	var quarter = GameState.month / 3
	var rev = GameState.revenue
	var u = GameState.users
	var team = GameState.team_size

	# 初回は秘書が事前説明
	if not _first_quarterly_done:
		_first_quarterly_done = true
		secretary_popup.show_dialogue([
			"社長、初めての四半期レビューの時間です！",
			"3ヶ月ごとに業績を振り返り、評価が行われます。",
			"好調なら士気UP・ボーナス、低迷なら士気DOWNとなります。",
			"売上やユーザー数を伸ばして、良い評価を目指しましょう！",
		])
		# 秘書ダイアログが閉じた後に実際のイベントを表示
		await secretary_popup.dialogue_finished

	# 評価判定
	var rating := "普通"
	var morale_effect := 0
	var cash_bonus := 0
	var reputation_effect := 0

	if rev >= 200 and u >= 1000:
		rating = "好調"
		morale_effect = 10
		cash_bonus = 100
		reputation_effect = 5
	elif rev >= 50 or u >= 500:
		rating = "まずまず"
		morale_effect = 3
		reputation_effect = 2
	elif rev <= 0 and GameState.month >= 9:
		rating = "低迷"
		morale_effect = -10
		reputation_effect = -5

	var description := "第%d四半期の業績レビュー\n\n" % quarter
	description += "📊 MRR: %d万円\n" % rev
	description += "📱 ユーザー: %s人\n" % _format_number_local(u)
	description += "👥 チーム: %d人\n\n" % team
	description += "総合評価: 【%s】" % rating

	var effect_text := ""
	if morale_effect != 0:
		GameState.team_morale = clampi(GameState.team_morale + morale_effect, 0, 100)
		effect_text += "士気 %+d " % morale_effect
	if cash_bonus > 0:
		GameState.cash += cash_bonus
		effect_text += "ボーナス +%d万 " % cash_bonus
	if reputation_effect != 0:
		GameState.reputation = clampi(GameState.reputation + reputation_effect, 0, 100)
		effect_text += "評判 %+d" % reputation_effect

	var event_data := {
		"title": "📅 第%d四半期 取締役会" % quarter,
		"description": description,
		"choices": [],
	}
	event_popup.show_event(event_data)
	if effect_text != "":
		event_popup._effect_label.text = effect_text
	_add_log("[color=#8899CC]📅 Q%d取締役会: %s[/color]" % [quarter, rating])


# --- 家具ショップ/配置コールバック ---

func _on_shop_button_pressed() -> void:
	if GameState.tutorial_month >= 0:
		_add_log("[color=#E85555]チュートリアル完了後に利用できます。[/color]")
		return
	AudioManager.play_sfx("click")
	furniture_shop_popup.show_shop()

func _on_furniture_purchased(item_id: String) -> void:
	var item = FurnitureData.get_item(item_id)
	_add_log("🛒 %sを購入！（%d万円）" % [item.get("name", ""), item.get("cost", 0)])
	_update_ui()

func _on_furniture_placement_requested(item_id: String) -> void:
	# ショップから配置要求された場合
	if furniture_placement:
		furniture_placement.start_placement(item_id)

func _on_furniture_shop_closed() -> void:
	pass

func _on_furniture_placement_completed(item_id: String, grid_pos: Vector2i) -> void:
	var item = FurnitureData.get_item(item_id)
	_add_log("🪑 %sを配置しました！" % item.get("name", ""))
	AudioManager.play_sfx("success")
	_update_ui()

func _on_furniture_placement_cancelled() -> void:
	pass

func _on_furniture_tapped(instance_id: int) -> void:
	# 配置モード中はタップを無視
	if furniture_placement and furniture_placement.is_in_placement_mode():
		return
	furniture_detail_popup.show_detail(instance_id)

func _on_furniture_sold(instance_id: int) -> void:
	AudioManager.play_sfx("cash")
	_add_log("💰 家具を売却しました。")
	if furniture_placement:
		furniture_placement.remove_furniture_sprite(instance_id, true)
	_update_ui()

func _on_furniture_move_requested(instance_id: int) -> void:
	# 移動: 一旦撤去してインベントリに戻し、配置モードを開始
	var item_id := FurnitureManager.remove_furniture(instance_id)
	if item_id != "" and furniture_placement:
		furniture_placement.remove_furniture_sprite(instance_id)
		furniture_placement.start_placement(item_id)

func _on_furniture_upgraded(instance_id: int, new_item_id: String) -> void:
	AudioManager.play_sfx("success")
	var item = FurnitureData.get_item(new_item_id)
	_add_log("⬆ %sにアップグレード！" % item.get("name", ""))
	# 全家具を再描画（旧家具削除 + 新家具追加をまとめて処理）
	if furniture_placement:
		furniture_placement.render_all_furniture()
	_update_ui()

func _on_furniture_detail_closed() -> void:
	pass


func _on_expand_button_pressed() -> void:
	if GameState.tutorial_month >= 0:
		_add_log("[color=#E85555]チュートリアル完了後に利用できます。[/color]")
		return
	AudioManager.play_sfx("click")
	office_expansion_popup.show_popup()


func _on_zone_purchased(zone_id: String) -> void:
	var zone = OfficeExpansionManager.get_zone(zone_id)
	AudioManager.play_sfx("success")
	_add_log("🏗️ %s %sを建設！" % [zone.get("icon", ""), zone.get("name", "")])
	# 部屋サイズが変わった可能性があるのでオフィスを再構築
	_refresh_tilemap_office()
	_update_ui()


func _on_expansion_popup_closed() -> void:
	pass


func _format_number_local(n: int) -> String:
	if n >= 100000000:
		return "%.1f億" % (n / 100000000.0)
	elif n >= 10000:
		return "%d万" % (n / 10000) if n >= 100000 else str(n)
	return str(n)
