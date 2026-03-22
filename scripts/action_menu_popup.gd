extends CanvasLayer
## アクションメニューポップアップ
## 画面下部からスライドアップするアクションメニュー

signal action_selected(action: String)
signal menu_closed

var _is_open := false
var _panel_root: Control
var _overlay: ColorRect
var _menu_panel: PanelContainer
var _buttons_vbox: VBoxContainer
var _create_product_btn: Button
var _develop_btn: Button
var _hire_btn: Button
var _marketing_btn: Button
var _fundraise_btn: Button
var _contract_btn: Button
var _team_care_btn: Button
var _history_btn: Button

const COLOR_OVERLAY := Color(0, 0, 0, 0.5)
const COLOR_PANEL_BG := Color(0.10, 0.12, 0.18)
const COLOR_PANEL_BORDER := Color(0.25, 0.35, 0.50)
const COLOR_BTN_BG := Color(0.15, 0.18, 0.26)
const COLOR_BTN_HOVER := Color(0.20, 0.24, 0.34)
const COLOR_TEXT := Color(1.0, 1.0, 1.0)


func _ready() -> void:
	layer = 50
	_build_ui()
	_panel_root.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	get_viewport().set_input_as_handled()


func show_menu() -> void:
	_panel_root.visible = true
	_is_open = true


func hide_menu() -> void:
	_panel_root.visible = false
	_is_open = false


func is_open() -> bool:
	return _is_open


func update_fundraise_btn(cooldown: int) -> void:
	if cooldown > 0:
		_fundraise_btn.text = "💵 資金調達 (あと%dヶ月)" % cooldown
		_fundraise_btn.disabled = true
	else:
		_fundraise_btn.text = "💵 資金調達"
		_fundraise_btn.disabled = false


func update_hire_btn() -> void:
	var current := TeamManager.members.size()
	var max_m: int = TeamManager.get_max_members()
	if current >= max_m:
		_hire_btn.text = "👤 採用する（%d/%d 入替のみ）" % [current, max_m]
	else:
		_hire_btn.text = "👤 採用する（%d/%d）" % [current, max_m]
	_hire_btn.disabled = false
	_history_btn.disabled = false


func update_create_product_btn(active_count: int, has_pm: bool) -> void:
	if active_count >= 3:
		_create_product_btn.text = "📦 プロダクト上限（3/3）"
		_create_product_btn.disabled = true
	elif not has_pm:
		_create_product_btn.text = "📦 プロダクトを作る（PM必要）"
		_create_product_btn.disabled = true
	else:
		_create_product_btn.text = "📦 プロダクトを作る（%d/3）" % active_count
		_create_product_btn.disabled = false


func update_contract_state(gs) -> void:
	if gs.contract_work_remaining > 0:
		# 受託中: 開発・マーケ・資金調達を無効化、受託ボタンに残り表示
		_develop_btn.disabled = true
		_marketing_btn.disabled = true
		_fundraise_btn.disabled = true
		_contract_btn.text = "🏗️ 受託中: %s（残%dヶ月）" % [gs.contract_work_name, gs.contract_work_remaining]
		_contract_btn.disabled = true
	else:
		_develop_btn.disabled = false
		_marketing_btn.disabled = false
		_contract_btn.text = "🏗️ 受託開発"
		_contract_btn.disabled = false


## フェーズに応じたアクション制限（チュートリアル完了後に適用）
func update_phase_state(_current_phase: int) -> void:
	pass


## チュートリアル中のボタン制限
func update_tutorial_state(forced_action: String) -> void:
	if forced_action == "":
		# 全解放
		_create_product_btn.disabled = false
		_develop_btn.disabled = false
		_hire_btn.disabled = false
		_marketing_btn.disabled = false
		_fundraise_btn.disabled = false
		_contract_btn.disabled = false
		_team_care_btn.disabled = false
		_history_btn.disabled = false
		return
	# 強制アクション以外を無効化
	_create_product_btn.disabled = (forced_action != "create_product")
	_develop_btn.disabled = (forced_action != "develop")
	_hire_btn.disabled = (forced_action != "hire")
	_marketing_btn.disabled = (forced_action != "marketing")
	_fundraise_btn.disabled = (forced_action != "fundraise")
	_contract_btn.disabled = (forced_action != "contract_work")
	_team_care_btn.disabled = (forced_action != "team_care")
	_history_btn.disabled = true  # チュートリアル中はログも無効


func _on_action_pressed(action: String) -> void:
	AudioManager.play_sfx("click")
	hide_menu()
	action_selected.emit(action)


func _on_overlay_pressed() -> void:
	AudioManager.play_sfx("click")
	hide_menu()
	menu_closed.emit()


func _build_ui() -> void:
	_panel_root = Control.new()
	_panel_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_root)

	# 半透明オーバーレイ（タップで閉じる）
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = COLOR_OVERLAY
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_overlay_pressed()
	)
	_panel_root.add_child(_overlay)

	# メニューパネル（画面下部に配置）
	_menu_panel = PanelContainer.new()
	KenneyTheme.apply_panel_style(_menu_panel, "popup")
	_menu_panel.anchor_left = 0.0
	_menu_panel.anchor_right = 1.0
	_menu_panel.anchor_top = 0.25
	_menu_panel.anchor_bottom = 1.0
	_menu_panel.offset_left = 0
	_menu_panel.offset_right = 0
	_menu_panel.offset_top = 0
	_menu_panel.offset_bottom = 0
	_menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_root.add_child(_menu_panel)

	# スクロールコンテナ（ボタンが多い場合にスクロール可能）
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu_panel.add_child(scroll)

	# ボタン用VBox
	_buttons_vbox = VBoxContainer.new()
	_buttons_vbox.add_theme_constant_override("separation", 8)
	_buttons_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_buttons_vbox)

	# アクションボタンを生成（各アクションに色を割当）
	_create_product_btn = _create_action_btn("📦 プロダクトを作る", "create_product", "blue")
	_develop_btn = _create_action_btn("🔨 開発に集中", "develop", "blue")
	_hire_btn = _create_action_btn("👤 採用する", "hire", "green")
	_marketing_btn = _create_action_btn("📣 マーケティング", "marketing", "yellow")
	_fundraise_btn = _create_action_btn("💵 資金調達", "fundraise", "green")
	_contract_btn = _create_action_btn("🏗️ 受託開発", "contract_work", "yellow")
	_team_care_btn = _create_action_btn("❤️ チームケア", "team_care", "red")

	_history_btn = _create_action_btn("📋 経営ログ", "history", "grey")

	_buttons_vbox.add_child(_create_product_btn)
	_buttons_vbox.add_child(_develop_btn)
	_buttons_vbox.add_child(_hire_btn)
	_buttons_vbox.add_child(_marketing_btn)
	_buttons_vbox.add_child(_fundraise_btn)
	_buttons_vbox.add_child(_contract_btn)
	_buttons_vbox.add_child(_team_care_btn)
	_buttons_vbox.add_child(_history_btn)


func _create_action_btn(text: String, action: String, color: String = "blue") -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 56)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	KenneyTheme.apply_button_style(btn, color)
	btn.pressed.connect(_on_action_pressed.bind(action))
	return btn
