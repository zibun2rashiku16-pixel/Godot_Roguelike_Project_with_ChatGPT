extends Node
class_name BagGridOps

func place_item_in_bag(inv: Inventory, item: Dictionary) -> bool:
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	var pos: Vector2i = self.find_fit(inv, size)
	if pos.x == -1:
		return false
	self._fill_cells(inv, pos, size, int(item["id"]))
	item["pos"] = pos
	inv.bag_items[int(item["id"])] = item
	return true

func place_item_in_bag_at(inv: Inventory, item: Dictionary, top_left: Vector2i) -> bool:
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	if not self._can_place_at(inv, top_left, size):
		return false
	self._fill_cells(inv, top_left, size, int(item["id"]))
	item["pos"] = top_left
	inv.bag_items[int(item["id"])] = item
	return true

func remove_item_from_bag(inv: Inventory, item_id: int) -> Dictionary:
	if not inv.bag_items.has(item_id):
		return {}
	var it: Dictionary = inv.bag_items[item_id]
	var pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	self._clear_cells(inv, pos, size)
	inv.bag_items.erase(item_id)
	return it

func move_item_in_bag_to(inv: Inventory, item_id: int, new_tl: Vector2i) -> bool:
	if not inv.bag_items.has(item_id):
		return false
	var it: Dictionary = inv.bag_items[item_id]
	var old_pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	if old_pos == new_tl:
		return true
	self._clear_cells(inv, old_pos, size)
	if self._can_place_at(inv, new_tl, size):
		self._fill_cells(inv, new_tl, size, item_id)
		it["pos"] = new_tl
		inv.bag_items[item_id] = it
		return true
	self._fill_cells(inv, old_pos, size, item_id)
	return false

func bag_id_at(inv: Inventory, x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= inv.bag_w or y >= inv.bag_h:
		return -1
	var row: Array = inv.bag_cells[y]
	return int(row[x])

func find_fit(inv: Inventory, size: Vector2i) -> Vector2i:
	for y: int in range(inv.bag_h):
		for x: int in range(inv.bag_w):
			var tl: Vector2i = Vector2i(x, y)
			if self._can_place_at(inv, tl, size):
				return tl
	return Vector2i(-1, -1)

func _fill_cells(inv: Inventory, top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = inv.bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = item_id
		inv.bag_cells[yy] = row

func _clear_cells(inv: Inventory, top_left: Vector2i, size: Vector2i) -> void:
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = inv.bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = -1
		inv.bag_cells[yy] = row

func _can_place_at(inv: Inventory, top_left: Vector2i, size: Vector2i) -> bool:
	if top_left.x < 0 or top_left.y < 0:
		return false
	if top_left.x + size.x > inv.bag_w or top_left.y + size.y > inv.bag_h:
		return false
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = inv.bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			if int(row[xx]) != -1:
				return false
	return true
