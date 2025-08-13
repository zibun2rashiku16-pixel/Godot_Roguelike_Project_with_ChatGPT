extends Object
class_name EnemyAI

static func enemies_turn(main: Main) -> void:
	for i in range(main.enemies.size() - 1, -1, -1):
		var e: Dictionary = main.enemies[i]
		var ep: Vector2i = e["pos"]

		var dx: int = main.player.x - ep.x
		var dy: int = main.player.y - ep.y
		var adx: int = abs(dx)
		var ady: int = abs(dy)
		var manhattan: int = adx + ady

		# 隣接の攻撃優先
		if manhattan == 0 or manhattan == 1:
			main.combat.enemy_attack(i)
			continue
		# 斜め隣接：角が無い場合は攻撃
		if adx == 1 and ady == 1:
			var sx: int = 0
			if dx > 0:
				sx = 1
			elif dx < 0:
				sx = -1
			var sy: int = 0
			if dy > 0:
				sy = 1
			elif dy < 0:
				sy = -1
			var dir: Vector2i = Vector2i(sx, sy)
			if not Movement.diagonal_blocked(main, ep, dir):
				main.combat.enemy_attack(i)
				continue
			# 角があるなら「横へ回り込み」（X優先→Y）
			var via_x: Vector2i = Vector2i(sx, 0)
			var via_y: Vector2i = Vector2i(0, sy)
			var np_x: Vector2i = ep + via_x
			var np_y: Vector2i = ep + via_y
			var moved: bool = false
			if Movement.can_step(main, ep, via_x) and main._enemy_at(np_x) == -1:
				e["pos"] = np_x
				main.enemies[i] = e
				moved = true
			elif Movement.can_step(main, ep, via_y) and main._enemy_at(np_y) == -1:
				e["pos"] = np_y
				main.enemies[i] = e
				moved = true
			if moved:
				continue
			# 動けないなら通常ロジックへ

		# 通常：距離の大きい軸を優先して 1 歩
		var dir2: Vector2i = _best_dir_towards(ep, main.player)
		var np: Vector2i = ep + dir2
		if Movement.can_step(main, ep, dir2) and main._enemy_at(np) == -1:
			e["pos"] = np
			main.enemies[i] = e

static func _best_dir_towards(from_p: Vector2i, to_p: Vector2i) -> Vector2i:
	var dx: int = to_p.x - from_p.x
	var dy: int = to_p.y - from_p.y
	var sx: int = 0
	if dx > 0:
		sx = 1
	elif dx < 0:
		sx = -1
	var sy: int = 0
	if dy > 0:
		sy = 1
	elif dy < 0:
		sy = -1
	if abs(dx) > abs(dy):
		return Vector2i(sx, 0)
	if abs(dy) > 0:
		return Vector2i(0, sy)
	return Vector2i.ZERO
