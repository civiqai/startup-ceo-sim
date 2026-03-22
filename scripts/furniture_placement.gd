extends Node2D
class_name FurniturePlacement
## 家具配置モードコントローラー
##
## OfficeTilemap の子ノードとして追加し、家具のレンダリングと
## ドラッグ＆ドロップによるインタラクティブ配置を管理する。

signal placement_completed(item_id: String, grid_pos: Vector2i)
signal placement_cancelled
signal furniture_tapped(instance_id: int)

const TILE_SIZE := 32

# 配置モード中の色
const COLOR_VALID := Color(0.2, 0.8, 0.3, 0.3)
const COLOR_INVALID := Color(0.9, 0.2, 0.2, 0.3)
const GHOST_ALPHA := 0.6

# --- 家具スプライト管理 ---
var _furniture_container: Node2D = null
var _furniture_sprites: Dictionary = {}  # instance_id → Node2D

# --- 配置モード状態 ---
var _is_placing: bool = false
var _placing_item_id: String = ""
var _ghost_sprite: Sprite2D = null
var _grid_highlight: Node2D = null
var _current_grid_pos: Vector2i = Vector2i.ZERO
var _placing_item_size: Vector2i = Vector2i(1, 1)

# --- 配置UI ---
var _placement_overlay: Node = null


func _ready() -> void:
	# 家具スプライトを保持するコンテナ
	_furniture_container = Node2D.new()
	_furniture_container.name = "FurnitureContainer"
	_furniture_container.z_index = 3
	add_child(_furniture_container)


# ============================================================
# 配置済み家具のレンダリング
# ============================================================

## 全家具スプライトを再描画する
func render_all_furniture() -> void:
	# 既存スプライトをクリア
	for key in _furniture_sprites:
		var node = _furniture_sprites[key]
		if is_instance_valid(node):
			node.queue_free()
	_furniture_sprites.clear()

	if not _has_furniture_manager():
		return

	var placed: Array = FurnitureManager.get_placed_furniture()
	for item in placed:
		var inst_id: int = item.get("instance_id", -1)
		var item_id: String = item.get("id", "")
		var grid_pos: Vector2i = item.get("grid_position", Vector2i.ZERO)
		if inst_id >= 0 and item_id != "":
			_create_furniture_node(inst_id, item_id, grid_pos)


## 単一の家具スプライトを追加する（フル再描画なし）
## with_entrance_anim が true の場合、配置時のバウンスアニメーションを再生する
func add_furniture_sprite(instance_id: int, item_id: String, grid_pos: Vector2i, with_entrance_anim: bool = false) -> void:
	# 既存があれば先に削除
	remove_furniture_sprite(instance_id)
	_create_furniture_node(instance_id, item_id, grid_pos)

	# 配置時バウンスアニメーション
	if with_entrance_anim and _furniture_sprites.has(instance_id):
		var node: Node2D = _furniture_sprites[instance_id]
		if is_instance_valid(node):
			_play_entrance_bounce(node)


## 単一の家具スプライトを削除する
## animated が true の場合、フェード＋縮小アニメーション後に削除する
func remove_furniture_sprite(instance_id: int, animated: bool = false) -> void:
	if _furniture_sprites.has(instance_id):
		var node = _furniture_sprites[instance_id]
		_furniture_sprites.erase(instance_id)
		if is_instance_valid(node):
			if animated:
				play_remove_effect(node)
			else:
				node.queue_free()


## 家具ノード（Sprite2D + Area2D）を作成してコンテナに追加する
func _create_furniture_node(instance_id: int, item_id: String, grid_pos: Vector2i) -> void:
	var data: Dictionary = _get_furniture_data(item_id)
	var item_size: Vector2i = data.get("size", Vector2i(1, 1))
	var sprite_path: String = data.get("sprite_path", "")

	var root := Node2D.new()
	root.name = "Furniture_%d" % instance_id

	# スプライト
	var sprite := Sprite2D.new()
	sprite.centered = false
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		if tex:
			sprite.texture = tex
			sprite.scale = _calc_sprite_scale(tex, item_size)
	else:
		# テクスチャがない場合はフォールバック色付き矩形
		sprite.visible = false
		var fallback := _create_fallback_rect(item_size, data)
		root.add_child(fallback)

	root.add_child(sprite)

	# タップ検知用 Area2D
	var area := Area2D.new()
	area.name = "TapArea"
	area.input_pickable = true
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(item_size.x * TILE_SIZE, item_size.y * TILE_SIZE)
	collision.shape = shape
	# CollisionShape2D は中心基準なのでオフセット
	collision.position = Vector2(item_size.x * TILE_SIZE / 2.0, item_size.y * TILE_SIZE / 2.0)
	area.add_child(collision)
	root.add_child(area)

	# タップシグナル接続
	var captured_id := instance_id
	area.input_event.connect(func(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			furniture_tapped.emit(captured_id)
	)

	# 位置設定（グリッド座標 → ピクセル座標、左上基準）
	root.position = Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)

	_furniture_container.add_child(root)
	_furniture_sprites[instance_id] = root

	# アイドルアニメーション追加
	_add_idle_animation(root, item_id)


