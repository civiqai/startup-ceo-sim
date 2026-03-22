class_name FurnitureManager
extends Node
## 家具配置状態管理シングルトン
## オフィスグリッド上の家具の購入・配置・移動・売却を管理する

# --- シグナル ---
signal furniture_placed(instance_id: int, item_id: String, grid_pos: Vector2i)
signal furniture_removed(instance_id: int, item_id: String)
signal furniture_purchased(item_id: String)
signal inventory_changed

# --- 内部状態 ---
## 配置済み家具リスト（各要素は PlacedFurniture 形式の Dictionary）
var _placed_furniture: Array[Dictionary] = []
## グリッド座標 → instance_id のマップ（衝突判定用）
var _grid_occupied: Dictionary = {}
## インスタンスID自動採番カウンタ
var _next_instance_id: int = 1
## 購入済み・未配置アイテムのインベントリ
var _purchased_items: Array[String] = []

# 売却時の返金率
const SELL_REFUND_RATE := 0.5


# --- PlacedFurniture ヘルパー ---
## 配置済み家具データを生成する
static func _make_placed_furniture(id: String, instance_id: int, grid_position: Vector2i, rotation: int = 0) -> Dictionary:
	return {
		"id": id,
		"instance_id": instance_id,
		"grid_position": grid_position,
		"rotation": rotation,
	}


# ==========================================================
#  購入系メソッド
# ==========================================================

## アイテムを購入できるか（資金チェック）
func can_purchase(item_id: String) -> bool:
	var item := FurnitureData.get_item(item_id)
	if item.is_empty():
		return false
	return GameState.cash >= item.get("cost", 0)


## アイテムを購入してインベントリに追加する
func purchase_item(item_id: String) -> bool:
	if not can_purchase(item_id):
		return false
	var item := FurnitureData.get_item(item_id)
	var cost: int = item.get("cost", 0)
	GameState.cash -= cost
	_purchased_items.append(item_id)
	furniture_purchased.emit(item_id)
	inventory_changed.emit()
	return true


## 購入済み・未配置アイテム一覧を返す
func get_inventory() -> Array[String]:
	return _purchased_items.duplicate()


# ==========================================================
#  配置系メソッド
# ==========================================================

## 指定位置に配置可能か（範囲内＋衝突なし）
func can_place(item_id: String, grid_pos: Vector2i, room_size: Vector2i) -> bool:
	var cells := get_furniture_cells(item_id, grid_pos)
	if cells.is_empty():
		return false
	for cell in cells:
		# 部屋の範囲チェック
		if cell.x < 0 or cell.y < 0 or cell.x >= room_size.x or cell.y >= room_size.y:
			return false
		# 衝突チェック
		if _grid_occupied.has(cell):
			return false
	return true


## インベントリから家具を配置する。成功時は instance_id を返す（失敗時 -1）
func place_furniture(item_id: String, grid_pos: Vector2i) -> int:
	# インベントリに存在するか
	var idx := _purchased_items.find(item_id)
	if idx == -1:
		return -1

	var cells := get_furniture_cells(item_id, grid_pos)
	if cells.is_empty():
		return -1

	# 衝突チェック（room_size なしの簡易版 — 呼び出し側で can_place 済みを想定）
	for cell in cells:
		if _grid_occupied.has(cell):
			return -1

	# インベントリから除去
	_purchased_items.remove_at(idx)
	inventory_changed.emit()

	# 配置登録
	var inst_id := _next_instance_id
	_next_instance_id += 1

	var placed := _make_placed_furniture(item_id, inst_id, grid_pos)
	_placed_furniture.append(placed)
	_occupy_cells(inst_id, cells)

	# バフ登録（instance_idをキーとして、アイテムの効果を登録）
	var item_data := FurnitureData.get_item(item_id)
	var effects: Dictionary = item_data.get("effects", {})
	if not effects.is_empty():
		OfficeBuffManager.add_furniture_buff(str(inst_id), effects)

	furniture_placed.emit(inst_id, item_id, grid_pos)
	return inst_id


## 配置済み家具を撤去してインベントリに戻す。戻り値は item_id（失敗時 ""）
func remove_furniture(instance_id: int) -> String:
	var idx := _find_placed_index(instance_id)
	if idx == -1:
		return ""

	var placed: Dictionary = _placed_furniture[idx]
	var item_id: String = placed["id"]
	var grid_pos: Vector2i = placed["grid_position"]

	# グリッド解放
	var cells := get_furniture_cells(item_id, grid_pos)
	_free_cells(cells)

	# 配置リストから除去
	_placed_furniture.remove_at(idx)

	# バフ除去
	OfficeBuffManager.remove_furniture_buff(str(instance_id))

	# インベントリに返却
	_purchased_items.append(item_id)
	inventory_changed.emit()

	furniture_removed.emit(instance_id, item_id)
	return item_id


## 配置済み家具を売却する（50%返金）。戻り値は返金額（失敗時 0）
func sell_furniture(instance_id: int) -> int:
	var idx := _find_placed_index(instance_id)
	if idx == -1:
		return 0

	var placed: Dictionary = _placed_furniture[idx]
	var item_id: String = placed["id"]
	var grid_pos: Vector2i = placed["grid_position"]

	# 返金額を計算
	var item := FurnitureData.get_item(item_id)
	var cost: int = item.get("cost", 0)
	var refund := int(cost * SELL_REFUND_RATE)

	# グリッド解放
	var cells := get_furniture_cells(item_id, grid_pos)
	_free_cells(cells)

	# 配置リストから除去
	_placed_furniture.remove_at(idx)

	# バフ除去
	OfficeBuffManager.remove_furniture_buff(str(instance_id))

	# 返金
	GameState.cash += refund

	furniture_removed.emit(instance_id, item_id)
	return refund


