extends Node
class_name Inventory

signal pouch_toggled(open: bool, id: int)

var main: Main
var status: Status

# 装備
var equip_weapon: Dictionary = {}
var equip_shield: Dictionary = {}
var equip_weapon_bonus_atk: int = 0
var equip_shield_bonus_def: int = 0

# バッグ（6×6）
var bag_w: int = 6
var bag_h: int = 6
var bag_cells: Array = []
var bag_items: Dictionary = {} # item_id -> item
var next_id: int = 1

# 地面（足元）
var ground: Dictionary = {}    # Vector2i -> Array[item]

# 袋コンテナ（通常/合成）
# pouches[pouch_id] = {
#   "w": int, "h": int, "cells": Array, "items": Dictionary,
#   "mode": "normal"|"fusion", "fusion_locked": bool, "fusion_locked_item": int
# }
var pouches: Dictionary = {}
var open_pouch_id: int = -1

# 直近 use のターン消費
var last_use_consumed_turn: bool = true

# 強化の上限（可変・既定10）
var max_plus_limit: int = 10

func _ready() -> void:
	if bag_cells.is_empty():
		init_inventory()

func init_inventory() -> void:
	equip_weapon = {}
	equip_shield = {}
	equip_weapon_bonus_atk = 0
	equip_shield_bonus_def = 0

	bag_items.clear()
	bag_cells.clear()
	for y: int in bag_h:
		var row: Array = []
		for x: int in bag_w:
			row.append(-1)
		bag_cells.append(row)
	ground.clear()

	pouches.clear()
	open_pouch_id = -1
	last_use_consumed_turn = true

# -------------------------
# 設定
# -------------------------
func set_max_plus_limit(v: int) -> void:
	max_plus_limit = max(0, v)

func get_max_plus_limit() -> int:
	return max_plus_limit

func close_pouch() -> void:
	if open_pouch_id != -1:
		open_pouch_id = -1
		pouch_toggled.emit(false, -1)

# -------------------------
# ID/生成
# -------------------------
func _alloc_id() -> int:
	var idv: int = next_id
	next_id += 1
	return idv

func make_item(name: String, w: int, h: int, t: String) -> Dictionary:
	var it: Dictionary = {
		"id": _alloc_id(),
		"name": name,
		"size": Vector2i(w, h),
		"type": t
	}
	return it

func create_wood_sword(plus: int) -> Dictionary:
	var it: Dictionary = make_item("木の剣+" + str(plus), 1, 3, "weapon")
	it["base"] = 1
	it["plus"] = plus
	return it

func create_wood_shield(plus: int) -> Dictionary:
	var it: Dictionary = make_item("木の盾+" + str(plus), 2, 2, "shield")
	it["base"] = 1
	it["plus"] = plus
	return it

func create_herb() -> Dictionary:
	var it: Dictionary = make_item("薬草", 1, 1, "potion")
	it["heal"] = 20
	return it

func create_onigiri() -> Dictionary:
	var it: Dictionary = make_item("おにぎり", 1, 1, "food")
	it["belly"] = 50
	return it

# 通常の袋（2×3 本体）／内部 2×4
func create_pouch() -> Dictionary:
	var it: Dictionary = make_item("袋", 2, 3, "pouch")
	it["pouch_w"] = 2
	it["pouch_h"] = 4
	return it

# 合成の袋（2×3 本体）／内部 2×4
func create_fusion_pouch() -> Dictionary:
	var it: Dictionary = make_item("合成の袋", 2, 3, "pouch_fusion")
	it["pouch_w"] = 2
	it["pouch_h"] = 4
	return it

# 強化のシール（1×1）
func create_enhance_seal() -> Dictionary:
	var it: Dictionary = make_item("強化のシール", 1, 1, "seal")
	return it

# 拡張のシール（1×1）
func create_expand_seal() -> Dictionary:
	var it: Dictionary = make_item("拡張のシール", 1, 1, "seal_expand")
	return it

# -------------------------
# 地面
# -------------------------
func add_item_to_ground(cell: Vector2i, item: Dictionary) -> void:
	var list: Array = ground.get(cell, [])
	if list.is_empty():
		list = []
	list.append(item)
	ground[cell] = list

