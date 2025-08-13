extends Node
class_name ItemSpawner

# 地面リセット
static func reset_ground(inv: Inventory) -> void:
	inv.ground.clear()

# 各部屋にアイテムをばら撒く
static func scatter_items_in_rooms(main: Main, rng: RandomNumberGenerator, min_per_room: int, max_per_room: int, tries_per_room: int) -> void:
	var rooms: Array = main.rooms
	for i: int in range(rooms.size()):
		var r: Rect2i = rooms[i]
		var n: int = rng.randi_range(min_per_room, max_per_room)
		for j: int in range(n):
			var pos: Vector2i = _random_floor_in_room(main, rng, r, tries_per_room)
			if pos.x == -1:
				continue
			var it: Dictionary = _roll_item(main.inv, rng)
			main.inv.add_item_to_ground(pos, it)

# 敵撃破時ドロップ（確率 chance、ここでは 0.30 を想定）
static func drop_item_with_chance(main: Main, rng: RandomNumberGenerator, pos: Vector2i, chance: float) -> void:
	var roll: float = rng.randf()
	if roll < chance:
		var it: Dictionary = _roll_item(main.inv, rng)
		main.inv.add_item_to_ground(pos, it)

# 部屋内の床セルをランダムに選ぶ
static func _random_floor_in_room(main: Main, rng: RandomNumberGenerator, rect: Rect2i, tries: int) -> Vector2i:
	var count: int = max(1, tries)
	for _k: int in range(count):
		var x: int = rng.randi_range(rect.position.x, rect.position.x + rect.size.x - 1)
		var y: int = rng.randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
		if x < 0 or y < 0 or x >= Params.W or y >= Params.H:
			continue
		var row: Array = main.grid[y]
		if int(row[x]) == 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

# ランダムアイテム生成（家具も出現）
static func _roll_item(inv: Inventory, rng: RandomNumberGenerator) -> Dictionary:
	var p: float = rng.randf()
	# ざっくり配分：家具10%、袋各10%、封印各10%、武器/盾/回復/食料など
	if p < 0.10:
		return inv.create_furniture()
	elif p < 0.20:
		return inv.create_pouch()
	elif p < 0.30:
		return inv.create_fusion_pouch()
	elif p < 0.40:
		return inv.create_enhance_seal()
	elif p < 0.50:
		return inv.create_expand_seal()
	elif p < 0.65:
		return inv.create_wood_sword(0)
	elif p < 0.80:
		return inv.create_wood_shield(0)
	elif p < 0.90:
		return inv.create_onigiri()
	else:
		return inv.create_herb()
