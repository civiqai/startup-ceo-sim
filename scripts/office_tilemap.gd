extends Node2D
## TileMap ベースのオフィスフロア・壁・メンバー配置管理
##
## build_office(phase) でフェーズに応じた部屋を構築し、
## update_members() で TeamManager のメンバーをスプライトとして配置する。

signal member_tapped(member_index: int)

# タイルサイズ
const TILE_SIZE := 32

# アトラステクスチャパス
const FLOOR_ATLAS_PATH := "res://assets/images/tiles/Room_Builder_Floors_32x32.png"
const WALL_ATLAS_PATH := "res://assets/images/tiles/Room_Builder_Walls_32x32.png"

# フロアアトラス: 480x1280px → 15列 x 40行
const FLOOR_ATLAS_COLS := 15
const FLOOR_ATLAS_ROWS := 40

# ウォールアトラス: 1024x1280px → 32列 x 40行
const WALL_ATLAS_COLS := 32
const WALL_ATLAS_ROWS := 40

# TileSetAtlasSource ID
const FLOOR_SOURCE_ID := 0
const WALL_SOURCE_ID := 1

# フェーズ別の部屋サイズ (幅タイル数, 高さタイル数) — 横長
const ROOM_SIZES := {
	0: Vector2i(16, 10),  # ガレージ
	1: Vector2i(22, 14),  # 小さなオフィス
	2: Vector2i(28, 16),  # コワーキングスペース
	3: Vector2i(36, 20),  # 自社オフィス
	4: Vector2i(44, 24),  # フロア貸しオフィス
	5: Vector2i(56, 30),  # 自社ビル
}

# フェーズ別オフィス名
const OFFICE_NAMES := [
	"自宅ガレージ",
	"小さなオフィス",
	"コワーキングスペース",
	"自社オフィス",
	"フロア貸しオフィス",
	"自社ビル",
]


# ウォールタイルで使う座標（アトラス内）
# 壁アトラスは8列ごとにカラーバリエーション: 0-7=白灰, 8-15=木茶, 16-23=赤, 24-31=青緑
# 各8列ブロック内: 列0-2が左壁〜右壁、行はパターン行
# 壁アトラス: 8列グループ×4グループ (白灰, 木茶, 赤, 青緑)
# 各グループ内の構造（行はおおよそ）:
#   row 0-1: 壁上部装飾
#   row 2-3: 壁の上辺
#   row 4-5: 壁の中間（左右含む）
#   row 6-7: 壁の下辺
# 白灰壁グループ (cols 0-7) を使用
const WALL_TOP := Vector2i(1, 1)     # 上壁
const WALL_BOTTOM := Vector2i(1, 5)  # 下壁
const WALL_LEFT := Vector2i(0, 3)    # 左壁
const WALL_RIGHT := Vector2i(2, 3)   # 右壁
const WALL_TL := Vector2i(0, 1)      # 左上コーナー
const WALL_TR := Vector2i(2, 1)      # 右上コーナー
const WALL_BL := Vector2i(0, 5)      # 左下コーナー
const WALL_BR := Vector2i(2, 5)      # 右下コーナー

# ノード参照
var _floor_layer: TileMapLayer = null
var _wall_layer: TileMapLayer = null
var _member_container: Node2D = null
var _tileset: TileSet = null

var _current_phase: int = -1
var _current_room_size: Vector2i = Vector2i.ZERO
var _pathfinding: Node = null  # office_pathfinding.gd instance
var _npcs: Dictionary = {}  # key: member index string → OfficeNPC node


func _ready() -> void:
	_create_tileset()
	_setup_layers()
	print("[OfficeTilemap] _ready done. tileset=%s floor_layer=%s wall_layer=%s" % [_tileset, _floor_layer, _wall_layer])


## プログラムで TileSet を作成する
func _create_tileset() -> void:
	_tileset = TileSet.new()
	_tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)

	# フロアアトラスソース
	var floor_tex := load(FLOOR_ATLAS_PATH) as Texture2D
	if floor_tex:
		var floor_source := TileSetAtlasSource.new()
		floor_source.texture = floor_tex
		floor_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		_tileset.add_source(floor_source, FLOOR_SOURCE_ID)
		# タイルを作成（アトラス全域）
		for y in FLOOR_ATLAS_ROWS:
			for x in FLOOR_ATLAS_COLS:
				var atlas_coord := Vector2i(x, y)
				floor_source.create_tile(atlas_coord)
	else:
		push_warning("OfficeTilemap: フロアテクスチャの読み込み失敗: %s" % FLOOR_ATLAS_PATH)

	# ウォールアトラスソース
	var wall_tex := load(WALL_ATLAS_PATH) as Texture2D
	if wall_tex:
		var wall_source := TileSetAtlasSource.new()
		wall_source.texture = wall_tex
		wall_source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
		_tileset.add_source(wall_source, WALL_SOURCE_ID)
		# タイルを作成（アトラス全域）
		for y in WALL_ATLAS_ROWS:
			for x in WALL_ATLAS_COLS:
				var atlas_coord := Vector2i(x, y)
				wall_source.create_tile(atlas_coord)
	else:
		push_warning("OfficeTilemap: ウォールテクスチャの読み込み失敗: %s" % WALL_ATLAS_PATH)