## 配置済み家具を別の位置に移動する
func move_furniture(instance_id: int, new_pos: Vector2i, room_size: Vector2i) -> bool:
	var idx := _find_placed_index(instance_id)
	if idx == -1:
		return false

	var placed: Dictionary = _placed_furniture[idx]
	var item_id: String = placed["id"]
	var old_pos: Vector2i = placed["grid_position"]

	# 現在のセルを一時的に解放して移動先の判定を行う
	var old_cells := get_furniture_cells(item_id, old_pos)
	_free_cells(old_cells)

	var new_cells := get_furniture_cells(item_id, new_pos)
	if new_cells.is_empty():
		# 失敗 — 元に戻す
		_occupy_cells(instance_id, old_cells)
		return false

	# 範囲・衝突チェック
	for cell in new_cells:
		if cell.x < 0 or cell.y < 0 or cell.x >= room_size.x or cell.y >= room_size.y:
			_occupy_cells(instance_id, old_cells)
			return false
		if _grid_occupied.has(cell):
			_occupy_cells(instance_id, old_cells)
			return false

	# 新しい位置で確定
	_occupy_cells(instance_id, new_cells)
	_placed_furniture[idx]["grid_position"] = new_pos
	return true


# ==========================================================
#  クエリ系メソッド
# ==========================================================

## 配置済み家具を全件返す
func get_placed_furniture() -> Array[Dictionary]:
	return _placed_furniture.duplicate()


## 指定グリッド座標にある家具を返す（無ければ空 Dictionary）
func get_furniture_at(grid_pos: Vector2i) -> Dictionary:
	if not _grid_occupied.has(grid_pos):
		return {}
	var inst_id: int = _grid_occupied[grid_pos]
	var idx := _find_placed_index(inst_id)
	if idx == -1:
		return {}
	return _placed_furniture[idx].duplicate()


## 特定アイテムの配置数を返す
func get_placed_count(item_id: String) -> int:
	var count := 0
	for placed in _placed_furniture:
		if placed["id"] == item_id:
			count += 1
	return count


## 配置済み家具の総数
func get_total_furniture_count() -> int:
	return _placed_furniture.size()


## セルが占有されているか
func is_cell_occupied(grid_pos: Vector2i) -> bool:
	return _grid_occupied.has(grid_pos)


## 指定インスタンスが占有しているセル一覧を返す
func get_occupied_cells(instance_id: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in _grid_occupied:
		if _grid_occupied[cell] == instance_id:
			result.append(cell)
	return result


# ==========================================================
#  グリッドヘルパー
# ==========================================================

## 家具が占有するセル座標一覧を算出する（左上基準）
func get_furniture_cells(item_id: String, grid_pos: Vector2i) -> Array[Vector2i]:
	var item := FurnitureData.get_item(item_id)
	if item.is_empty():
		return []
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	var cells: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			cells.append(grid_pos + Vector2i(x, y))
	return cells


## セルを占有状態にする
func _occupy_cells(instance_id: int, cells: Array[Vector2i]) -> void:
	for cell in cells:
		_grid_occupied[cell] = instance_id


## セルの占有を解除する
func _free_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		_grid_occupied.erase(cell)


# ==========================================================
#  シリアライズ / デシリアライズ
# ==========================================================

## 全状態を Dictionary に変換する（セーブ用）
func serialize() -> Dictionary:
	# _grid_occupied は _placed_furniture から復元可能なので保存不要
	var placed_data: Array[Dictionary] = []
	for p in _placed_furniture:
		placed_data.append({
			"id": p["id"],
			"instance_id": p["instance_id"],
			"grid_position": {"x": p["grid_position"].x, "y": p["grid_position"].y},
			"rotation": p["rotation"],
		})
	return {
		"placed_furniture": placed_data,
		"next_instance_id": _next_instance_id,
		"purchased_items": _purchased_items.duplicate(),
	}


## Dictionary から状態を復元する（ロード用）
func deserialize(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return

	_next_instance_id = data.get("next_instance_id", 1)

	var items_raw: Array = data.get("purchased_items", [])
	for item_id in items_raw:
		_purchased_items.append(str(item_id))

	var placed_raw: Array = data.get("placed_furniture", [])
	for p in placed_raw:
		var gp: Dictionary = p.get("grid_position", {"x": 0, "y": 0})
		var grid_pos := Vector2i(int(gp["x"]), int(gp["y"]))
		var placed := _make_placed_furniture(
			str(p["id"]),
			int(p["instance_id"]),
			grid_pos,
			int(p.get("rotation", 0)),
		)
		_placed_furniture.append(placed)

		# グリッド占有を再構築
		var cells := get_furniture_cells(placed["id"], grid_pos)
		_occupy_cells(placed["instance_id"], cells)

		# バフ再登録
		var item_data := FurnitureData.get_item(placed["id"])
		var effects: Dictionary = item_data.get("effects", {})
		if not effects.is_empty():
			OfficeBuffManager.add_furniture_buff(str(placed["instance_id"]), effects)

	inventory_changed.emit()


## 全状態をクリアする（ニューゲーム用）
func reset() -> void:
	_placed_furniture.clear()
	_grid_occupied.clear()
	_purchased_items.clear()
	_next_instance_id = 1
	inventory_changed.emit()


# ==========================================================
#  内部ユーティリティ
# ==========================================================

## instance_id から _placed_furniture のインデックスを探す（見つからなければ -1）
func _find_placed_index(instance_id: int) -> int:
	for i in range(_placed_furniture.size()):
		if _placed_furniture[i]["instance_id"] == instance_id:
			return i
	return -1
