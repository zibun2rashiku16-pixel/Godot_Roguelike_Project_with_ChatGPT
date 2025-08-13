extends Node
class_name PouchSystem

func close_pouch(inv: Inventory) -> void:
	if inv.open_pouch_id != -1:
		inv.open_pouch_id = -1
		inv.pouch_toggled.emit(false, -1)

# -------------------------
# 内部ユーティリティ（名称整形）
# -------------------------

func _extract_base_name(name: String) -> String:
	var idx: int = name.find("+")
	var idx_zen: int = name.find("＋")
	var cut: int = -1
	if idx >= 0:
		cut = idx
	elif idx_zen >= 0:
		cut = idx_zen
	if cut >= 0:
		return name.substr(0, cut)
	return name

func _to_zenkaku_digits(n: int) -> String:
	var s: String = str(n)
	var map: Dictionary = {
		"0": "０", "1": "１", "2": "２", "3": "３", "4": "４",
		"5": "５", "6": "６", "7": "７", "8": "８", "9": "９"
	}
	var out: String = ""
	for i: int in s.length():
		var ch: String = s.substr(i, 1)
		if map.has(ch):
			out += String(map[ch])
		else:
			out += ch
	return out

func _format_fused_name(base_name: String, plus_total: int) -> String:
	return base_name + "＋" + _to_zenkaku_digits(plus_total)

# -------------------------
# ID/生成
# -------------------------

func _ensure_pouch_container(inv: Inventory, pouch_id: int, w: int, h: int, mode: String = "normal") -> void:
	if inv.pouches.has(pouch_id):
		return
	var cells: Array = []
	for yy: int in range(h):
		var row: Array = []
		for xx: int in range(w):
			row.append(-1)
		cells.append(row)
	var items: Dictionary = {}
	var c: Dictionary = {
		"w": w,
		"h": h,
		"cells": cells,
		"items": items,
		"mode": mode,
		"fusion_locked": false,
		"fusion_locked_item": -1
	}
	inv.pouches[pouch_id] = c

func get_open_pouch_id(inv: Inventory) -> int:
	return inv.open_pouch_id

func pouch_dims(inv: Inventory, pouch_id: int) -> Vector2i:
	if not inv.pouches.has(pouch_id):
		return Vector2i.ZERO
	var c: Dictionary = inv.pouches[pouch_id]
	return Vector2i(int(c["w"]), int(c["h"]))

func pouch_id_at(inv: Inventory, pouch_id: int, x: int, y: int) -> int:
	if not inv.pouches.has(pouch_id):
		return -1
	var c: Dictionary = inv.pouches[pouch_id]
	var w: int = int(c["w"])
	var h: int = int(c["h"])
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	var cells: Array = c["cells"]
	var row: Array = cells[y]
	return int(row[x])

func _pouch_can_place_at(inv: Inventory, pouch_id: int, top_left: Vector2i, size: Vector2i) -> bool:
	if not inv.pouches.has(pouch_id):
		return false
	var c: Dictionary = inv.pouches[pouch_id]
	var w: int = int(c["w"])
	var h: int = int(c["h"])
	if top_left.x < 0 or top_left.y < 0:
		return false
	if top_left.x + size.x > w or top_left.y + size.y > h:
		return false
	var cells: Array = c["cells"]
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			if int(row[xx]) != -1:
				return false
	return true

