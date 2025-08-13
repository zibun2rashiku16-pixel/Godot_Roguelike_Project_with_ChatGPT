extends Node
class_name AutoNav

var last_dir: Vector2i = Vector2i.ZERO
var visited: Dictionary = {}

func reset_for_new_floor() -> void:
	last_dir = Vector2i.ZERO
	visited.clear()

func _key(p: Vector2i) -> String:
	return str(p.x) + "," + str(p.y)

func _mark_visited(p: Vector2i) -> void:
	visited[_key(p)] = true

func _is_walkable(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return false
	var row: Array = main.grid[p.y]
	return int(row[p.x]) == 0

func _dirs4() -> Array:
	var a: Array = [
		Vector2i(0, -1), Vector2i(1, 0),
		Vector2i(0, 1), Vector2i(-1, 0)
	]
	return a

func _dirs8() -> Array:
	var a: Array = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                    Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]
	return a

func _adjacent_enemy_indices(main: Main, p: Vector2i) -> Array:
	var out: Array = []
	for d: Vector2i in _dirs8():
		var q: Vector2i = p + d
		var idx: int = main._enemy_at(q)
		if idx >= 0:
			out.append(idx)
	return out

func _room_id_at(main: Main, p: Vector2i) -> int:
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return -1
	var row: Array = main.room_id[p.y]
	return int(row[p.x])

func _walkable_dirs4(main: Main, p: Vector2i) -> Array:
	var res: Array = []
	for d: Vector2i in _dirs4():
		if Movement.can_step(main, p, d):
			res.append(d)
	return res

func _has_items_in_room(main: Main, rid: int) -> bool:
	var keys: Array = main.inv.ground.keys()
	for cell: Variant in keys:
		var v: Vector2i = cell
		var r: int = _room_id_at(main, v)
		if r == rid:
			return true
	return false

func _stairs_in_room(main: Main, rid: int) -> bool:
	var s: Vector2i = main.stairs
	if s.x < 0:
		return false
	return _room_id_at(main, s) == rid

func _nearest_target_dir(main: Main, target: Vector2i) -> Vector2i:
	return EnemyAI._best_dir_towards(main.player, target)

func _choose_exit_to_unvisited_corridor(main: Main, p: Vector2i) -> Vector2i:
	var rid_here: int = _room_id_at(main, p)
	for d: Vector2i in _dirs4():
		var q: Vector2i = p + d
		if not _is_walkable(main, q):
			continue
		var rid_q: int = _room_id_at(main, q)
		if rid_q != rid_here:
			var key: String = _key(q)
			if not visited.has(key):
				return d
	for d2: Vector2i in _dirs4():
		var q2: Vector2i = p + d2
		if not _is_walkable(main, q2):
			continue
		var rid_q2: int = _room_id_at(main, q2)
		if rid_q2 != rid_here:
			return d2
	return Vector2i.ZERO

func _choose_dir_in_corridor(main: Main, p: Vector2i) -> Vector2i:
	var opts: Array = _walkable_dirs4(main, p)
	if opts.is_empty():
		return Vector2i.ZERO
	var back: Vector2i = Vector2i(-last_dir.x, -last_dir.y)
	# 直進を最優先
	if last_dir != Vector2i.ZERO:
		for d0: Vector2i in opts:
			if d0 == last_dir:
				return d0
	# 直進不可：分岐なら「逆方向以外」をランダム
	var cand: Array = []
	for d1: Vector2i in opts:
		if d1 != back:
			cand.append(d1)
	if cand.size() > 0:
		var idx: int = 0
		if main.rng != null:
			idx = main.rng.randi_range(0, cand.size() - 1)
		var choice: Vector2i = cand[idx]
		return choice
	# 仕方なく戻る
	return back

func _auto_pick_here(main: Main) -> bool:
	# 自動拾いを無視するフラグ
	if main.auto_ignore_items:
		return false
	var pos: Vector2i = main.player
	var items: Array = main.inv.get_ground_items_at(pos)
	if items.is_empty():
		return false
	var only_furn: bool = main.auto_pick_furniture_only
	if only_furn:
		for it: Variant in items:
			var d: Dictionary = it
			var t: String = String(d.get("type", ""))
			if t != "furniture":
				continue
			var iid: int = int(d.get("id", -1))
			if iid < 0:
				continue
			var picked: Dictionary = main.inv.take_item_from_ground(pos, iid)
			if picked.is_empty():
				continue
			var ok_put: bool = main.inv.place_item_in_bag(picked)
			if not ok_put:
				# 入らない → 以降は自動解除までアイテム無視
				main.inv.add_item_to_ground(pos, picked)
				main.auto_ignore_items = true
				return false
			main._post_turn_update()
			return true
		return false
	# 通常：トップを拾う。失敗したらフラグを立てて以降無視。
	var ok_top: bool = main.inv.pickup_ground_item(pos)
	if ok_top:
		main._post_turn_update()
		return true
	main.auto_ignore_items = true
	return false

func step(main: Main) -> bool:
	var p: Vector2i = main.player
	_mark_visited(p)

	# 1) 隣接（8方向）に敵がいれば攻撃（1体）
	var adj: Array = _adjacent_enemy_indices(main, p)
	if adj.size() > 0:
		var idx: int = int(adj[0])
		var acted_hit: bool = main._trigger_enemy_hit(idx)
		if acted_hit:
			main._post_turn_update()
			return true

	# 2) 足元のアイテムを自動取得
	if _auto_pick_here(main):
		return true

	# 3) 階段に乗っていれば次フロアへ
	if p == main.stairs:
		main.try_stairs()
		return true

	# 4) 移動
	var rid: int = _room_id_at(main, p)

	# 4-1) 通路（部屋IDが -1）では分岐に対応：直進優先、なければランダム、最後に後退
	if rid < 0:
		var d_corr: Vector2i = _choose_dir_in_corridor(main, p)
		if d_corr != Vector2i.ZERO and Movement.can_step(main, p, d_corr):
			last_dir = d_corr
			Movement.attempt_player_step(main, d_corr)
			return true

	# 4-2) 部屋：アイテム／階段を優先、無ければ未訪問の出口へ
	if rid >= 0:
		var keys: Array = main.inv.ground.keys()
		for cell: Variant in keys:
			var v: Vector2i = cell
			if _room_id_at(main, v) == rid:
				var dir_to_item: Vector2i = _nearest_target_dir(main, v)
				if dir_to_item != Vector2i.ZERO and Movement.can_step(main, p, dir_to_item):
					last_dir = dir_to_item
					Movement.attempt_player_step(main, dir_to_item)
					return true
		if _stairs_in_room(main, rid):
			var dir_to_stairs: Vector2i = _nearest_target_dir(main, main.stairs)
			if dir_to_stairs != Vector2i.ZERO and Movement.can_step(main, p, dir_to_stairs):
				last_dir = dir_to_stairs
				Movement.attempt_player_step(main, dir_to_stairs)
				return true
		var ex: Vector2i = _choose_exit_to_unvisited_corridor(main, p)
		if ex != Vector2i.ZERO and Movement.can_step(main, p, ex):
			last_dir = ex
			Movement.attempt_player_step(main, ex)
			return true

	# 4-3) フォールバック：階段方向へ
	var dflt: Vector2i = _nearest_target_dir(main, main.stairs)
	if dflt != Vector2i.ZERO and Movement.can_step(main, p, dflt):
		last_dir = dflt
		Movement.attempt_player_step(main, dflt)
		return true

	return false
