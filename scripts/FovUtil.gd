extends Object
class_name FovUtil

static func compute_vis(grid: Array, origin: Vector2i, radius: int) -> Array:
	var H: int = grid.size()
	var W: int = 0
	if H > 0:
		W = (grid[0] as Array).size()
	var vis: Array = []
	for y in H:
		var row: Array[bool] = []
		for x in W:
			row.append(false)
		vis.append(row)
	if H == 0 or W == 0:
		return vis
	var q: Array[Vector2i] = []
	var dist: Dictionary = {}
	q.append(origin)
	dist[origin] = 0
	while q.size() > 0:
		var p: Vector2i = q.pop_front()
		var d: int = int(dist[p])
		if d > radius:
			continue
		if p.y < 0 or p.y >= H or p.x < 0 or p.x >= W:
			continue
		((vis[p.y] as Array))[p.x] = true
		if (grid[p.y] as Array)[p.x] == 1 and d > 0:
			continue
		for dir: Vector2i in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var np: Vector2i = p + dir
			if dist.has(np):
				continue
			dist[np] = d + 1
			q.append(np)
	return vis

static func update_fov(main: Main) -> void:
	var vis: Array = FovUtil.compute_vis(main.grid, main.player, Params.FOV_RADIUS)
	main.vis_map = vis

	# 部屋にいるときは「部屋全体」を可視＋外周1マスの壁も可視
	if main.player.y >= 0 and main.player.y < Params.H and main.player.x >= 0 and main.player.x < Params.W:
		var rid_row: Array = main.room_id[main.player.y]
		var rid: int = int(rid_row[main.player.x])
		if rid >= 0 and rid < main.rooms.size():
			var r: Rect2i = main.rooms[rid]
			for yy in range(r.position.y, r.position.y + r.size.y):
				if yy < 0 or yy >= Params.H:
					continue
				var rowv: Array = main.vis_map[yy]
				for xx in range(r.position.x, r.position.x + r.size.x):
					if xx < 0 or xx >= Params.W:
						continue
					rowv[xx] = true
			var y0: int = r.position.y - 1
			var y1: int = r.position.y + r.size.y
			var x0: int = r.position.x - 1
			var x1: int = r.position.x + r.size.x
			for yy2 in range(y0, y1 + 1):
				if yy2 < 0 or yy2 >= Params.H:
					continue
				var rowv2: Array = main.vis_map[yy2]
				for xx2 in range(x0, x1 + 1):
					if xx2 < 0 or xx2 >= Params.W:
						continue
					var inside_room: bool = (xx2 >= r.position.x and xx2 < r.position.x + r.size.x and yy2 >= r.position.y and yy2 < r.position.y + r.size.y)
					if inside_room:
						continue
					if (main.grid[yy2] as Array)[xx2] == 1:
						rowv2[xx2] = true

	# 探索済み更新
	MapMemory.remember_visible(main.vis_map, main.explored)
	# ★ アイテム／階段の記憶も更新
	MapMemory.remember_objects(main)
