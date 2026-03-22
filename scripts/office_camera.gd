extends Camera2D
## オフィスTileMapビュー用カメラ — スワイプ移動・ピンチズーム・慣性スクロール

# カメラ移動の境界（TileMap領域に合わせて調整）
@export var map_bounds: Rect2 = Rect2(-160, -160, 640, 640)

# ズーム範囲
@export var zoom_min: float = 0.5
@export var zoom_max: float = 4.0

# 慣性の減衰率（毎フレーム速度にかける）
@export var friction: float = 0.92

# タップ判定用の最小ドラッグ距離（px）
@export var dead_zone: float = 5.0

# ズームTweenの秒数
@export var zoom_duration: float = 0.15

# マウスホイール1クリックあたりのズーム量
@export var wheel_zoom_step: float = 0.1

# --- 内部状態 ---

# 慣性用速度ベクトル（ワールド座標/秒ではなくフレーム単位）
var _velocity: Vector2 = Vector2.ZERO

# ドラッグ中フラグ（dead_zoneを超えたら有効）
var _is_dragging: bool = false

# タッチ開始位置（dead_zone判定用）
var _drag_start_pos: Vector2 = Vector2.ZERO

# 現在のタッチポイント情報 {index: position}
var _touches: Dictionary = {}

# ピンチ開始時の2点間距離
var _pinch_start_distance: float = 0.0

# ピンチ開始時のズーム値
var _pinch_start_zoom: Vector2 = Vector2.ONE

# ピンチ中フラグ
var _is_pinching: bool = false

# マウスドラッグ中フラグ
var _mouse_dragging: bool = false
var _mouse_drag_start: Vector2 = Vector2.ZERO
var _mouse_drag_active: bool = false  # dead_zone超過済み

# ズーム用Tween参照
var _zoom_tween: Tween = null

# シグナル
signal camera_moved(new_position: Vector2)
signal camera_zoomed(new_zoom: Vector2)


func _ready() -> void:
	# カメラを有効化
	enabled = true


func _process(delta: float) -> void:
	# 慣性スクロール（ドラッグ中・ピンチ中は適用しない）
	if not _is_dragging and not _is_pinching and not _mouse_drag_active:
		if _velocity.length() > 0.5:
			position += _velocity
			_velocity *= friction
			_clamp_position()
			camera_moved.emit(position)
		else:
			_velocity = Vector2.ZERO


func _input(event: InputEvent) -> void:
	# --- モバイルタッチ ---
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	# --- マウスフォールバック ---
	elif event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


# ==========================
#  モバイルタッチ処理
# ==========================

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			# シングルタッチ開始
			_drag_start_pos = event.position
			_is_dragging = false
			_velocity = Vector2.ZERO
		elif _touches.size() == 2:
			# ピンチ開始
			_is_dragging = false
			_is_pinching = true
			var points = _touches.values()
			_pinch_start_distance = points[0].distance_to(points[1])
			_pinch_start_zoom = zoom
	else:
		_touches.erase(event.index)
		if _touches.size() < 2:
			_is_pinching = false
		if _touches.size() == 0:
			_is_dragging = false


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touches[event.index] = event.position

	if _touches.size() == 2 and _is_pinching:
		# ピンチズーム処理
		var points = _touches.values()
		var current_distance: float = points[0].distance_to(points[1])
		if _pinch_start_distance > 0:
			var scale_factor: float = current_distance / _pinch_start_distance
			var new_zoom_val: float = clampf(
				_pinch_start_zoom.x * scale_factor,
				zoom_min,
				zoom_max
			)
			zoom = Vector2(new_zoom_val, new_zoom_val)
			_clamp_position()
			camera_zoomed.emit(zoom)
	elif _touches.size() == 1 and not _is_pinching:
		# シングルタッチドラッグ（パン）
		if not _is_dragging:
			if event.position.distance_to(_drag_start_pos) >= dead_zone:
				_is_dragging = true
			else:
				return
		# zoom考慮: 画面上の移動量をワールド座標に変換
		var pan_offset: Vector2 = -event.relative / zoom
		position += pan_offset
		_velocity = -event.relative / zoom
		_clamp_position()
		camera_moved.emit(position)


# ==========================
#  マウスフォールバック処理
# ==========================

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_dragging = true
			_mouse_drag_active = false
			_mouse_drag_start = event.position
			_velocity = Vector2.ZERO
		else:
			_mouse_dragging = false
			_mouse_drag_active = false
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_smooth_zoom(wheel_zoom_step)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_smooth_zoom(-wheel_zoom_step)


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_dragging:
		return
	if not _mouse_drag_active:
		if event.position.distance_to(_mouse_drag_start) >= dead_zone:
			_mouse_drag_active = true
		else:
			return
	var pan_offset: Vector2 = -event.relative / zoom
	position += pan_offset
	_velocity = -event.relative / zoom
	_clamp_position()
	camera_moved.emit(position)


# ==========================
#  ズーム
# ==========================

func _smooth_zoom(step: float) -> void:
	var target_val: float = clampf(zoom.x + step, zoom_min, zoom_max)
	var target_zoom := Vector2(target_val, target_val)

	# 既存Tweenがあればキャンセル
	if _zoom_tween and _zoom_tween.is_valid():
		_zoom_tween.kill()

	_zoom_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.tween_property(self, "zoom", target_zoom, zoom_duration)
	_zoom_tween.tween_callback(_on_zoom_tween_finished)

	camera_zoomed.emit(target_zoom)


func _on_zoom_tween_finished() -> void:
	_clamp_position()


# ==========================
#  境界クランプ
# ==========================

func _clamp_position() -> void:
	# 画面サイズの半分（ズーム考慮）を境界から引いて、カメラ中心の有効範囲を求める
	var viewport_size := get_viewport_rect().size
	var half_view := viewport_size / (2.0 * zoom)

	var min_pos := Vector2(
		map_bounds.position.x + half_view.x,
		map_bounds.position.y + half_view.y
	)
	var max_pos := Vector2(
		map_bounds.end.x - half_view.x,
		map_bounds.end.y - half_view.y
	)

	# マップが画面より小さい場合は中央に固定
	if min_pos.x > max_pos.x:
		position.x = map_bounds.position.x + map_bounds.size.x / 2.0
	else:
		position.x = clampf(position.x, min_pos.x, max_pos.x)

	if min_pos.y > max_pos.y:
		position.y = map_bounds.position.y + map_bounds.size.y / 2.0
	else:
		position.y = clampf(position.y, min_pos.y, max_pos.y)
