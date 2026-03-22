## AStarGrid2D ラッパー — タイルマップオフィスのグリッドベース経路探索
extends Node

const TILE_SIZE: int = 32

var astar: AStarGrid2D


func setup(room_size: Vector2i) -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(Vector2i.ZERO, room_size)
	astar.cell_size = Vector2(TILE_SIZE, TILE_SIZE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()


func update_obstacles(room_size: Vector2i, furniture_cells: Array) -> void:
	# 全セルをリセット（歩行可能に戻す）
	for y in range(room_size.y):
		for x in range(room_size.x):
			astar.set_point_solid(Vector2i(x, y), false)

	# 壁（外周）をソリッドに設定
	for x in range(room_size.x):
		astar.set_point_solid(Vector2i(x, 0), true)
		astar.set_point_solid(Vector2i(x, room_size.y - 1), true)
	for y in range(room_size.y):
		astar.set_point_solid(Vector2i(0, y), true)
		astar.set_point_solid(Vector2i(room_size.x - 1, y), true)

	# 家具セルをソリッドに設定
	for cell in furniture_cells:
		var pos: Vector2i = cell
		if astar.is_in_bounds(pos.x, pos.y):
			astar.set_point_solid(pos, true)

	astar.update()


func find_path(from_grid: Vector2i, to_grid: Vector2i) -> PackedVector2Array:
	if not is_walkable(from_grid) or not is_walkable(to_grid):
		return PackedVector2Array()

	# AStarGrid2D.get_point_path() は cell_size を考慮したピクセル座標を返す
	# （タイル中心: grid * cell_size + cell_size / 2）
	return astar.get_point_path(from_grid, to_grid)


func get_random_walkable_tile() -> Vector2i:
	var region: Rect2i = astar.region
	for i in range(100):
		var x: int = randi_range(region.position.x, region.position.x + region.size.x - 1)
		var y: int = randi_range(region.position.y, region.position.y + region.size.y - 1)
		var pos := Vector2i(x, y)
		if is_walkable(pos):
			return pos
	return Vector2i(-1, -1)


func is_walkable(grid_pos: Vector2i) -> bool:
	if not astar.is_in_bounds(grid_pos.x, grid_pos.y):
		return false
	return not astar.is_point_solid(grid_pos)


func grid_to_pixel(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2, grid_pos.y * TILE_SIZE + TILE_SIZE / 2)


func pixel_to_grid(pixel_pos: Vector2) -> Vector2i:
	return Vector2i(int(pixel_pos.x) / TILE_SIZE, int(pixel_pos.y) / TILE_SIZE)