func _pouch_fill(inv: Inventory, pouch_id: int, top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	if not inv.pouches.has(pouch_id):
		return
	var c: Dictionary = inv.pouches[pouch_id]
	var cells: Array = c["cells"]
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = item_id
		cells[yy] = row
	c["cells"] = cells
	inv.pouches[pouch_id] = c

func _pouch_clear(inv: Inventory, pouch_id: int, top_left: Vector2i, size: Vector2i) -> void:
	if not inv.pouches.has(pouch_id):
		return
	var c: Dictionary = inv.pouches[pouch_id]
	var cells: Array = c["cells"]
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = -1
		cells[yy] = row
	c["cells"] = cells
	inv.pouches[pouch_id] = c

func pouch_place_item_at(inv: Inventory, pouch_id: int, item: Dictionary, top_left: Vector2i) -> bool:
	var t_item: String = String(item.get("type",""))
	if t_item == "pouch" or t_item == "pouch_fusion":
		return false
	if not inv.pouches.has(pouch_id):
		return false
	var c: Dictionary = inv.pouches[pouch_id]
	var mode: String = String(c.get("mode","normal"))
	if mode == "fusion":
		if bool(c.get("fusion_locked", false)):
			return false
		if t_item != "weapon" and t_item != "shield":
			return false
		var items_now: Dictionary = c["items"]
		if items_now.size() >= 2:
			return false
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	if not self._pouch_can_place_at(inv, pouch_id, top_left, size):
		return false
	self._pouch_fill(inv, pouch_id, top_left, size, int(item["id"]))
	item["pos"] = top_left
	var items: Dictionary = c["items"]
	items[int(item["id"])] = item
	c["items"] = items
	inv.pouches[pouch_id] = c
	if mode == "fusion":
		self._fusion_try_merge(inv, pouch_id)
	return true

func pouch_remove_item(inv: Inventory, pouch_id: int, item_id: int) -> Dictionary:
	if not inv.pouches.has(pouch_id):
		return {}
	var c: Dictionary = inv.pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(item_id):
		return {}
	var it: Dictionary = items[item_id]
	var pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	self._pouch_clear(inv, pouch_id, pos, size)
	items.erase(item_id)
	c["items"] = items
	inv.pouches[pouch_id] = c

	# 合成済み装備を取り出したら、合成の袋そのものを消す
	var mode2: String = String(c.get("mode", "normal"))
	if mode2 == "fusion":
		var locked: bool = bool(c.get("fusion_locked", false))
		var locked_id: int = int(c.get("fusion_locked_item", -1))
		if locked and item_id == locked_id:
			if inv.open_pouch_id == pouch_id:
				inv.open_pouch_id = -1
				inv.pouch_toggled.emit(false, -1)
			inv.pouches.erase(pouch_id)
			inv.remove_item_from_bag(pouch_id)
	return it

func pouch_move_item_to(inv: Inventory, pouch_id: int, item_id: int, new_tl: Vector2i) -> bool:
	if not inv.pouches.has(pouch_id):
		return false
	var c: Dictionary = inv.pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(item_id):
		return false
	var it: Dictionary = items[item_id]
	var old_pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	if old_pos == new_tl:
		return true
	self._pouch_clear(inv, pouch_id, old_pos, size)
	if self._pouch_can_place_at(inv, pouch_id, new_tl, size):
		self._pouch_fill(inv, pouch_id, new_tl, size, item_id)
		it["pos"] = new_tl
		items[item_id] = it
		c["items"] = items
		inv.pouches[pouch_id] = c
		return true
	self._pouch_fill(inv, pouch_id, old_pos, size, item_id)
	return false

func _fusion_try_merge(inv: Inventory, pouch_id: int) -> void:
	if not inv.pouches.has(pouch_id):
		return
	var c: Dictionary = inv.pouches[pouch_id]
	var items: Dictionary = c["items"]
	if items.size() != 2:
		return
	var keys: Array = items.keys()
	var a_id: int = int(keys[0])
	var b_id: int = int(keys[1])
	var a: Dictionary = items[a_id]
	var b: Dictionary = items[b_id]
	var ta: String = String(a.get("type",""))
	var tb: String = String(b.get("type",""))
	if ta != tb:
		return

	# 左上の装備を基準に名称を決める
	var pos_a: Vector2i = a.get("pos", Vector2i.ZERO)
	var pos_b: Vector2i = b.get("pos", Vector2i.ZERO)
	var use_a: bool = true
	if pos_a.y > pos_b.y:
		use_a = false
	elif pos_a.y == pos_b.y:
		if pos_a.x > pos_b.x:
			use_a = false
	var base_item: Dictionary = a
	if not use_a:
		base_item = b
	var base_name: String = _extract_base_name(String(base_item.get("name", "")))

	# +値は合計
	var pa: int = int(a.get("plus", 0))
	var pb: int = int(b.get("plus", 0))
	var total_plus: int = pa + pb

	var merged: Dictionary = base_item.duplicate(true)
	merged["plus"] = total_plus
	merged["name"] = _format_fused_name(base_name, total_plus)

	# a, b を消し、merged を空き位置に置く
	self.pouch_remove_item(inv, pouch_id, a_id)
	self.pouch_remove_item(inv, pouch_id, b_id)
	self.pouch_place_item_at(inv, pouch_id, merged, Vector2i(0, 0))
	c = inv.pouches[pouch_id]
	c["fusion_locked"] = true
	c["fusion_locked_item"] = int(merged.get("id", -1))
	inv.pouches[pouch_id] = c

func expand_pouch_by_one(inv: Inventory, pouch_id: int) -> bool:
	if not inv.pouches.has(pouch_id):
		return false
	var c: Dictionary = inv.pouches[pouch_id]
	if String(c.get("mode","normal")) != "normal":
		return false
	var w: int = int(c["w"])
	var h: int = int(c["h"])
	if h < 6:
		var new_row: Array = []
		for _i: int in range(w):
			new_row.append(-1)
		var cells0: Array = c["cells"]
		cells0.append(new_row)
		c["cells"] = cells0
		c["h"] = h + 1
		inv.pouches[pouch_id] = c
		return true
	if h >= 6 and w < 6:
		var cells1: Array = c["cells"]
		for yy: int in range(h):
			var row: Array = cells1[yy]
			row.append(-1)
			cells1[yy] = row
		c["cells"] = cells1
		c["w"] = w + 1
		inv.pouches[pouch_id] = c
		return true
	return false