## TileMapLayer と メンバーコンテナをセットアップ
func _setup_layers() -> void:
	# フロアレイヤー
	_floor_layer = TileMapLayer.new()
	_floor_layer.name = "FloorLayer"
	_floor_layer.tile_set = _tileset
	_floor_layer.z_index = 0
	add_child(_floor_layer)

	# ウォールレイヤー
	_wall_layer = TileMapLayer.new()
	_wall_layer.name = "WallLayer"
	_wall_layer.tile_set = _tileset
	_wall_layer.z_index = 1
	add_child(_wall_layer)

	# メンバースプライトコンテナ
	_member_container = Node2D.new()
	_member_container.name = "MemberContainer"
	_member_container.z_index = 2
	_member_container.y_sort_enabled = true
	add_child(_member_container)


## フェーズに応じたオフィスを構築する
func build_office(phase: int) -> void:
	phase = clampi(phase, 0, ROOM_SIZES.size() - 1)

	var target_size: Vector2i = ROOM_SIZES[phase]
	if get_tree() and get_tree().root.has_node("OfficeExpansionManager"):
		target_size += OfficeExpansionManager.get_total_size_bonus()
	if phase == _current_phase and target_size == _current_room_size:
		return

	_current_phase = phase
	_current_room_size = target_size

	# 既存タイルをクリア
	_floor_layer.clear()
	_wall_layer.clear()

	var w: int = _current_room_size.x
	var h: int = _current_room_size.y

	# フロアタイル配置（内部を埋める: 1 ~ w-2, 1 ~ h-2）
	for ty in range(1, h - 1):
		for tx in range(1, w - 1):
			# フェーズによって少しバリエーションを付ける
			var floor_coord := _get_floor_tile_for_phase(phase, tx, ty)
			_floor_layer.set_cell(Vector2i(tx, ty), FLOOR_SOURCE_ID, floor_coord)

	# ウォールタイル配置（外周）
	for tx in range(w):
		for ty in range(h):
			var is_top := (ty == 0)
			var is_bottom := (ty == h - 1)
			var is_left := (tx == 0)
			var is_right := (tx == w - 1)

			if not (is_top or is_bottom or is_left or is_right):
				continue  # 内部はスキップ

			var wall_coord: Vector2i
			if is_top and is_left:
				wall_coord = WALL_TL
			elif is_top and is_right:
				wall_coord = WALL_TR
			elif is_bottom and is_left:
				wall_coord = WALL_BL
			elif is_bottom and is_right:
				wall_coord = WALL_BR
			elif is_top:
				wall_coord = WALL_TOP
			elif is_bottom:
				wall_coord = WALL_BOTTOM
			elif is_left:
				wall_coord = WALL_LEFT
			elif is_right:
				wall_coord = WALL_RIGHT
			else:
				wall_coord = WALL_TOP

			_wall_layer.set_cell(Vector2i(tx, ty), WALL_SOURCE_ID, wall_coord)

	_setup_pathfinding()


## フェーズに応じたフロアタイル座標を返す（バリエーション）
## フロアアトラスは3列ごとにスタイルが異なる（5ストリップ）
## 各ストリップ内で行ごとにパターン変化
## strip 0 (cols 0-2): 白/明るい, strip 1 (cols 3-5): 暖色木目
## strip 2 (cols 6-8): 赤茶, strip 3 (cols 9-11): 青灰, strip 4 (cols 12-14): 灰
func _get_floor_tile_for_phase(phase: int, tx: int, ty: int) -> Vector2i:
	# フェーズごとにストリップと行を選択
	# アトラスは5ストリップ(各3列): 0-2, 3-5, 6-8, 9-11, 12-14
	# 行方向は複数のフロアパターン。各パターンは2行程度占有
	var strip_col: int  # ストリップの開始列
	var base_row: int
	match phase:
		0:
			strip_col = 0; base_row = 10   # ガレージ: 暗めの木目
		1:
			strip_col = 0; base_row = 14   # 小オフィス: ナチュラル木目
		2:
			strip_col = 3; base_row = 8    # コワーキング: 暖色タイル
		3:
			strip_col = 3; base_row = 14   # 自社オフィス: リッチ木目
		4:
			strip_col = 12; base_row = 18  # フロア: モダングレー
		5:
			strip_col = 12; base_row = 22  # 自社ビル: 高級フロア
		_:
			strip_col = 0; base_row = 10

	# 全タイル同じにして統一感を出す（チェッカーは微妙に見えるので）
	var tile_x: int = strip_col + 1
	var tile_y: int = clampi(base_row, 0, FLOOR_ATLAS_ROWS - 1)
	return Vector2i(tile_x, tile_y)


