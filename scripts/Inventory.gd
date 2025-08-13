extends Node
class_name Inventory

signal pouch_toggled(open: bool, id: int)

var main: Node
var status: Node

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
var pouches: Dictionary = {}
var open_pouch_id: int = -1

# 直近 use のターン消費
var last_use_consumed_turn: bool = true

# 強化の上限（可変・既定10）
var max_plus_limit: int = 10

var item_factory: ItemFactory
var bag_ops: BagGridOps
var pouch_ops: PouchSystem
var ground_ops: GroundSystem
var seal_ops: SealSystem

func _ready() -> void:
	item_factory = ItemFactory.new()
	bag_ops = BagGridOps.new()
	pouch_ops = PouchSystem.new()
	ground_ops = GroundSystem.new()
	seal_ops = SealSystem.new()
	if bag_cells.is_empty():
		init_inventory()

func init_inventory() -> void:
	equip_weapon = {}
	equip_shield = {}
	equip_weapon_bonus_atk = 0
	equip_shield_bonus_def = 0
	bag_items.clear()
	bag_cells.clear()
	for y: int in range(bag_h):
		var row: Array = []
		for x: int in range(bag_w):
			row.append(-1)
		bag_cells.append(row)
	ground.clear()
	pouches.clear()
	open_pouch_id = -1
	last_use_consumed_turn = true
	var s: Dictionary = create_wood_sword(0)
	place_item_in_bag_at(s, Vector2i(0, 0))
	var sh: Dictionary = create_wood_shield(0)
	place_item_in_bag_at(sh, Vector2i(2, 0))
	var h: Dictionary = create_herb()
	place_item_in_bag(h)
	var f: Dictionary = create_fusion_pouch()
	place_item_in_bag(f)
	var e: Dictionary = create_enhance_seal()
	place_item_in_bag(e)
	var ex: Dictionary = create_expand_seal()
	place_item_in_bag(ex)

func set_max_plus_limit(v: int) -> void:
	max_plus_limit = v

func get_max_plus_limit() -> int:
	return max_plus_limit

func close_pouch() -> void:
	pouch_ops.close_pouch(self)

# -------------------------
# ID/生成
# -------------------------

func _alloc_id() -> int:
	var id: int = next_id
	next_id += 1
	return id

func make_item(name: String, w: int, h: int, t: String) -> Dictionary:
	return item_factory.make_item(self, name, w, h, t)

func create_wood_sword(plus: int) -> Dictionary:
	return item_factory.create_wood_sword(self, plus)

func create_wood_shield(plus: int) -> Dictionary:
	return item_factory.create_wood_shield(self, plus)

func create_herb() -> Dictionary:
	return item_factory.create_herb(self)

func create_onigiri() -> Dictionary:
	return item_factory.create_onigiri(self)

func create_pouch() -> Dictionary:
	return item_factory.create_pouch(self)

func create_fusion_pouch() -> Dictionary:
	return item_factory.create_fusion_pouch(self)

func create_enhance_seal() -> Dictionary:
	return item_factory.create_enhance_seal(self)

func create_expand_seal() -> Dictionary:
	return item_factory.create_expand_seal(self)

# ★ 家具
func create_furniture() -> Dictionary:
	return item_factory.create_furniture(self)

# -------------------------
# 地面
# -------------------------

func add_item_to_ground(cell: Vector2i, item: Dictionary) -> void:
	ground_ops.add_item_to_ground(self, cell, item)

func get_ground_items_at(cell: Vector2i) -> Array:
	return ground_ops.get_ground_items_at(self, cell)

func get_ground_top_item(cell: Vector2i) -> Dictionary:
	return ground_ops.get_ground_top_item(self, cell)

func pickup_ground_item(cell: Vector2i) -> bool:
	return ground_ops.pickup_ground_item(self, cell)

func take_item_from_ground(cell: Vector2i, item_id: int) -> Dictionary:
	return ground_ops.take_item_from_ground(self, cell, item_id)

# -------------------------
# バッグ（6×6）
# -------------------------

func place_item_in_bag(item: Dictionary) -> bool:
	return bag_ops.place_item_in_bag(self, item)

func place_item_in_bag_at(item: Dictionary, top_left: Vector2i) -> bool:
	return bag_ops.place_item_in_bag_at(self, item, top_left)

func remove_item_from_bag(item_id: int) -> Dictionary:
	return bag_ops.remove_item_from_bag(self, item_id)

func move_item_in_bag_to(item_id: int, new_tl: Vector2i) -> bool:
	return bag_ops.move_item_in_bag_to(self, item_id, new_tl)

func bag_id_at(x: int, y: int) -> int:
	return bag_ops.bag_id_at(self, x, y)

func find_fit(size: Vector2i) -> Vector2i:
	return bag_ops.find_fit(self, size)

