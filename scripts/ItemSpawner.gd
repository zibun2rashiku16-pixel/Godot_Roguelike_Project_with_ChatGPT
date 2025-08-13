extends Object
class_name ItemSpawner

static func reset_ground(inv: Inventory) -> void:
	if inv != null:
		inv.ground.clear()

static func _is_cell_free(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.x >= Params.W or p.y < 0 or p.y >= Params.H:
		return false
	if (main.grid[p.y] as Array)[p.x] == 1:
		return false
	if p == main.player or p == main.stairs:
		return false
	for e in main.enemies:
		var ep: Vector2i = e["pos"]
		if ep == p:
			return false
	return true

static func scatter_items_in_rooms(
	main: Main,
	rng: RandomNumberGenerator,
	per_room_min: int,
	per_room_max: int,
	ensure_total_min: int
) -> void:
	if main.inv == null:
		return

	var total: int = 0
	for i: int in main.rooms.size():
		var r: Rect2i = main.rooms[i]
		var count: int = rng.randi_range(per_room_min, per_room_max)
		for _j: int in count:
			var tries: int = 48
			var placed: bool = false
			while tries > 0 and not placed:
				var x: int = rng.randi_range(r.position.x, r.position.x + r.size.x - 1)
				var y: int = rng.randi_range(r.position.y, r.position.y + r.size.y - 1)
				tries -= 1
				if y < 0 or y >= Params.H or x < 0 or x >= Params.W:
					continue
				var rid_row: Array = main.room_id[y]
				if int(rid_row[x]) < 0:
					continue
				var p: Vector2i = Vector2i(x, y)
				if not ItemSpawner._is_cell_free(main, p):
					continue

				# 配分（合計100%）
				#  0-13 : 薬草 (14%)
				# 14-27 : おにぎり (14%)
				# 28-39 : 木の剣 (12%)
				# 40-47 : 木の盾 (8%)
				# 48-65 : 袋 (18%)
				# 66-83 : 強化のシール (18%)
				# 84-93 : 拡張のシール (10%)
				# 94-99 : 合成の袋 (6%)
				var roll: int = rng.randi_range(0, 99)
				var it: Dictionary = {}
				if roll < 14:
					it = main.inv.create_herb()
				elif roll < 28:
					it = main.inv.create_onigiri()
				elif roll < 40:
					it = main.inv.create_wood_sword(rng.randi_range(0, 2))
				elif roll < 48:
					it = main.inv.create_wood_shield(rng.randi_range(0, 2))
				elif roll < 66:
					it = main.inv.create_pouch()
				elif roll < 84:
					it = main.inv.create_enhance_seal()
				elif roll < 94:
					it = main.inv.create_expand_seal()
				else:
					it = main.inv.create_fusion_pouch()

				main.inv.add_item_to_ground(p, it)
				total += 1
				placed = true

	if total < ensure_total_min and main.rooms.size() > 0:
		var need: int = ensure_total_min - total
		var r0: Rect2i = main.rooms[0]
		for k: int in need:
			var x2: int = clamp(r0.get_center().x + ((k % 3) - 1), 0, Params.W - 1)
			var y2: int = clamp(r0.get_center().y + int(k / 3) - 1, 0, Params.H - 1)
			var p2: Vector2i = Vector2i(x2, y2)
			if ItemSpawner._is_cell_free(main, p2):
				main.inv.add_item_to_ground(p2, main.inv.create_herb())

# ★ 追加：敵撃破時ドロップ
static func drop_from_enemy(main: Main, rng: RandomNumberGenerator, pos: Vector2i) -> void:
	# 低確率（10%）でドロップ
	var r: RandomNumberGenerator = rng
	if r == null:
		r = RandomNumberGenerator.new()
		r.randomize()
	var chance: int = r.randi_range(0, 99)
	if chance >= 10:
		return

	# ドロップ内容（軽め寄り）
	#  0-39 : 薬草 (40%)
	# 40-64 : おにぎり (25%)
	# 65-79 : 強化のシール (15%)
	# 80-89 : 袋 (10%)
	# 90-95 : 拡張のシール (6%)
	# 96-99 : 合成の袋 (4%)
	var roll: int = r.randi_range(0, 99)
	var it: Dictionary = {}
	if roll < 40:
		it = main.inv.create_herb()
	elif roll < 65:
		it = main.inv.create_onigiri()
	elif roll < 80:
		it = main.inv.create_enhance_seal()
	elif roll < 90:
		it = main.inv.create_pouch()
	elif roll < 96:
		it = main.inv.create_expand_seal()
	else:
		it = main.inv.create_fusion_pouch()

	main.inv.add_item_to_ground(pos, it)