## フォールバック用の色付き矩形
func _create_fallback_rect(item_size: Vector2i, data: Dictionary) -> ColorRect:
	var rect := ColorRect.new()
	rect.size = Vector2(item_size.x * TILE_SIZE, item_size.y * TILE_SIZE)
	var base_color: Color = data.get("color", Color(0.45, 0.55, 0.65))
	rect.color = base_color
	return rect


## テクスチャスケールを計算する
func _calc_sprite_scale(tex: Texture2D, item_size: Vector2i) -> Vector2:
	var tex_size := tex.get_size()
	if tex_size.x <= 0 or tex_size.y <= 0:
		return Vector2.ONE
	var target_w: float = item_size.x * TILE_SIZE
	var target_h: float = item_size.y * TILE_SIZE
	return Vector2(target_w / tex_size.x, target_h / tex_size.y)


# ============================================================
# 配置モード
# ============================================================

## 配置モードを開始する
func start_placement(item_id: String) -> void:
	if _is_placing:
		cancel_placement()

	var data: Dictionary = _get_furniture_data(item_id)
	_placing_item_size = data.get("size", Vector2i(1, 1))
	_placing_item_id = item_id
	_is_placing = true

	# ゴーストスプライト作成
	_ghost_sprite = Sprite2D.new()
	_ghost_sprite.name = "GhostSprite"
	_ghost_sprite.centered = false
	_ghost_sprite.modulate = Color(1.0, 1.0, 1.0, GHOST_ALPHA)
	_ghost_sprite.z_index = 4

	var sprite_path: String = data.get("sprite_path", "")
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var tex: Texture2D = load(sprite_path)
		if tex:
			_ghost_sprite.texture = tex
			_ghost_sprite.scale = _calc_sprite_scale(tex, _placing_item_size)

	add_child(_ghost_sprite)

	# グリッドハイライト作成
	_grid_highlight = _create_grid_highlight(_placing_item_size)
	_grid_highlight.z_index = 5
	add_child(_grid_highlight)

	# 部屋の中央に初期配置
	var bounds := get_room_bounds()
	var center_x: int = bounds.position.x + (bounds.size.x - _placing_item_size.x) / 2
	var center_y: int = bounds.position.y + (bounds.size.y - _placing_item_size.y) / 2
	_current_grid_pos = Vector2i(center_x, center_y)
	_update_ghost_position(_current_grid_pos)

	# 配置UIオーバーレイ表示
	_show_placement_overlay()


## 配置をキャンセルする
func cancel_placement() -> void:
	_cleanup_placement()
	placement_cancelled.emit()


## 配置を確定する
func confirm_placement() -> void:
	if not _is_placing:
		return

	if not _has_furniture_manager():
		push_warning("FurniturePlacement: FurnitureManager が見つかりません")
		_cleanup_placement()
		return

	var room_size := _get_room_size()
	if not FurnitureManager.can_place(_placing_item_id, _current_grid_pos, room_size):
		# 無効な配置 → 赤フラッシュ
		_flash_invalid()
		return

	# 配置実行（place_furniture は instance_id: int を返す、失敗時 -1）
	var inst_id: int = FurnitureManager.place_furniture(_placing_item_id, _current_grid_pos)
	var completed_item_id := _placing_item_id
	var completed_pos := _current_grid_pos
	var completed_size := _placing_item_size

	_cleanup_placement()

	# 新しい家具スプライトを追加（バウンスアニメーション付き）
	if inst_id > 0:
		add_furniture_sprite(inst_id, completed_item_id, completed_pos, true)
		# 配置お祝いエフェクト
		play_place_effect(completed_pos, completed_size)

	placement_completed.emit(completed_item_id, completed_pos)


## 配置モードの後片付け
func _cleanup_placement() -> void:
	_is_placing = false
	_placing_item_id = ""

	if is_instance_valid(_ghost_sprite):
		_ghost_sprite.queue_free()
	_ghost_sprite = null

	if is_instance_valid(_grid_highlight):
		_grid_highlight.queue_free()
	_grid_highlight = null

	_hide_placement_overlay()


