extends Node
class_name ItemSpawner

static func reset_ground(inv: Inventory) -> void:
	if inv == null:
		return
	if inv.ground == null:
		inv.ground = {}
	else:
		inv.ground.clear()

static func scatter_items_in_rooms(main: Main, rng: RandomNumberGenerator, min_per_room: int, max_per_room: int, extra: int) -> void:
	if main == null:
		return
	if main.inv == null:
		return
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# ★ 1F限定：プレイヤー足元に「識別済みの薬草」を2個（足元メニューで移動可能）
	if int(main.floor_level) == 1:
		_place_initial_herbs_on_foot(main)

	# 以降：従来の散布（簡易）
	var rooms: Array = main.rooms
	for i in rooms.size():
		var rect: Rect2i = rooms[i]
		var n: int = rng.randi_range(min_per_room, max_per_room)
		for k in n:
			var pos: Vector2i = _random_point_in_room(main, rng, rect)
			if pos.x < 0:
				continue
			var it: Dictionary = _roll_item(rng)
			main.inv.add_item_to_ground(pos, it)

	for m in extra:
		var pos2: Vector2i = _random_floor_anywhere(main, rng)
		if pos2.x < 0:
			continue
		var it2: Dictionary = _roll_item(rng)
		main.inv.add_item_to_ground(pos2, it2)

static func drop_item_with_chance(main: Main, pos: Vector2i, rng: RandomNumberGenerator, chance: float = 0.30) -> void:
	if main == null:
		return
	if main.inv == null:
		return
	var rr: RandomNumberGenerator = rng
	if rr == null:
		rr = RandomNumberGenerator.new()
		rr.randomize()
	var ch: float = chance
	if ch > 1.0:
		ch = ch * 0.01
	if ch <= 0.0:
		return
	if rr.randf() < ch:
		var it: Dictionary = _roll_item(rr)
		main.inv.add_item_to_ground(pos, it)

static func drop_loot(main: Main, pos: Vector2i, rng: RandomNumberGenerator) -> void:
	drop_item_with_chance(main, pos, rng, 0.30)

# --- 内部ヘルパー ---

# 足元に薬草×2。Dictionary は毎回新規生成して ID 競合を回避
static func _place_initial_herbs_on_foot(main: Main) -> void:
	var p: Vector2i = main.player
	main.inv.add_item_to_ground(p, _mk_herb())
	main.inv.add_item_to_ground(p, _mk_herb())

static func _is_floor(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return false
	var row: Array = main.grid[p.y]
	return int(row[p.x]) == 0

static func _mk_herb() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "potion"
	d["identified"] = true
	d["name"] = "薬草"
	d["size_w"] = 1
	d["size_h"] = 1
	return d

static func _random_point_in_room(main: Main, rng: RandomNumberGenerator, rect: Rect2i) -> Vector2i:
	var tries: int = 32
	while tries > 0:
		tries -= 1
		var x: int = rng.randi_range(rect.position.x, rect.position.x + rect.size.x - 1)
		var y: int = rng.randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
		var p: Vector2i = Vector2i(x, y)
		if _is_floor(main, p):
			return p
	return Vector2i(-1, -1)

static func _random_floor_anywhere(main: Main, rng: RandomNumberGenerator) -> Vector2i:
	var tries: int = 64
	while tries > 0:
		tries -= 1
		var x: int = rng.randi_range(0, Params.W - 1)
		var y: int = rng.randi_range(0, Params.H - 1)
		var p: Vector2i = Vector2i(x, y)
		if _is_floor(main, p):
			return p
	return Vector2i(-1, -1)

static func _roll_item(rng: RandomNumberGenerator) -> Dictionary:
	var r: float = rng.randf()
	if r < 0.25:
		return _mk_herb()
	elif r < 0.45:
		return _mk_food()
	elif r < 0.61:
		return _mk_weapon()
	elif r < 0.75:
		return _mk_shield()
	elif r < 0.83:
		return _mk_seal()
	elif r < 0.88:
		return _mk_seal_expand()
	elif r < 0.94:
		return _mk_pouch()
	elif r < 0.97:
		return _mk_pouch_fusion()
	else:
		return _mk_furniture()

static func _mk_food() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "food"
	d["name"] = "食料"
	d["size_w"] = 1
	d["size_h"] = 1
	return d

static func _mk_weapon() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "weapon"
	d["name"] = "木の剣"
	d["size_w"] = 1
	d["size_h"] = 2
	d["plus"] = 0
	return d

static func _mk_shield() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "shield"
	d["name"] = "木の盾"
	d["size_w"] = 2
	d["size_h"] = 2
	d["plus"] = 0
	return d

static func _mk_seal() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "seal"
	d["name"] = "シール"
	d["size_w"] = 1
	d["size_h"] = 1
	return d

static func _mk_seal_expand() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "seal_expand"
	d["name"] = "拡張シール"
	d["size_w"] = 1
	d["size_h"] = 1
	return d

static func _mk_pouch() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "pouch"
	d["name"] = "袋"
	d["size_w"] = 2
	d["size_h"] = 2
	return d

static func _mk_pouch_fusion() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "pouch_fusion"
	d["name"] = "合成の袋"
	d["size_w"] = 2
	d["size_h"] = 2
	return d

static func _mk_furniture() -> Dictionary:
	var d: Dictionary = {}
	d["type"] = "furniture"
	d["name"] = "家具"
	d["size_w"] = 2
	d["size_h"] = 3
	return d