## TeamManager からメンバー情報を取得してNPCを更新する
func update_members() -> void:
	if _member_container == null:
		return

	# 現在のメンバーリスト: CEO + TeamManager.members
	var all_members: Array = []
	# CEO（ダミーデータ）
	all_members.append({"is_ceo": true, "name": "社長", "skill_type": "pm", "avatar_id": 0})

	for m in TeamManager.members:
		all_members.append({
			"is_ceo": false,
			"name": m.member_name,
			"skill_type": m.skill_type,
			"avatar_id": m.avatar_id,
		})

	# Remove excess NPCs
	var needed_keys: Array[String] = []
	for i in all_members.size():
		needed_keys.append(str(i))

	var to_remove: Array[String] = []
	for key in _npcs:
		if not key in needed_keys:
			to_remove.append(key)
	for key in to_remove:
		var npc = _npcs[key]
		if is_instance_valid(npc):
			npc.queue_free()
		_npcs.erase(key)

	# Calculate home positions
	var positions := _calculate_member_positions(all_members.size())

	# Create/update NPCs
	for i in all_members.size():
		var key := str(i)
		var member_data: Dictionary = all_members[i]
		var pos: Vector2 = positions[i] if i < positions.size() else Vector2(TILE_SIZE * 3, TILE_SIZE * 3)
		var grid_pos := Vector2i(int(pos.x / TILE_SIZE), int(pos.y / TILE_SIZE))

		if _npcs.has(key) and is_instance_valid(_npcs[key]):
			# Update existing NPC home position
			_npcs[key].set_home_position(pos, grid_pos)
		else:
			# Create new NPC
			var npc := _create_npc(member_data, i)
			npc.set_home_position(pos, grid_pos)
			_member_container.add_child(npc)
			_npcs[key] = npc
			# Start wandering after a short delay
			if _pathfinding != null:
				npc.start_wandering()


## メンバー配置位置を計算する（フロア内部に重ならないように配置）
## デスク家具がある場合はその隣に優先配置する
func _calculate_member_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if _current_room_size == Vector2i.ZERO or count == 0:
		return positions

	# まずデスク隣接ポジションを取得
	var desk_positions := _get_desk_adjacent_positions()
	if desk_positions.size() >= count:
		return desk_positions.slice(0, count)

	# デスク分を先に埋め、残りはグリッド配置
	var filled: int = mini(desk_positions.size(), count)
	for i in filled:
		positions.append(desk_positions[i])

	var remaining: int = count - filled
	if remaining <= 0:
		return positions

	# フロア内部の範囲（壁1マス分を除外）
	var inner_start_x: float = 1.5 * TILE_SIZE
	var inner_start_y: float = 1.5 * TILE_SIZE
	var inner_w: float = (_current_room_size.x - 3) * TILE_SIZE
	var inner_h: float = (_current_room_size.y - 3) * TILE_SIZE

	if remaining == count and count == 1:
		# デスクなし、1人の場合は中央
		positions.append(Vector2(
			inner_start_x + inner_w / 2.0,
			inner_start_y + inner_h / 2.0
		))
		return positions

	# グリッド配置: 行列数を自動計算（残りの人数分）
	var cols := ceili(sqrt(float(remaining)))
	var rows := ceili(float(remaining) / cols)

	var cell_w: float = inner_w / cols
	var cell_h: float = inner_h / rows

	for i in remaining:
		var col: int = i % cols
		var row: int = i / cols
		var px: float = inner_start_x + col * cell_w + cell_w / 2.0
		var py: float = inner_start_y + row * cell_h + cell_h / 2.0

		# デスクポジションと重複しないようにわずかにずらす
		var candidate := Vector2(px, py)
		for dp in desk_positions:
			if candidate.distance_to(dp) < TILE_SIZE:
				candidate.x += TILE_SIZE
				break
		positions.append(candidate)

	return positions