func get_ground_items_at(cell: Vector2i) -> Array:
	if ground.has(cell):
		return ground[cell]
	return []

func get_ground_top_item(cell: Vector2i) -> Dictionary:
	var arr: Array = get_ground_items_at(cell)
	if arr.size() > 0:
		return arr[0]
	return {}

func pickup_ground_item(cell: Vector2i, item_id: int) -> bool:
	if not ground.has(cell):
		return false
	var arr: Array = ground[cell]
	for i: int in range(arr.size() - 1, -1, -1):
		var it: Dictionary = arr[i]
		if int(it.get("id", -999)) == item_id:
			if place_item_in_bag(it):
				arr.remove_at(i)
				if arr.is_empty():
					ground.erase(cell)
				else:
					ground[cell] = arr
				return true
			return false
	return false

func take_item_from_ground(cell: Vector2i, item_id: int) -> Dictionary:
	if not ground.has(cell):
		return {}
	var arr: Array = ground[cell]
	for i: int in range(arr.size() - 1, -1, -1):
		var it: Dictionary = arr[i]
		if int(it.get("id", -1)) == item_id:
			arr.remove_at(i)
			if arr.is_empty():
				ground.erase(cell)
			else:
				ground[cell] = arr
			return it
	return {}

# -------------------------
# バッグ（6×6）
# -------------------------
func _can_place_at(top_left: Vector2i, size: Vector2i) -> bool:
	if top_left.x < 0 or top_left.y < 0:
		return false
	if top_left.x + size.x > bag_w or top_left.y + size.y > bag_h:
		return false
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			if int(row[xx]) != -1:
				return false
	return true

