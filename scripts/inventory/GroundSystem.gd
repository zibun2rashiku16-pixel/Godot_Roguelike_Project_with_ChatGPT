extends Node
class_name GroundSystem

func add_item_to_ground(inv: Inventory, cell: Vector2i, item: Dictionary) -> void:
	var list: Array = inv.ground.get(cell, [])
	if list.is_empty():
		list = []
	list.append(item)
	inv.ground[cell] = list

func get_ground_items_at(inv: Inventory, cell: Vector2i) -> Array:
	if inv.ground.has(cell):
		return inv.ground[cell]
	return []

func get_ground_top_item(inv: Inventory, cell: Vector2i) -> Dictionary:
	if not inv.ground.has(cell):
		return {}
	var arr: Array = inv.ground[cell]
	if arr.is_empty():
		return {}
	return arr[arr.size() - 1]

func pickup_ground_item(inv: Inventory, cell: Vector2i) -> bool:
	var top: Dictionary = get_ground_top_item(inv, cell)
	if top.is_empty():
		return false
	if not inv.place_item_in_bag(top):
		return false
	var arr: Array = inv.ground.get(cell, [])
	if not arr.is_empty():
		arr.remove_at(arr.size() - 1)
		if arr.is_empty():
			inv.ground.erase(cell)
		else:
			inv.ground[cell] = arr
	return true

func take_item_from_ground(inv: Inventory, cell: Vector2i, item_id: int) -> Dictionary:
	if not inv.ground.has(cell):
		return {}
	var arr: Array = inv.ground[cell]
	for i: int in range(arr.size() - 1, -1, -1):
		var it: Dictionary = arr[i]
		if int(it.get("id", -1)) == item_id:
			arr.remove_at(i)
			if arr.is_empty():
				inv.ground.erase(cell)
			else:
				inv.ground[cell] = arr
			return it
	return {}