## デスク/ワークステーション家具の隣接位置を取得する
func _get_desk_adjacent_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []

	# FurnitureManager が利用可能かチェック
	if not get_tree() or not get_tree().root.has_node("FurnitureManager"):
		return result
	if not get_tree().root.has_node("FurnitureData"):
		return result

	var placed: Array = FurnitureManager.get_placed_furniture()
	for item in placed:
		var item_id: String = item.get("id", "")
		var grid_pos: Vector2i = item.get("grid_position", Vector2i.ZERO)

		# FurnitureData からカテゴリを取得
		var data: Dictionary = FurnitureData.get_item(item_id)
		var category: String = data.get("category", "")
		var item_size: Vector2i = data.get("size", Vector2i(1, 1))

		# デスクカテゴリのみ対象
		if category != "desk":
			continue

		# デスクの右隣（1タイル分オフセット）をメンバー配置位置とする
		var adjacent_x: float = (grid_pos.x + item_size.x) * TILE_SIZE + TILE_SIZE * 0.5
		var adjacent_y: float = (grid_pos.y + item_size.y / 2.0) * TILE_SIZE

		# 部屋の範囲内かチェック
		var max_x: float = (_current_room_size.x - 1) * TILE_SIZE
		var max_y: float = (_current_room_size.y - 1) * TILE_SIZE
		if adjacent_x > max_x:
			# 右に収まらない場合は下にオフセット
			adjacent_x = (grid_pos.x + item_size.x / 2.0) * TILE_SIZE
			adjacent_y = (grid_pos.y + item_size.y) * TILE_SIZE + TILE_SIZE * 0.5
		if adjacent_y > max_y:
			adjacent_y = max_y - TILE_SIZE * 0.5

		result.append(Vector2(adjacent_x, adjacent_y))

	return result


## NPC キャラクターノードを新規作成する
func _create_npc(member_data: Dictionary, index: int) -> Node2D:
	var NPCScript = load("res://scripts/office_npc.gd")
	var npc := Node2D.new()
	npc.set_script(NPCScript)
	npc.name = "NPC_%d" % index

	# Assign a character sprite (1-20, deterministic based on index)
	var char_idx: int = (index % 20) + 1

	npc.setup(member_data, index, char_idx)
	if _pathfinding != null:
		npc.set_pathfinding(_pathfinding)

	# Connect tap signal
	npc.tapped.connect(func(member_idx: int) -> void:
		member_tapped.emit(member_idx)
	)

	return npc


## パスファインディングをセットアップする
func _setup_pathfinding() -> void:
	if _pathfinding == null:
		var PathfindingScript = load("res://scripts/office_pathfinding.gd")
		_pathfinding = Node.new()
		_pathfinding.set_script(PathfindingScript)
		_pathfinding.name = "Pathfinding"
		add_child(_pathfinding)

	_pathfinding.setup(_current_room_size)

	# Get furniture-occupied cells
	var furniture_cells: Array = []
	if get_tree() and get_tree().root.has_node("FurnitureManager"):
		var placed: Array = FurnitureManager.get_placed_furniture()
		for item in placed:
			var item_id: String = item.get("id", "")
			var grid_pos: Vector2i = item.get("grid_position", Vector2i.ZERO)
			if get_tree().root.has_node("FurnitureData"):
				var data: Dictionary = FurnitureData.get_item(item_id)
				var item_size: Vector2i = data.get("size", Vector2i(1, 1))
				for dx in range(item_size.x):
					for dy in range(item_size.y):
						furniture_cells.append(grid_pos + Vector2i(dx, dy))

	_pathfinding.update_obstacles(_current_room_size, furniture_cells)


## パスファインディングを再構築する（家具変更時に呼ばれる）
func refresh_pathfinding() -> void:
	if _pathfinding != null and _current_room_size != Vector2i.ZERO:
		_setup_pathfinding()


## フェーズに対応するオフィス名を返す
func get_office_name(phase: int = -1) -> String:
	if phase < 0:
		phase = _current_phase
	phase = clampi(phase, 0, OFFICE_NAMES.size() - 1)
	return OFFICE_NAMES[phase]


## 現在の部屋サイズ（タイル数）を返す
func get_room_size() -> Vector2i:
	return _current_room_size


## 部屋のピクセルサイズを返す
func get_room_pixel_size() -> Vector2:
	return Vector2(_current_room_size.x * TILE_SIZE, _current_room_size.y * TILE_SIZE)


## 現在のフェーズを返す
func get_current_phase() -> int:
	return _current_phase
