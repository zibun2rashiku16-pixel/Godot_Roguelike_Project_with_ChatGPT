extends Node
class_name SealSystem

func _can_enhance_dict(inv: Inventory, it: Dictionary) -> bool:
	return it.has("plus")

func _rename_plus_item(inv: Inventory, it: Dictionary) -> void:
	var name0: String = String(it.get("name", ""))
	var base_name: String = name0
	var idx: int = name0.find("+")
	if idx >= 0:
		base_name = name0.substr(0, idx)
	var p: int = int(it.get("plus", 0))
	it["name"] = base_name + "+" + str(p)

func _enhance_bag_item(inv: Inventory, target_id: int) -> bool:
	if not inv.bag_items.has(target_id):
		return false
	var it: Dictionary = inv.bag_items[target_id]
	if not self._can_enhance_dict(inv, it):
		return false
	var cur: int = int(it.get("plus", 0))
	if cur >= inv.max_plus_limit:
		return false
	it["plus"] = cur + 1
	self._rename_plus_item(inv, it)
	inv.bag_items[target_id] = it
	return true

func _enhance_pouch_item(inv: Inventory, pouch_id: int, target_id: int) -> bool:
	if not inv.pouches.has(pouch_id):
		return false
	var c: Dictionary = inv.pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(target_id):
		return false
	var it: Dictionary = items[target_id]
	if not self._can_enhance_dict(inv, it):
		return false
	var cur: int = int(it.get("plus", 0))
	if cur >= inv.max_plus_limit:
		return false
	it["plus"] = cur + 1
	self._rename_plus_item(inv, it)
	items[target_id] = it
	c["items"] = items
	inv.pouches[pouch_id] = c
	return true

func _consume_seal_from_bag(inv: Inventory, seal_id: int) -> bool:
	var rem: Dictionary = inv.remove_item_from_bag(seal_id)
	return not rem.is_empty()

func _consume_seal_from_pouch(inv: Inventory, pouch_id: int, seal_id: int) -> bool:
	var rem: Dictionary = inv.pouch_remove_item(pouch_id, seal_id)
	return not rem.is_empty()

func apply_seal_from_bag_to_bag(inv: Inventory, seal_id: int, target_id: int) -> bool:
	if not inv.bag_items.has(seal_id):
		return false
	if not self._enhance_bag_item(inv, target_id):
		return false
	if not self._consume_seal_from_bag(inv, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true

func apply_seal_from_bag_to_pouch(inv: Inventory, seal_id: int, pouch_id: int, target_id: int) -> bool:
	if not inv.bag_items.has(seal_id):
		return false
	if not self._enhance_pouch_item(inv, pouch_id, target_id):
		return false
	if not self._consume_seal_from_bag(inv, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true

func apply_seal_from_pouch_to_bag(inv: Inventory, pouch_id: int, seal_id: int, target_id: int) -> bool:
	if not self._enhance_bag_item(inv, target_id):
		return false
	if not self._consume_seal_from_pouch(inv, pouch_id, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true

func apply_seal_from_pouch_to_pouch(inv: Inventory, pouch_id: int, seal_id: int, target_id: int) -> bool:
	if not self._enhance_pouch_item(inv, pouch_id, target_id):
		return false
	if not self._consume_seal_from_pouch(inv, pouch_id, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true

func apply_expand_from_bag(inv: Inventory, seal_id: int) -> bool:
	if inv.open_pouch_id == -1:
		return false
	if not inv.expand_pouch_by_one(inv.open_pouch_id):
		return false
	if not self._consume_seal_from_bag(inv, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true

func apply_expand_from_pouch(inv: Inventory, pouch_id: int, seal_id: int) -> bool:
	if not inv.pouches.has(pouch_id):
		return false
	if inv.open_pouch_id == -1:
		return false
	if not inv.expand_pouch_by_one(inv.open_pouch_id):
		return false
	if not self._consume_seal_from_pouch(inv, pouch_id, seal_id):
		return false
	inv.last_use_consumed_turn = true
	return true