func _fill_cells(top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = item_id
		bag_cells[yy] = row

func _clear_cells(top_left: Vector2i, size: Vector2i) -> void:
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = bag_cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = -1
		bag_cells[yy] = row

func find_fit(size: Vector2i) -> Vector2i:
	for y: int in bag_h:
		for x: int in bag_w:
			var tl: Vector2i = Vector2i(x, y)
			if _can_place_at(tl, size):
				return tl
	return Vector2i(-1, -1)

func place_item_in_bag(item: Dictionary) -> bool:
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	var pos: Vector2i = find_fit(size)
	if pos.x == -1:
		return false
	_fill_cells(pos, size, int(item["id"]))
	item["pos"] = pos
	bag_items[int(item["id"])] = item
	return true

func place_item_in_bag_at(item: Dictionary, top_left: Vector2i) -> bool:
	var size: Vector2i = item.get("size", Vector2i(1, 1))
	if not _can_place_at(top_left, size):
		return false
	_fill_cells(top_left, size, int(item["id"]))
	item["pos"] = top_left
	bag_items[int(item["id"])] = item
	return true

func remove_item_from_bag(item_id: int) -> Dictionary:
	if not bag_items.has(item_id):
		return {}
	var it: Dictionary = bag_items[item_id]
	var pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	_clear_cells(pos, size)
	bag_items.erase(item_id)
	return it

func move_item_in_bag_to(item_id: int, new_tl: Vector2i) -> bool:
	if not bag_items.has(item_id):
		return false
	var it: Dictionary = bag_items[item_id]
	var old_pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	if old_pos == new_tl:
		return true
	_clear_cells(old_pos, size)
	if _can_place_at(new_tl, size):
		_fill_cells(new_tl, size, item_id)
		it["pos"] = new_tl
		bag_items[item_id] = it
		return true
	_fill_cells(old_pos, size, item_id)
	return false

func bag_id_at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= bag_w or y >= bag_h:
		return -1
	var row: Array = bag_cells[y]
	return int(row[x])

# -------------------------
# 袋コンテナ（通常/合成）2×4〜最大6×6
# -------------------------
func _ensure_pouch_container(pouch_id: int, w: int, h: int, mode: String = "normal") -> void:
	if pouches.has(pouch_id):
		return
	var cells: Array = []
	for yy: int in h:
		var row: Array = []
		for xx: int in w:
			row.append(-1)
		cells.append(row)
	pouches[pouch_id] = {
		"w": w, "h": h, "cells": cells, "items": {},
		"mode": mode, "fusion_locked": false, "fusion_locked_item": -1
	}

func get_open_pouch_id() -> int:
	return open_pouch_id

func pouch_dims(pouch_id: int) -> Vector2i:
	if not pouches.has(pouch_id):
		return Vector2i(0, 0)
	var c: Dictionary = pouches[pouch_id]
	return Vector2i(int(c["w"]), int(c["h"]))

func pouch_id_at(pouch_id: int, x: int, y: int) -> int:
	if not pouches.has(pouch_id):
		return -1
	var c: Dictionary = pouches[pouch_id]
	var w: int = int(c["w"])
	var h: int = int(c["h"])
	if x < 0 or y < 0 or x >= w or y >= h:
		return -1
	var cells: Array = c["cells"]
	var row: Array = cells[y]
	return int(row[x])

func _pouch_can_place_at(pouch_id: int, top_left: Vector2i, size: Vector2i) -> bool:
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
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

func _pouch_fill(pouch_id: int, top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	var c: Dictionary = pouches[pouch_id]
	var cells: Array = c["cells"]
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = item_id
		cells[yy] = row
	c["cells"] = cells
	pouches[pouch_id] = c

func _pouch_clear(pouch_id: int, top_left: Vector2i, size: Vector2i) -> void:
	var c: Dictionary = pouches[pouch_id]
	var cells: Array = c["cells"]
	for yy: int in range(top_left.y, top_left.y + size.y):
		var row: Array = cells[yy]
		for xx: int in range(top_left.x, top_left.x + size.x):
			row[xx] = -1
		cells[yy] = row
	c["cells"] = cells
	pouches[pouch_id] = c

func pouch_place_item_at(pouch_id: int, item: Dictionary, top_left: Vector2i) -> bool:
	var t_item: String = String(item.get("type",""))
	if t_item == "pouch" or t_item == "pouch_fusion":
		return false
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
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
	if not _pouch_can_place_at(pouch_id, top_left, size):
		return false
	_pouch_fill(pouch_id, top_left, size, int(item["id"]))
	item["pos"] = top_left
	var items: Dictionary = c["items"]
	items[int(item["id"])] = item
	c["items"] = items
	pouches[pouch_id] = c

	# 合成の袋：2つ揃ったら合成
	if mode == "fusion":
		_fusion_try_merge(pouch_id)
	return true

func pouch_remove_item(pouch_id: int, item_id: int) -> Dictionary:
	if not pouches.has(pouch_id):
		return {}
	var c: Dictionary = pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(item_id):
		return {}
	var it: Dictionary = items[item_id]
	var pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	_pouch_clear(pouch_id, pos, size)
	items.erase(item_id)
	c["items"] = items
	pouches[pouch_id] = c

	# 合成の袋：ロック状態で取り出して空になったら袋自体を消す
	var mode: String = String(c.get("mode","normal"))
	if mode == "fusion" and bool(c.get("fusion_locked", false)) and items.size() == 0:
		remove_item_from_bag(pouch_id)
		pouches.erase(pouch_id)
		if open_pouch_id == pouch_id:
			open_pouch_id = -1
			pouch_toggled.emit(false, -1)
	return it

func pouch_move_item_to(pouch_id: int, item_id: int, new_tl: Vector2i) -> bool:
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
	if String(c.get("mode","normal")) == "fusion" and bool(c.get("fusion_locked", false)):
		return false
	var items: Dictionary = c["items"]
	if not items.has(item_id):
		return false
	var it: Dictionary = items[item_id]
	var old_pos: Vector2i = it.get("pos", Vector2i.ZERO)
	var size: Vector2i = it.get("size", Vector2i(1, 1))
	if old_pos == new_tl:
		return true
	_pouch_clear(pouch_id, old_pos, size)
	if _pouch_can_place_at(pouch_id, new_tl, size):
		_pouch_fill(pouch_id, new_tl, size, item_id)
		it["pos"] = new_tl
		items[item_id] = it
		c["items"] = items
		pouches[pouch_id] = c
		return true
	_pouch_fill(pouch_id, old_pos, size, item_id)
	return false

# ★ 合成ロジック
# Inventory.gd 内
func _fusion_try_merge(pouch_id: int) -> void:
	if not pouches.has(pouch_id):
		return
	var c: Dictionary = pouches[pouch_id]
	if String(c.get("mode","normal")) != "fusion":
		return
	var items: Dictionary = c["items"]
	if items.size() < 2:
		return
	# 同カテゴリ2つを探す
	var ids: Array = items.keys()
	var keep_id: int = -1
	var drop_id: int = -1
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var ida: int = int(ids[i])
			var idb: int = int(ids[j])
			var ia: Dictionary = items[ida]
			var ib: Dictionary = items[idb]
			var ta: String = String(ia.get("type",""))
			var tb: String = String(ib.get("type",""))
			if (ta == "weapon" or ta == "shield") and ta == tb:
				# ★ 左上が残る（xが小さい方。x同値ならyが小さい方）
				var pa: Vector2i = ia.get("pos", Vector2i.ZERO)
				var pb: Vector2i = ib.get("pos", Vector2i.ZERO)
				var choose_a: bool = false
				if pa.x < pb.x:
					choose_a = true
				elif pa.x == pb.x and pa.y < pb.y:
					choose_a = true
				if choose_a:
					keep_id = ida
					drop_id = idb
				else:

					keep_id = idb
					drop_id = ida
				break
		if keep_id != -1:
			break
	if keep_id == -1:
		return

	var keep_it: Dictionary = items[keep_id]
	var drop_it: Dictionary = items[drop_id]
	var plus_total: int = int(keep_it.get("plus", 0)) + int(drop_it.get("plus", 0))
	keep_it["plus"] = plus_total
	_rename_plus_item(keep_it)
	items[keep_id] = keep_it

	# 消える側をクリア
	var dp: Vector2i = drop_it.get("pos", Vector2i.ZERO)
	var ds: Vector2i = drop_it.get("size", Vector2i(1, 1))
	_pouch_clear(pouch_id, dp, ds)
	items.erase(drop_id)

	# 合成後は残った装備以外のマスをロック
	c["items"] = items
	c["fusion_locked"] = true
	c["fusion_locked_item"] = keep_id
	pouches[pouch_id] = c


# -------------------------
# 装備
# -------------------------
func _apply_unequip_effect(slot: String) -> void:
	if slot == "weapon":
		if equip_weapon_bonus_atk != 0:
			status.atk = max(0, status.atk - equip_weapon_bonus_atk)
			equip_weapon_bonus_atk = 0
	if slot == "shield":
		if equip_shield_bonus_def != 0:
			status.def = max(0, status.def - equip_shield_bonus_def)
			equip_shield_bonus_def = 0

func _apply_equip_effect(item: Dictionary) -> void:
	var t: String = item.get("type", "")
	if t == "weapon":
		var base: int = int(item.get("base", 0))
		var plus: int = int(item.get("plus", 0))
		equip_weapon_bonus_atk = base + plus
		status.atk += equip_weapon_bonus_atk
	elif t == "shield":
		var base2: int = int(item.get("base", 0))
		var plus2: int = int(item.get("plus", 0))
		equip_shield_bonus_def = base2 + plus2
		status.def += equip_shield_bonus_def

func equip_from_bag(item_id: int) -> bool:
	if not bag_items.has(item_id):
		return false
	var it: Dictionary = bag_items[item_id]
	var t: String = it.get("type", "")
	if t == "weapon":
		if not equip_weapon.is_empty():
			var back: Dictionary = equip_weapon
			if not place_item_in_bag(back):
				return false
		remove_item_from_bag(item_id)
		_apply_unequip_effect("weapon")
		equip_weapon = it
		_apply_equip_effect(it)
		return true
	elif t == "shield":
		if not equip_shield.is_empty():
			var back2: Dictionary = equip_shield
			if not place_item_in_bag(back2):
				return false
		remove_item_from_bag(item_id)
		_apply_unequip_effect("shield")
		equip_shield = it
		_apply_equip_effect(it)
		return true
	return false

func unequip_to_bag(slot: String) -> bool:
	if slot == "weapon":
		if equip_weapon.is_empty():
			return false
		var it: Dictionary = equip_weapon
		if not place_item_in_bag(it):
			return false
		_apply_unequip_effect("weapon")
		equip_weapon = {}
		return true
	if slot == "shield":
		if equip_shield.is_empty():
			return false
		var it2: Dictionary = equip_shield
		if not place_item_in_bag(it2):
			return false
		_apply_unequip_effect("shield")
		equip_shield = {}
		return true
	return false

# -------------------------
# 使う（バッグ／袋）
# -------------------------
func use_item_from_bag(item_id: int) -> bool:
	last_use_consumed_turn = true
	if not bag_items.has(item_id):
		return false
	var it: Dictionary = bag_items[item_id]
	var t: String = it.get("type", "")
	if t == "potion":
		var heal: int = int(it.get("heal", 0))
		if heal > 0:
			status.hp = min(status.max_hp, status.hp + heal)
		remove_item_from_bag(item_id)
		return true
	if t == "food":
		var gain: int = int(it.get("belly", 0))
		if gain > 0:
			status.belly = min(status.belly_max, status.belly + gain)
		remove_item_from_bag(item_id)
		return true
	if t == "weapon" or t == "shield":
		return equip_from_bag(item_id)
	if t == "pouch":
		var w: int = int(it.get("pouch_w", 2))
		var h: int = int(it.get("pouch_h", 4))
		_ensure_pouch_container(item_id, w, h, "normal")
		if open_pouch_id == item_id:
			open_pouch_id = -1
			pouch_toggled.emit(false, -1)
		else:
			open_pouch_id = item_id
			pouch_toggled.emit(true, item_id)
		last_use_consumed_turn = false
		return true
	if t == "pouch_fusion":
		var w2: int = int(it.get("pouch_w", 2))
		var h2: int = int(it.get("pouch_h", 4))
		_ensure_pouch_container(item_id, w2, h2, "fusion")
		if open_pouch_id == item_id:
			open_pouch_id = -1
			pouch_toggled.emit(false, -1)
		else:
			open_pouch_id = item_id
			pouch_toggled.emit(true, item_id)
		last_use_consumed_turn = false
		return true
	if t == "seal":
		last_use_consumed_turn = false
		return false
	if t == "seal_expand":
		last_use_consumed_turn = false
		return false
	return false

func use_item_from_pouch(pouch_id: int, item_id: int) -> bool:
	last_use_consumed_turn = true
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(item_id):
		return false
	var it: Dictionary = items[item_id]
	var t: String = it.get("type", "")
	if t == "potion":
		var heal: int = int(it.get("heal", 0))
		if heal > 0:
			status.hp = min(status.max_hp, status.hp + heal)
		pouch_remove_item(pouch_id, item_id)
		return true
	if t == "food":
		var gain: int = int(it.get("belly", 0))
		if gain > 0:
			status.belly = min(status.belly_max, status.belly + gain)
		pouch_remove_item(pouch_id, item_id)
		return true
	if t == "weapon" or t == "shield":
		var old_pos: Vector2i = it.get("pos", Vector2i.ZERO)
		var picked: Dictionary = pouch_remove_item(pouch_id, item_id)
		if picked.is_empty():
			return false
		if t == "weapon":
			if not equip_weapon.is_empty():
				var back: Dictionary = equip_weapon
				if not place_item_in_bag(back):
					pouch_place_item_at(pouch_id, picked, old_pos)
					return false
			_apply_unequip_effect("weapon")
			equip_weapon = picked
			_apply_equip_effect(picked)
			return true
		else:
			if not equip_shield.is_empty():
				var back2: Dictionary = equip_shield
				if not place_item_in_bag(back2):
					pouch_place_item_at(pouch_id, picked, old_pos)
					return false
			_apply_unequip_effect("shield")
			equip_shield = picked
			_apply_equip_effect(picked)
			return true
	if t == "seal":
		last_use_consumed_turn = false
		return false
	if t == "seal_expand":
		last_use_consumed_turn = false
		return false
	return false

# -------------------------
# 強化シール：適用
# -------------------------
func _can_enhance_dict(it: Dictionary) -> bool:
	return it.has("plus")

func _rename_plus_item(it: Dictionary) -> void:
	var name0: String = String(it.get("name", ""))
	var base_name: String = name0
	var idx: int = name0.find("+")
	if idx >= 0:
		base_name = name0.substr(0, idx)
	var p: int = int(it.get("plus", 0))
	it["name"] = base_name + "+" + str(p)

func _enhance_bag_item(target_id: int) -> bool:
	if not bag_items.has(target_id):
		return false
	var it: Dictionary = bag_items[target_id]
	if not _can_enhance_dict(it):
		return false
	var cur: int = int(it.get("plus", 0))
	if cur >= max_plus_limit:
		return false
	it["plus"] = cur + 1
	_rename_plus_item(it)
	bag_items[target_id] = it
	return true

func _enhance_pouch_item(pouch_id: int, target_id: int) -> bool:
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
	var items: Dictionary = c["items"]
	if not items.has(target_id):
		return false
	var it: Dictionary = items[target_id]
	if not _can_enhance_dict(it):
		return false
	var cur: int = int(it.get("plus", 0))
	if cur >= max_plus_limit:
		return false
	it["plus"] = cur + 1
	_rename_plus_item(it)
	items[target_id] = it
	c["items"] = items
	pouches[pouch_id] = c
	return true

func _consume_seal_from_bag(seal_id: int) -> bool:
	var rem: Dictionary = remove_item_from_bag(seal_id)
	return not rem.is_empty()

func _consume_seal_from_pouch(pouch_id: int, seal_id: int) -> bool:
	var rem: Dictionary = pouch_remove_item(pouch_id, seal_id)
	return not rem.is_empty()

func apply_seal_from_bag_to_bag(seal_id: int, target_id: int) -> bool:
	if not bag_items.has(seal_id):
		return false
	if not _enhance_bag_item(target_id):
		return false
	if not _consume_seal_from_bag(seal_id):
		return false
	last_use_consumed_turn = true
	return true

func apply_seal_from_bag_to_pouch(seal_id: int, pouch_id: int, target_id: int) -> bool:
	if not bag_items.has(seal_id):
		return false
	if not _enhance_pouch_item(pouch_id, target_id):
		return false
	if not _consume_seal_from_bag(seal_id):
		return false
	last_use_consumed_turn = true
	return true

func apply_seal_from_pouch_to_bag(pouch_id: int, seal_id: int, target_id: int) -> bool:
	if not pouches.has(pouch_id):
		return false
	if not _enhance_bag_item(target_id):
		return false
	if not _consume_seal_from_pouch(pouch_id, seal_id):
		return false
	last_use_consumed_turn = true
	return true

func apply_seal_from_pouch_to_pouch(pouch_id: int, seal_id: int, target_id: int) -> bool:
	if not pouches.has(pouch_id):
		return false
	if not _enhance_pouch_item(pouch_id, target_id):
		return false
	if not _consume_seal_from_pouch(pouch_id, seal_id):
		return false
	last_use_consumed_turn = true
	return true

# -------------------------
# 拡張シール：適用（通常の袋のみ）
# -------------------------
func expand_pouch_by_one(pouch_id: int) -> bool:
	if not pouches.has(pouch_id):
		return false
	var c: Dictionary = pouches[pouch_id]
	if String(c.get("mode","normal")) != "normal":
		return false
	var w: int = int(c["w"])
	var h: int = int(c["h"])
	if h < 6:
		var new_row: Array = []
		for _i: int in w:
			new_row.append(-1)
		var cells0: Array = c["cells"]
		cells0.append(new_row)
		c["cells"] = cells0
		c["h"] = h + 1
		pouches[pouch_id] = c
		return true
	if h >= 6 and w < 6:
		var cells1: Array = c["cells"]
		for yy: int in h:
			var row: Array = cells1[yy]
			row.append(-1)
			cells1[yy] = row
		c["cells"] = cells1
		c["w"] = w + 1
		pouches[pouch_id] = c
		return true
	return false

func apply_expand_from_bag(seal_id: int) -> bool:
	if not bag_items.has(seal_id):
		return false
	if open_pouch_id == -1:
		return false
	if not expand_pouch_by_one(open_pouch_id):
		return false
	if not _consume_seal_from_bag(seal_id):
		return false
	last_use_consumed_turn = true
	return true

func apply_expand_from_pouch(pouch_id: int, seal_id: int) -> bool:
	if not pouches.has(pouch_id):
		return false
	if open_pouch_id == -1:
		return false
	if not expand_pouch_by_one(open_pouch_id):
		return false
	if not _consume_seal_from_pouch(pouch_id, seal_id):
		return false
	last_use_consumed_turn = true
	return true
