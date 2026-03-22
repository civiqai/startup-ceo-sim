extends MarginContainer
## SafeArea対応のMarginContainer
## DisplayServer.get_display_safe_area() を使って自動的にマージンを設定する

func _ready() -> void:
	_update_safe_area()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED:
		_update_safe_area()

func _update_safe_area() -> void:
	var screen_size: Vector2 = DisplayServer.window_get_size()
	if screen_size.x <= 0 or screen_size.y <= 0:
		return

	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var viewport_size: Vector2 = get_viewport_rect().size

	# safe_areaが無効（サイズ0やウィンドウ範囲外）ならマージン0にする
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		return
	if safe_area.end.x > screen_size.x or safe_area.end.y > screen_size.y:
		# デスクトップ等でsafe_areaがスクリーン座標を返す場合はスキップ
		return

	# デバイス座標からビューポート座標へのスケール変換
	var scale_x: float = viewport_size.x / screen_size.x
	var scale_y: float = viewport_size.y / screen_size.y

	var margin_left: int = maxi(0, int(safe_area.position.x * scale_x))
	var margin_top: int = maxi(0, int(safe_area.position.y * scale_y))
	var margin_right: int = maxi(0, int((screen_size.x - safe_area.end.x) * scale_x))
	var margin_bottom: int = maxi(0, int((screen_size.y - safe_area.end.y) * scale_y))

	add_theme_constant_override("margin_left", margin_left)
	add_theme_constant_override("margin_top", margin_top)
	add_theme_constant_override("margin_right", margin_right)
	add_theme_constant_override("margin_bottom", margin_bottom)
