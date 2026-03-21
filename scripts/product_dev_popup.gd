extends CanvasLayer
## プロダクト開発ポップアップ — プロダクト選択・機能開発・KPIダッシュボード・撤退

signal feature_selected(feature_id: String)
signal debt_repair_selected
signal cancelled

var _panel: PanelContainer
var _vbox: VBoxContainer
var _product_manager: Node  # Reference set externally


func _ready() -> void:
	layer = 100
	_build_ui()
	_panel.visible = false


func set_product_manager(pm: Node) -> void:
	_product_manager = pm


func show_features() -> void:
	if not _product_manager:
		return
	_clear_buttons()
	_panel.visible = true

	# ヘッダー
	var title_label = Label.new()
	title_label.text = "🔨 プロダクト開発"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_vbox.add_child(title_label)

	# KPIサマリー
	_add_kpi_summary()

	# プロダクト選択（複数プロダクトがある場合）
	var active_products = _product_manager.get_active_products()
	if active_products.size() > 1:
		_add_product_selector(active_products)

	# 現在選択中プロダクトの情報
	var current = _product_manager._get_active_product()
	if not current.is_empty():
		var type_data = _product_manager.PRODUCT_TYPES.get(current["type"], {})
		var product_info = Label.new()
		var maint_cost = type_data.get("monthly_maintenance", 0)
		product_info.text = "%s %s（メンテ: %d万円/月）" % [
			type_data.get("icon", ""), current.get("name", ""), maint_cost]
		product_info.add_theme_font_size_override("font_size", 22)
		product_info.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		product_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(product_info)

	# 現在開発中の表示
	if _product_manager.developing_feature != "":
		var dev_feat = _product_manager.FEATURES.get(_product_manager.developing_feature, {})
		var dev_label = Label.new()
		dev_label.text = "🚧 開発中: %s %s（残り%dヶ月）" % [
			dev_feat.get("icon", ""), dev_feat.get("name", ""),
			_product_manager.dev_remaining_months]
		dev_label.add_theme_font_size_override("font_size", 20)
		dev_label.add_theme_color_override("font_color", Color(0.90, 0.75, 0.30))
		dev_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_vbox.add_child(dev_label)

	# 技術的負債表示
	if _product_manager.tech_debt > 0:
		var debt_label = Label.new()
		var debt_color = Color(0.90, 0.40, 0.35) if _product_manager.tech_debt >= 60 else Color(0.90, 0.75, 0.30)
		debt_label.text = "⚠️ 技術的負債: %d/100" % _product_manager.tech_debt
		debt_label.add_theme_font_size_override("font_size", 20)
		debt_label.add_theme_color_override("font_color", debt_color)
		_vbox.add_child(debt_label)

		# 負債返済ボタン
		if _product_manager.developing_feature == "" and _product_manager.tech_debt >= 20:
			var debt_btn = Button.new()
			debt_btn.text = "🔧 技術的負債を返済する（1ターン消費）"
			debt_btn.custom_minimum_size = Vector2(0, 50)
			debt_btn.add_theme_font_size_override("font_size", 20)
			debt_btn.pressed.connect(func():
				debt_repair_selected.emit()
				_panel.visible = false)
			_vbox.add_child(debt_btn)

	# 開発可能な機能一覧
	var features = _product_manager.get_available_features()
	if features.is_empty() and _product_manager.developing_feature == "":
		var done_label = Label.new()
		done_label.text = "全機能の開発が完了！"
		done_label.add_theme_font_size_override("font_size", 22)
		done_label.add_theme_color_override("font_color", Color(0.55, 0.85, 0.55))
		done_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(done_label)
	elif _product_manager.developing_feature == "":
		for feat in features:
			var btn = Button.new()
			var can_afford = GameState.cash >= feat["cost"]
			btn.text = "%s %s（%d万円 / %dヶ月 / 力+%d）" % [
				feat.get("icon", ""), feat["name"], feat["cost"],
				feat["months"], feat["power"]]
			btn.custom_minimum_size = Vector2(0, 50)
			btn.add_theme_font_size_override("font_size", 20)
			btn.disabled = not can_afford
			var fid = feat["id"]
			btn.pressed.connect(func():
				feature_selected.emit(fid)
				_panel.visible = false)
			_vbox.add_child(btn)

	# サービス撤退ボタン（プロダクトが2つ以上ある場合のみ）
	if active_products.size() > 1 and not current.is_empty():
		_add_separator()
		var shutdown_btn = Button.new()
		shutdown_btn.text = "🚫 %sをサービス終了する" % current.get("name", "")
		shutdown_btn.custom_minimum_size = Vector2(0, 50)
		shutdown_btn.add_theme_font_size_override("font_size", 20)
		shutdown_btn.add_theme_color_override("font_color", Color(0.90, 0.40, 0.35))
		var idx = _product_manager.active_product_index
		shutdown_btn.pressed.connect(func():
			var result = _product_manager.shutdown_product(idx)
			# 再表示
			show_features())
		_vbox.add_child(shutdown_btn)

	# メンテコスト合計表示
	var total_maint = _product_manager.get_total_maintenance_cost()
	if total_maint > 0:
		var maint_label = Label.new()
		maint_label.text = "💰 メンテコスト合計: %d万円/月" % total_maint
		maint_label.add_theme_font_size_override("font_size", 18)
		maint_label.add_theme_color_override("font_color", Color(0.80, 0.65, 0.50))
		maint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_vbox.add_child(maint_label)

	# 閉じるボタン
	var close_btn = Button.new()
	close_btn.text = "閉じる"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.pressed.connect(func():
		cancelled.emit()
		_panel.visible = false)
	_vbox.add_child(close_btn)