func _fill_cells(top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	bag_ops._fill_cells(self, top_left, size, item_id)

func _clear_cells(top_left: Vector2i, size: Vector2i) -> void:
	bag_ops._clear_cells(self, top_left, size)

func _can_place_at(top_left: Vector2i, size: Vector2i) -> bool:
	return bag_ops._can_place_at(self, top_left, size)

# -------------------------
# 袋（通常／合成）
# -------------------------

func _ensure_pouch_container(pouch_id: int, w: int, h: int, mode: String = "normal") -> void:
	pouch_ops._ensure_pouch_container(self, pouch_id, w, h, mode)

func get_open_pouch_id() -> int:
	return pouch_ops.get_open_pouch_id(self)

func pouch_dims(pouch_id: int) -> Vector2i:
	return pouch_ops.pouch_dims(self, pouch_id)

func pouch_id_at(pouch_id: int, x: int, y: int) -> int:
	return pouch_ops.pouch_id_at(self, pouch_id, x, y)

func _pouch_can_place_at(pouch_id: int, top_left: Vector2i, size: Vector2i) -> bool:
	return pouch_ops._pouch_can_place_at(self, pouch_id, top_left, size)

func _pouch_fill(pouch_id: int, top_left: Vector2i, size: Vector2i, item_id: int) -> void:
	pouch_ops._pouch_fill(self, pouch_id, top_left, size, item_id)

func _pouch_clear(pouch_id: int, top_left: Vector2i, size: Vector2i) -> void:
	pouch_ops._pouch_clear(self, pouch_id, top_left, size)

func pouch_place_item_at(pouch_id: int, item: Dictionary, top_left: Vector2i) -> bool:
	return pouch_ops.pouch_place_item_at(self, pouch_id, item, top_left)

func pouch_remove_item(pouch_id: int, item_id: int) -> Dictionary:
	return pouch_ops.pouch_remove_item(self, pouch_id, item_id)

func pouch_move_item_to(pouch_id: int, item_id: int, new_tl: Vector2i) -> bool:
	return pouch_ops.pouch_move_item_to(self, pouch_id, item_id, new_tl)

func _fusion_try_merge(pouch_id: int) -> void:
	pouch_ops._fusion_try_merge(self, pouch_id)

func expand_pouch_by_one(pouch_id: int) -> bool:
	return pouch_ops.expand_pouch_by_one(self, pouch_id)

# -------------------------
# 装備
# -------------------------

func _apply_unequip_effect(slot: String) -> void:
	if slot == "weapon":
		status.atk -= equip_weapon_bonus_atk
		equip_weapon_bonus_atk = 0
	elif slot == "shield":
		status.def -= equip_shield_bonus_def
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
		var it_w: Dictionary = equip_weapon
		if not place_item_in_bag(it_w):
			return false
		_apply_unequip_effect("weapon")
		equip_weapon = {}
		return true
	if slot == "shield":
		if equip_shield.is_empty():
			return false
		var it_s: Dictionary = equip_shield
		if not place_item_in_bag(it_s):
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
	if t == "weapon" or t == "shield":
		var ok: bool = equip_from_bag(item_id)
		if not ok:
			last_use_consumed_turn = false
		return ok
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
	if t == "pouch":
		var w0: int = int(it.get("pouch_w", 2))
		var h0: int = int(it.get("pouch_h", 4))
		_ensure_pouch_container(item_id, w0, h0, "normal")
		if open_pouch_id == item_id:
			open_pouch_id = -1
			pouch_toggled.emit(false, -1)
		else:
			open_pouch_id = item_id
			pouch_toggled.emit(true, item_id)
		last_use_consumed_turn = false
		return true
	if t == "pouch_fusion":
		var w1: int = int(it.get("pouch_w", 2))
		var h1: int = int(it.get("pouch_h", 4))
		_ensure_pouch_container(item_id, w1, h1, "fusion")
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
	if t == "seal":
		last_use_consumed_turn = false
		return false
	if t == "seal_expand":
		last_use_consumed_turn = false
		return false
	return false

# -------------------------
# 強化／拡張（ラッパ）
# -------------------------

func _can_enhance_dict(it: Dictionary) -> bool:
	return seal_ops._can_enhance_dict(self, it)

func _rename_plus_item(it: Dictionary) -> void:
	seal_ops._rename_plus_item(self, it)

func _enhance_bag_item(target_id: int) -> bool:
	return seal_ops._enhance_bag_item(self, target_id)

func _enhance_pouch_item(pouch_id: int, target_id: int) -> bool:
	return seal_ops._enhance_pouch_item(self, pouch_id, target_id)

func _consume_seal_from_bag(seal_id: int) -> bool:
	return seal_ops._consume_seal_from_bag(self, seal_id)

func _consume_seal_from_pouch(pouch_id: int, seal_id: int) -> bool:
	return seal_ops._consume_seal_from_pouch(self, pouch_id, seal_id)

func apply_seal_from_bag_to_bag(seal_id: int, target_id: int) -> bool:
	return seal_ops.apply_seal_from_bag_to_bag(self, seal_id, target_id)

func apply_seal_from_bag_to_pouch(seal_id: int, pouch_id: int, target_id: int) -> bool:
	return seal_ops.apply_seal_from_bag_to_pouch(self, seal_id, pouch_id, target_id)

func apply_seal_from_pouch_to_bag(pouch_id: int, seal_id: int, target_id: int) -> bool:
	return seal_ops.apply_seal_from_pouch_to_bag(self, pouch_id, seal_id, target_id)

func apply_seal_from_pouch_to_pouch(pouch_id: int, seal_id: int, target_id: int) -> bool:
	return seal_ops.apply_seal_from_pouch_to_pouch(self, pouch_id, seal_id, target_id)

func apply_expand_from_bag(seal_id: int) -> bool:
	return seal_ops.apply_expand_from_bag(self, seal_id)

func apply_expand_from_pouch(pouch_id: int, seal_id: int) -> bool:
	return seal_ops.apply_expand_from_pouch(self, pouch_id, seal_id)
