extends Node
class_name AutoNav

const DOOR_CD_TURNS: int = 6
const PAIR_CD_TURNS: int = 8
const EXIT_ITEM_PENALTY: int = 5
const HUNGER_EAT_THRESHOLD: int = 20

var last_dir: Vector2i = Vector2i.ZERO
var visited: Dictionary = {}
var door_cd: Dictionary = {}
var room_pair_cd: Dictionary = {}
var last_pos: Vector2i = Vector2i(-999, -999)
var last_room_id: int = -2
var prev_room_id: int = -2

var avoid_room_id: int = -1
var avoid_room_left: int = 0

func reset_for_new_floor() -> void:
	last_dir = Vector2i.ZERO
	visited.clear()
	door_cd.clear()
	room_pair_cd.clear()
	last_pos = Vector2i(-999, -999)
	last_room_id = -2
	prev_room_id = -2
	avoid_room_id = -1
	avoid_room_left = 0

func _key(p: Vector2i) -> String:
	return str(p.x) + "," + str(p.y)

func _pair_key(a: int, b: int) -> String:
	return str(a) + ">" + str(b)

func _cooldown(a: int, b: int) -> int:
	var k: String = _pair_key(a, b)
	if door_cd.has(k):
		return int(door_cd[k])
	return 0

func _arm_cooldown(a: int, b: int) -> void:
	var k: String = _pair_key(a, b)
	door_cd[k] = DOOR_CD_TURNS

func _pair_cd(a: int, b: int) -> int:
	var k: String = _pair_key(a, b)
	if room_pair_cd.has(k):
		return int(room_pair_cd[k])
	return 0

func _arm_pair_cd(a: int, b: int) -> void:
	var k1: String = _pair_key(a, b)
	var k2: String = _pair_key(b, a)
	room_pair_cd[k1] = PAIR_CD_TURNS
	room_pair_cd[k2] = PAIR_CD_TURNS

func _tick_cooldowns() -> void:
	var keys1: Array = door_cd.keys()
	for k1: Variant in keys1:
		var s1: String = String(k1)
		var v1: int = int(door_cd[s1])
		v1 -= 1
		if v1 <= 0:
			door_cd.erase(s1)
		else:
			door_cd[s1] = v1
	var keys2: Array = room_pair_cd.keys()
	for k2: Variant in keys2:
		var s2: String = String(k2)
		var v2: int = int(room_pair_cd[s2])
		v2 -= 1
		if v2 <= 0:
			room_pair_cd.erase(s2)
		else:
			room_pair_cd[s2] = v2
	if avoid_room_left > 0:
		avoid_room_left -= 1
		if avoid_room_left <= 0:
			avoid_room_id = -1
			avoid_room_left = 0

func _set_avoid_room(rid: int) -> void:
	avoid_room_id = rid
	avoid_room_left = DOOR_CD_TURNS

func _mark_visited(p: Vector2i) -> void:
	visited[_key(p)] = true

func _update_room_history(main: Main) -> void:
	var rid_now: int = _room_id_at(main, main.player)
	if rid_now != last_room_id:
		prev_room_id = last_room_id
		last_room_id = rid_now
	last_pos = main.player