# ============================================================
# 入力処理（配置モード中）
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_placing:
		return

	# タッチドラッグ
	if event is InputEventScreenDrag:
		var grid_pos := _screen_to_grid(event.position)
		_current_grid_pos = grid_pos
		_update_ghost_position(grid_pos)
		get_viewport().set_input_as_handled()

	# マウスモーション（デスクトップフォールバック）
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var grid_pos := _screen_to_grid(event.position)
		_current_grid_pos = grid_pos
		_update_ghost_position(grid_pos)
		get_viewport().set_input_as_handled()

	# シングルタップ → 位置更新（ドラッグ開始しないタップ）
	elif event is InputEventScreenTouch and event.pressed:
		var grid_pos := _screen_to_grid(event.position)
		_current_grid_pos = grid_pos
		_update_ghost_position(grid_pos)
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var grid_pos := _screen_to_grid(event.position)
		_current_grid_pos = grid_pos
		_update_ghost_position(grid_pos)
		get_viewport().set_input_as_handled()


## スクリーン座標をグリッドセル座標に変換する
func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	# SubViewport 内のカメラ変換を考慮してローカル座標に変換
	# get_global_mouse_position はビューポート内のワールド座標を返す
	# ただし _unhandled_input のイベント座標はビューポートローカルなので
	# カメラのトランスフォームを使って変換する
	var camera := _get_camera()
	var local_pos: Vector2

	if camera:
		# カメラのズームとオフセットを考慮
		var viewport := get_viewport()
		var viewport_size := viewport.get_visible_rect().size
		var camera_pos := camera.global_position
		var zoom_val := camera.zoom

		# スクリーン座標 → ワールド座標
		local_pos = (screen_pos - viewport_size / 2.0) / zoom_val + camera_pos
	else:
		local_pos = screen_pos

	# ワールド座標 → グリッド座標
	var gx: int = floori(local_pos.x / TILE_SIZE)
	var gy: int = floori(local_pos.y / TILE_SIZE)
	return Vector2i(gx, gy)


## ゴーストスプライトとハイライトを新しい位置に更新する
func _update_ghost_position(grid_pos: Vector2i) -> void:
	var pixel_pos := Vector2(grid_pos.x * TILE_SIZE, grid_pos.y * TILE_SIZE)

	if is_instance_valid(_ghost_sprite):
		_ghost_sprite.position = pixel_pos

	if is_instance_valid(_grid_highlight):
		_grid_highlight.position = pixel_pos

	# ハイライト色を更新
	_update_highlight_color(grid_pos, _placing_item_id)


# ============================================================
# グリッドハイライト
# ============================================================

## グリッドハイライトノードを作成する
func _create_grid_highlight(item_size: Vector2i) -> Node2D:
	var highlight := Node2D.new()
	highlight.name = "GridHighlight"

	for cy in item_size.y:
		for cx in item_size.x:
			var cell := ColorRect.new()
			cell.name = "Cell_%d_%d" % [cx, cy]
			cell.size = Vector2(TILE_SIZE, TILE_SIZE)
			cell.position = Vector2(cx * TILE_SIZE, cy * TILE_SIZE)
			cell.color = COLOR_VALID
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			highlight.add_child(cell)

	return highlight


## ハイライトの色を更新する（セルごとに有効/無効を判定）
func _update_highlight_color(grid_pos: Vector2i, item_id: String) -> void:
	if not is_instance_valid(_grid_highlight):
		return

	var bounds := get_room_bounds()
	var occupied := _get_occupied_cells()
	var room_size := _get_room_size()

	var cell_index: int = 0
	for cy in _placing_item_size.y:
		for cx in _placing_item_size.x:
			var check_pos := Vector2i(grid_pos.x + cx, grid_pos.y + cy)
			var valid := true

			# 範囲外チェック（壁含む外周）
			if check_pos.x < bounds.position.x or check_pos.x >= bounds.position.x + bounds.size.x:
				valid = false
			elif check_pos.y < bounds.position.y or check_pos.y >= bounds.position.y + bounds.size.y:
				valid = false
			# 既存家具との衝突チェック
			elif check_pos in occupied:
				valid = false

			var cell_node := _grid_highlight.get_child(cell_index)
			if cell_node is ColorRect:
				cell_node.color = COLOR_VALID if valid else COLOR_INVALID

			cell_index += 1