## KPIサマリーを表示
func _add_kpi_summary() -> void:
	var history = GameState.monthly_history
	if history.size() == 0:
		return

	var kpi_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.20, 0.30, 0.8)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	kpi_panel.add_theme_stylebox_override("panel", style)

	var kpi_vbox = VBoxContainer.new()
	kpi_vbox.add_theme_constant_override("separation", 4)

	var kpi_title = Label.new()
	kpi_title.text = "📊 KPIサマリー"
	kpi_title.add_theme_font_size_override("font_size", 22)
	kpi_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	kpi_vbox.add_child(kpi_title)

	var latest = history.back()
	var prev = history[maxi(history.size() - 2, 0)]
	var mrr_change = latest.get("revenue", 0) - prev.get("revenue", 0)
	var user_change = latest.get("users", 0) - prev.get("users", 0)

	var mrr_label = Label.new()
	var mrr_sign = "+" if mrr_change >= 0 else ""
	mrr_label.text = "MRR: %d万円 (%s%d)" % [latest.get("revenue", 0), mrr_sign, mrr_change]
	mrr_label.add_theme_font_size_override("font_size", 18)
	var mrr_color = Color(0.55, 0.85, 0.55) if mrr_change >= 0 else Color(0.90, 0.40, 0.35)
	mrr_label.add_theme_color_override("font_color", mrr_color)
	kpi_vbox.add_child(mrr_label)

	var user_label = Label.new()
	var user_sign = "+" if user_change >= 0 else ""
	user_label.text = "ユーザー: %d人 (%s%d)" % [latest.get("users", 0), user_sign, user_change]
	user_label.add_theme_font_size_override("font_size", 18)
	var user_color = Color(0.55, 0.85, 0.55) if user_change >= 0 else Color(0.90, 0.40, 0.35)
	user_label.add_theme_color_override("font_color", user_color)
	kpi_vbox.add_child(user_label)

	var burn_label = Label.new()
	burn_label.text = "バーンレート: %d万円/月" % latest.get("monthly_cost", 0)
	burn_label.add_theme_font_size_override("font_size", 18)
	burn_label.add_theme_color_override("font_color", Color(0.80, 0.75, 0.65))
	kpi_vbox.add_child(burn_label)

	# ミニスパークライン（直近6ヶ月のMRR推移をテキストで表示）
	if history.size() >= 3:
		var spark_text = "MRR推移: "
		var start_idx = maxi(history.size() - 6, 0)
		for j in range(start_idx, history.size()):
			var rev = history[j].get("revenue", 0)
			if j > start_idx:
				var prev_rev = history[j - 1].get("revenue", 0)
				if rev > prev_rev:
					spark_text += "↑"
				elif rev < prev_rev:
					spark_text += "↓"
				else:
					spark_text += "→"
			spark_text += "%d " % rev
		var spark_label = Label.new()
		spark_label.text = spark_text
		spark_label.add_theme_font_size_override("font_size", 16)
		spark_label.add_theme_color_override("font_color", Color(0.65, 0.70, 0.80))
		spark_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		kpi_vbox.add_child(spark_label)

	kpi_panel.add_child(kpi_vbox)
	_vbox.add_child(kpi_panel)


## プロダクト選択UI（複数プロダクトがある場合）
func _add_product_selector(active_products: Array[Dictionary]) -> void:
	var selector_hbox = HBoxContainer.new()
	selector_hbox.add_theme_constant_override("separation", 8)
	selector_hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	for i in _product_manager.products.size():
		var p = _product_manager.products[i]
		if not p.get("active", true):
			continue
		var type_data = _product_manager.PRODUCT_TYPES.get(p["type"], {})
		var btn = Button.new()
		btn.text = "%s %s" % [type_data.get("icon", ""), p.get("name", "")]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.add_theme_font_size_override("font_size", 18)
		if i == _product_manager.active_product_index:
			btn.disabled = true  # 現在選択中
		var idx = i
		btn.pressed.connect(func():
			_product_manager.select_active_product(idx)
			show_features())  # 再表示
		selector_hbox.add_child(btn)

	_vbox.add_child(selector_hbox)


## セパレータ追加
func _add_separator() -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_vbox.add_child(sep)


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.05
	_panel.anchor_right = 0.95
	_panel.anchor_top = 0.1
	_panel.anchor_bottom = 0.9
	KenneyTheme.apply_panel_style(_panel, "popup")

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(_vbox)

	add_child(_panel)


func _clear_buttons() -> void:
	for child in _vbox.get_children():
		child.queue_free()