func _is_walkable(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return false
	var row: Array = main.grid[p.y]
	return int(row[p.x]) == 0

func _is_explored(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return true
	var row: Array = main.explored[p.y]
	return bool(row[p.x])

func _is_frontier(main: Main, p: Vector2i) -> bool:
	if not _is_walkable(main, p):
		return false
	return not _is_explored(main, p)

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
	for d: Variant in _dirs8():
		var v: Vector2i = d
		var q: Vector2i = p + v
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
	for d: Variant in _dirs4():
		var v: Vector2i = d
		if Movement.can_step(main, p, v):
			res.append(v)
	return res

func _has_items_at(main: Main, cell: Vector2i) -> bool:
	var arr: Array = main.inv.get_ground_items_at(cell)
	return not arr.is_empty()

func _cell_has_pickable_item(main: Main, cell: Vector2i) -> bool:
	if main.auto_ignore_items:
		return false
	var items: Array = main.inv.get_ground_items_at(cell)
	if items.is_empty():
		return false
	if main.auto_pick_furniture_only:
		for it: Variant in items:
			var d: Dictionary = it
			var t: String = String(d.get("type", ""))
			if t == "furniture":
				return true
		return false
	return true

func _nearest_target_dir(main: Main, target: Vector2i) -> Vector2i:
	return EnemyAI._best_dir_towards(main.player, target)

func _room_exit_cells(main: Main, rid: int) -> Array:
	var out: Array = []
	if rid < 0 or rid >= main.rooms.size():
		return out
	var rect: Rect2i = main.rooms[rid]
	var seen: Dictionary = {}
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		var yy: int = int(y)
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			var xx: int = int(x)
			var q: Vector2i = Vector2i(xx, yy)
			if not _is_walkable(main, q):
				continue
			for d: Variant in _dirs4():
				var v: Vector2i = d
				var n: Vector2i = q + v
				if not _is_walkable(main, n):
					continue
				if _room_id_at(main, n) != rid:
					var k: String = _key(q)
					if not seen.has(k):
						out.append(q)
						seen[k] = true
					break
	return out

func _exit_out_dir(main: Main, rid: int, ex: Vector2i) -> Vector2i:
	for d: Variant in _dirs4():
		var v: Vector2i = d
		var outp: Vector2i = ex + v
		if not _is_walkable(main, outp):
			continue
		if _room_id_at(main, outp) != rid:
			return v
	return Vector2i.ZERO

func _other_room_from_outside(main: Main, rid_here: int, outside: Vector2i) -> int:
	for d: Variant in _dirs4():
		var v: Vector2i = d
		var n: Vector2i = outside + v
		var rn: int = _room_id_at(main, n)
		if rn >= 0 and rn != rid_here:
			return rn
	return -1

func _room_has_objectives(main: Main, rid: int) -> bool:
	if rid < 0:
		return false
	var keys: Array = main.inv.ground.keys()
	for cell: Variant in keys:
		var c: Vector2i = cell
		if _room_id_at(main, c) == rid:
			return true
	if _room_id_at(main, main.stairs) == rid:
		return true
	return false

func _choose_exit_with_out_dir(main: Main, p: Vector2i, rid: int) -> Dictionary:
	var exits: Array = _room_exit_cells(main, rid)
	if exits.is_empty():
		return {}
	var best: Dictionary = {}
	var best_score: int = 1_000_000
	for ex: Variant in exits:
		var epos: Vector2i = ex
		var dir_to_exit: Vector2i = Vector2i.ZERO
		if epos != p:
			dir_to_exit = _nearest_target_dir(main, epos)
		var out_dir: Vector2i = _exit_out_dir(main, rid, epos)
		if out_dir == Vector2i.ZERO:
			continue
		var outside: Vector2i = epos + out_dir
		var rid_other: int = _other_room_from_outside(main, rid, outside)

		var prefer_unvisited: bool = not visited.has(_key(outside))
		var dist: int = abs(epos.x - p.x) + abs(epos.y - p.y)
		var score: int = dist
		if not prefer_unvisited:
			score += 3
		if rid_other == prev_room_id and prev_room_id != -2:
			score += 12
		if rid_other >= 0:
			var cdp: int = _pair_cd(rid, rid_other)
			if cdp > 0:
				score += cdp * 2
		var cd: int = _cooldown(rid, -1)
		if cd > 0:
			score += cd
		if main.auto_ignore_items:
			if _has_items_at(main, epos):
				score += EXIT_ITEM_PENALTY
			if _has_items_at(main, outside):
				score += EXIT_ITEM_PENALTY
		if rid_other >= 0 and not _room_has_objectives(main, rid_other):
			score += 3
		if avoid_room_left > 0 and rid == avoid_room_id:
			score += 8

		if score < best_score:
			best_score = score
			best = {
				"exit": epos,
				"dir_to_exit": dir_to_exit,
				"out_dir": out_dir,
				"outside": outside,
				"rid_other": rid_other
			}
	return best

func _score_corridor_dir(main: Main, p: Vector2i, dir: Vector2i) -> int:
	var q: Vector2i = p + dir
	var s: int = 0
	if dir == last_dir:
		s -= 3
	if not visited.has(_key(q)):
		s -= 2
	var rid_tgt: int = _room_id_at(main, q)
	if avoid_room_left > 0 and rid_tgt == avoid_room_id and rid_tgt >= 0:
		s += 6
	if last_room_id >= 0 and rid_tgt >= 0:
		var cdp: int = _pair_cd(last_room_id, rid_tgt)
		if cdp > 0:
			s += 8
	return s

func _choose_dir_in_corridor(main: Main, p: Vector2i) -> Vector2i:
	var opts: Array = _walkable_dirs4(main, p)
	if opts.is_empty():
		return Vector2i.ZERO
	var best_dir: Vector2i = Vector2i.ZERO
	var best_score: int = 1_000_000
	for d: Variant in opts:
		var v: Vector2i = d
		var sc: int = _score_corridor_dir(main, p, v)
		if sc < best_score:
			best_score = sc
			best_dir = v
	return best_dir

# --- グローバル探索：未踏破（未explored）へ最短路で向かう ---
func _bfs_next_dir_to_frontier(main: Main, start: Vector2i) -> Vector2i:
	var q: Array = []
	var used: Dictionary = {}
	var came: Dictionary = {}
	var qi: int = 0
	var found: bool = false
	var goal: Vector2i = start

	q.append(start)
	used[_key(start)] = true

	while qi < q.size():
		var cur: Vector2i = q[qi]
		qi += 1

		if _is_frontier(main, cur):
			found = true
			goal = cur
			break

		for d: Variant in _dirs4():
			var v: Vector2i = d
			var nxt: Vector2i = cur + v
			if not _is_walkable(main, nxt):
				continue
			var k: String = _key(nxt)
			if used.has(k):
				continue
			used[k] = true
			came[k] = cur
			q.append(nxt)

	if not found:
		return Vector2i.ZERO

	var cur2: Vector2i = goal
	var prev: Vector2i = start
	while true:
		if cur2 == start:
			break
		var k2: String = _key(cur2)
		if not came.has(k2):
			break
		prev = Vector2i(came[k2])
		if prev == start:
			var step: Vector2i = cur2 - start
			return Vector2i(step.x, step.y)
		cur2 = prev

	return Vector2i.ZERO

# --- 空腹時の自動食事（Inventory 側に用意があれば呼び出し） ---
func _auto_consume_if_hungry(main: Main) -> bool:
	if main.status == null:
		return false
	if main.status.belly > HUNGER_EAT_THRESHOLD:
		return false
	if main.inv == null:
		return false
	var did: bool = false
	# 既存実装に寄り添って順に呼び分け（存在確認してから呼ぶ）
	if main.inv.has_method("auto_consume_food_if_needed"):
		did = bool(main.inv.auto_consume_food_if_needed(HUNGER_EAT_THRESHOLD))
	elif main.inv.has_method("auto_consume_food"):
		did = bool(main.inv.auto_consume_food())
	elif main.inv.has_method("consume_food_auto"):
		did = bool(main.inv.consume_food_auto())
	elif main.inv.has_method("use_food_auto"):
		did = bool(main.inv.use_food_auto())
	elif main.inv.has_method("use_first_food"):
		did = bool(main.inv.use_first_food())
	if did:
		main._post_turn_update()
		return true
	return false

func _auto_pick_here(main: Main) -> bool:
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
				main.inv.add_item_to_ground(pos, picked)
				main.auto_ignore_items = true
				return false
			main._post_turn_update()
			return true
		return false
	var ok_top: bool = main.inv.pickup_ground_item(pos)
	if ok_top:
		main._post_turn_update()
		return true
	main.auto_ignore_items = true
	return false

func step(main: Main) -> bool:
	_tick_cooldowns()
	_update_room_history(main)

	var p: Vector2i = main.player
	_mark_visited(p)

	# 0) 空腹チェック：腹が閾値以下なら食料を自動使用
	if _auto_consume_if_hungry(main):
		return true

	# 1) 戦闘
	var adj: Array = _adjacent_enemy_indices(main, p)
	if adj.size() > 0:
		var idx: int = int(adj[0])
		var acted_hit: bool = main._trigger_enemy_hit(idx)
		if acted_hit:
			main._post_turn_update()
			return true

	# 2) 足元のアイテム
	if _auto_pick_here(main):
		return true

	# 3) 階段
	if p == main.stairs:
		main.try_stairs()
		return true

	# 4) 未踏破（未explored）へ最短路で向かう
	var dir_frontier: Vector2i = _bfs_next_dir_to_frontier(main, p)
	if dir_frontier != Vector2i.ZERO and Movement.can_step(main, p, dir_frontier):
		var dest: Vector2i = p + dir_frontier
		var rid_from: int = _room_id_at(main, p)
		var rid_to: int = _room_id_at(main, dest)
		if rid_from >= 0 and rid_to >= 0:
			_arm_pair_cd(rid_from, rid_to)
		last_dir = dir_frontier
		Movement.attempt_player_step(main, dir_frontier)
		return true

	# 5) ローカル指向（通路・部屋の既存ヒューリスティクス）
	var rid: int = _room_id_at(main, p)

	if rid < 0:
		var d_corr: Vector2i = _choose_dir_in_corridor(main, p)
		if d_corr != Vector2i.ZERO and Movement.can_step(main, p, d_corr):
			var dest2: Vector2i = p + d_corr
			var rid_tgt: int = _room_id_at(main, dest2)
			if last_room_id >= 0 and rid_tgt >= 0:
				_arm_pair_cd(last_room_id, rid_tgt)
			last_dir = d_corr
			Movement.attempt_player_step(main, d_corr)
			return true

	if rid >= 0 and not main.auto_ignore_items:
		var keys: Array = main.inv.ground.keys()
		for cell: Variant in keys:
			var vcell: Vector2i = cell
			if _room_id_at(main, vcell) == rid:
				if not _cell_has_pickable_item(main, vcell):
					continue
				var dir_to_item: Vector2i = _nearest_target_dir(main, vcell)
				if dir_to_item != Vector2i.ZERO and Movement.can_step(main, p, dir_to_item):
					last_dir = dir_to_item
					Movement.attempt_player_step(main, dir_to_item)
					return true

	if rid >= 0 and _room_id_at(main, main.stairs) == rid:
		var dir_to_stairs: Vector2i = _nearest_target_dir(main, main.stairs)
		if dir_to_stairs != Vector2i.ZERO and Movement.can_step(main, p, dir_to_stairs):
			last_dir = dir_to_stairs
			Movement.attempt_player_step(main, dir_to_stairs)
			return true

	if rid >= 0:
		var ex: Dictionary = _choose_exit_with_out_dir(main, p, rid)
		if not ex.is_empty():
			var dir_to_exit: Vector2i = ex["dir_to_exit"]
			var out_dir: Vector2i = ex["out_dir"]
			var rid_other: int = int(ex["rid_other"])
			if dir_to_exit != Vector2i.ZERO and Movement.can_step(main, p, dir_to_exit):
				last_dir = dir_to_exit
				Movement.attempt_player_step(main, dir_to_exit)
				return true
			if out_dir != Vector2i.ZERO and Movement.can_step(main, p, out_dir):
				_arm_cooldown(rid, -1)
				if rid_other >= 0:
					_arm_pair_cd(rid, rid_other)
				_set_avoid_room(rid)
				last_dir = out_dir
				Movement.attempt_player_step(main, out_dir)
				return true

	# 6) フォールバック：階段方向
	var dflt: Vector2i = _nearest_target_dir(main, main.stairs)
	if dflt != Vector2i.ZERO and Movement.can_step(main, p, dflt):
		last_dir = dflt
		Movement.attempt_player_step(main, dflt)
		return true

	return false