## 無効配置時の赤フラッシュ演出
func _flash_invalid() -> void:
	if not is_instance_valid(_grid_highlight):
		return

	# 一瞬全セルを濃い赤にしてから戻す
	for child in _grid_highlight.get_children():
		if child is ColorRect:
			child.color = Color(1.0, 0.1, 0.1, 0.6)

	var tween := create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		_update_highlight_color(_current_grid_pos, _placing_item_id)
	)


# ============================================================
# 配置オーバーレイUI（確定/キャンセルボタン）
# ============================================================

## 配置モード用のボタンオーバーレイを表示する
## SubViewportContainer上に直接HBoxContainerを配置して、タイルマップビュー下端に表示する
func _show_placement_overlay() -> void:
	_hide_placement_overlay()

	# SubViewportContainer を取得（ボタンの親として使う）
	var viewport_container := _get_viewport_container()
	if viewport_container == null:
		push_warning("FurniturePlacement: SubViewportContainer が見つかりません")
		return

	var container := HBoxContainer.new()
	container.name = "PlacementButtons"
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 12)
	# SubViewportContainerの右上に配置
	var vc_size: Vector2 = viewport_container.size
	container.position = Vector2(vc_size.x - 310, 4)
	container.size = Vector2(300, 40)

	# キャンセルボタン
	var cancel_btn := Button.new()
	cancel_btn.text = "✕ キャンセル"
	cancel_btn.custom_minimum_size = Vector2(140, 36)
	var cancel_style := StyleBoxFlat.new()
	cancel_style.bg_color = Color(0.75, 0.20, 0.20, 0.95)
	cancel_style.set_corner_radius_all(6)
	cancel_style.content_margin_left = 10.0
	cancel_style.content_margin_right = 10.0
	cancel_style.content_margin_top = 4.0
	cancel_style.content_margin_bottom = 4.0
	cancel_btn.add_theme_stylebox_override("normal", cancel_style)
	cancel_btn.add_theme_font_size_override("font_size", 20)
	cancel_btn.pressed.connect(cancel_placement)

	# 確定ボタン
	var confirm_btn := Button.new()
	confirm_btn.text = "✓ 配置"
	confirm_btn.custom_minimum_size = Vector2(140, 36)
	var confirm_style := StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.20, 0.65, 0.30, 0.95)
	confirm_style.set_corner_radius_all(6)
	confirm_style.content_margin_left = 10.0
	confirm_style.content_margin_right = 10.0
	confirm_style.content_margin_top = 4.0
	confirm_style.content_margin_bottom = 4.0
	confirm_btn.add_theme_stylebox_override("normal", confirm_style)
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.pressed.connect(confirm_placement)

	container.add_child(cancel_btn)
	container.add_child(confirm_btn)

	viewport_container.add_child(container)
	_placement_overlay = container


## 配置オーバーレイを非表示にする
func _hide_placement_overlay() -> void:
	if is_instance_valid(_placement_overlay):
		_placement_overlay.queue_free()
	_placement_overlay = null


# ============================================================
# ヘルパーメソッド
# ============================================================

## 配置可能エリア（壁を除いた内側）を返す
func get_room_bounds() -> Rect2i:
	var room_size := _get_room_size()
	if room_size == Vector2i.ZERO:
		return Rect2i(1, 1, 14, 8)  # フォールバック
	return Rect2i(1, 1, room_size.x - 2, room_size.y - 2)


## 配置モード中かどうかを返す
func is_in_placement_mode() -> bool:
	return _is_placing


## 家具コンテナノードを返す
func get_furniture_container() -> Node2D:
	return _furniture_container


## 部屋サイズを OfficeTilemap から取得する
func _get_room_size() -> Vector2i:
	var tilemap := get_parent()
	if tilemap and tilemap.has_method("get_room_size"):
		return tilemap.get_room_size()
	return Vector2i.ZERO


## カメラノードを取得する
func _get_camera() -> Camera2D:
	# OfficeTilemap の兄弟としてカメラがある想定
	var tilemap := get_parent()
	if tilemap:
		for child in tilemap.get_children():
			if child is Camera2D:
				return child
		# 親の親にもチェック（SubViewport直下の場合）
		var vp := tilemap.get_parent()
		if vp:
			for child in vp.get_children():
				if child is Camera2D:
					return child
	return null


## SubViewportContainer を取得する（配置ボタンの親として使用）
func _get_viewport_container() -> Control:
	# OfficeTilemap → SubViewport → SubViewportContainer
	var node := get_parent()  # OfficeTilemap
	if node:
		var vp := node.get_parent()  # SubViewport
		if vp:
			var vpc := vp.get_parent()  # SubViewportContainer
			if vpc is Control:
				return vpc
	return null


