extends Object
class_name MapGen

static func carve_rooms_and_corridors(
	W: int, H: int, rng_seed: int,
	out_grid: Array, out_room_id: Array, out_rooms: Array[Rect2i]
) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	if rng_seed == 0:
		rng.randomize()
	else:
		rng.seed = int(rng_seed)

	out_grid.clear()
	out_room_id.clear()
	out_rooms.clear()

	for y in H:
		var row: Array[int] = []
		var ridrow: Array[int] = []
		for x in W:
			row.append(1)   # 壁
			ridrow.append(-1) # 非部屋（初期値）
		out_grid.append(row)
		out_room_id.append(ridrow)

	# 部屋を配置
	var room_count: int = 10 + rng.randi_range(0, 6)
	for i in room_count:
		var rw: int = 4 + rng.randi_range(0, 6)
		var rh: int = 4 + rng.randi_range(0, 6)
		var rx: int = rng.randi_range(1, max(1, W - rw - 2))
		var ry: int = rng.randi_range(1, max(1, H - rh - 2))
		var rect: Rect2i = Rect2i(rx, ry, rw, rh)
		var overlaps: bool = false
		for r: Rect2i in out_rooms:
			if r.intersects(rect.grow(1)):
				overlaps = true
				break
		if overlaps:
			continue
		for y2 in range(ry, ry + rh):
			for x2 in range(rx, rx + rw):
				(out_grid[y2] as Array)[x2] = 0
				(out_room_id[y2] as Array)[x2] = out_rooms.size() # 部屋IDを付与
		out_rooms.append(rect)

	# 通路を彫る（★ room_id は上書きしない：部屋と通路が重なったら部屋扱いを維持）
	for i in range(1, out_rooms.size()):
		var a: Vector2i = out_rooms[i - 1].get_center()
		var b: Vector2i = out_rooms[i].get_center()

		# 横通路
		var y0: int = a.y
		var x_min: int = min(a.x, b.x)
		var x_max: int = max(a.x, b.x)
		for x in range(x_min, x_max + 1):
			if x >= 0 and x < W and y0 >= 0 and y0 < H:
				(out_grid[y0] as Array)[x] = 0
				# (out_room_id[y0][x]) は触らない（初期 -1 のままか、部屋なら部屋IDのまま）

		# 縦通路
		var x0: int = b.x
		var y_min: int = min(a.y, b.y)
		var y_max: int = max(a.y, b.y)
		for y2 in range(y_min, y_max + 1):
			if x0 >= 0 and x0 < W and y2 >= 0 and y2 < H:
				(out_grid[y2] as Array)[x0] = 0
				# (out_room_id[y2][x0]) は触らない