## FurnitureManager autoload が利用可能かチェック
func _has_furniture_manager() -> bool:
	return get_tree() and get_tree().root.has_node("FurnitureManager")


## FurnitureData autoload からアイテム情報を取得する
func _get_furniture_data(item_id: String) -> Dictionary:
	if get_tree() and get_tree().root.has_node("FurnitureData"):
		return FurnitureData.get_item(item_id)
	return {}


# ============================================================
# アニメーション・エフェクト
# ============================================================

## 配置時のお祝いパーティクルエフェクト（モバイル互換の簡易版）
func play_place_effect(grid_pos: Vector2i, item_size: Vector2i) -> void:
	var center_px := Vector2(
		(grid_pos.x + item_size.x / 2.0) * TILE_SIZE,
		(grid_pos.y + item_size.y / 2.0) * TILE_SIZE
	)

	var effect_root := Node2D.new()
	effect_root.name = "PlaceEffect"
	effect_root.position = center_px
	effect_root.z_index = 10
	_furniture_container.add_child(effect_root)

	# 4〜6個の小さな色付き四角をバースト
	var particle_count := randi_range(4, 6)
	var colors := [
		Color(0.95, 0.85, 0.25),  # 金
		Color(0.30, 0.80, 0.45),  # 緑
		Color(0.40, 0.60, 0.95),  # 青
		Color(0.90, 0.45, 0.30),  # 赤橙
		Color(0.75, 0.40, 0.85),  # 紫
		Color(0.95, 0.65, 0.20),  # オレンジ
	]

	for i in particle_count:
		var particle := ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.position = Vector2(-2, -2)
		particle.color = colors[i % colors.size()]
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		effect_root.add_child(particle)

		# ランダムな方向に飛ばす
		var angle := randf() * TAU
		var distance := randf_range(16.0, 32.0)
		var target_offset := Vector2(cos(angle) * distance, sin(angle) * distance)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "position", target_offset, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(particle, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)

	# 0.5秒後にクリーンアップ
	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(0.55)
	cleanup_tween.tween_callback(func() -> void:
		if is_instance_valid(effect_root):
			effect_root.queue_free()
	)


## 売却/撤去時のフェード＋縮小エフェクト
func play_remove_effect(node: Node2D) -> void:
	if not is_instance_valid(node):
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(node, "modulate:a", 0.0, 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(node, "scale", Vector2(0.3, 0.3), 0.3).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)

	var cleanup_tween := create_tween()
	cleanup_tween.tween_interval(0.35)
	cleanup_tween.tween_callback(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	)


## 配置直後のバウンスアニメーション
func _play_entrance_bounce(node: Node2D) -> void:
	if not is_instance_valid(node):
		return

	node.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(node, "scale", Vector2(1.1, 1.1), 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(node, "scale", Vector2.ONE, 0.1).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)


## 家具ノードにアイドルアニメーションを追加する（カテゴリ別）
func _add_idle_animation(node: Node2D, item_id: String) -> void:
	if not is_instance_valid(node):
		return

	var data: Dictionary = _get_furniture_data(item_id)
	var category: String = data.get("category", "")

	# 植物: ゆるやかな揺れアニメーション
	if category == "comfort" and "plant" in item_id:
		var tween := create_tween()
		tween.set_loops()
		var sway_deg := 2.0
		var duration := randf_range(3.0, 4.0)
		tween.tween_property(node, "rotation_degrees", sway_deg, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "rotation_degrees", -sway_deg, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "rotation_degrees", 0.0, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		return

	# モニター: 微妙な明滅パルス
	if category == "desk" and "monitor" in item_id:
		var tween := create_tween()
		tween.set_loops()
		var duration := randf_range(1.8, 2.2)
		tween.tween_property(node, "modulate:a", 0.9, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_property(node, "modulate:a", 1.0, duration / 2.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
		return


## 配置済み家具が占有しているセルの一覧を返す
func _get_occupied_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not _has_furniture_manager():
		return cells

	# FurnitureManager._grid_occupied のキーを使う
	var placed: Array = FurnitureManager.get_placed_furniture()
	for item in placed:
		var pos: Vector2i = item.get("grid_position", Vector2i.ZERO)
		var item_id: String = item.get("id", "")
		var data: Dictionary = _get_furniture_data(item_id)
		var sz: Vector2i = data.get("size", Vector2i(1, 1))
		for cy in sz.y:
			for cx in sz.x:
				cells.append(Vector2i(pos.x + cx, pos.y + cy))

	return cells
