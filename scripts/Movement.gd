extends Object
class_name Movement

static func is_floor(main: Main, p: Vector2i) -> bool:
	if p.x < 0 or p.x >= Params.W or p.y < 0 or p.y >= Params.H:
		return false
	return ((main.grid[p.y] as Array)[p.x] as int) == 0

static func diagonal_blocked(main: Main, from: Vector2i, dir: Vector2i) -> bool:
	# 斜め移動／攻撃の角判定：隣接する2軸いずれかが壁ならブロック
	if dir.x == 0 or dir.y == 0:
		return false
	var a: Vector2i = from + Vector2i(dir.x, 0)
	var b: Vector2i = from + Vector2i(0, dir.y)
	if not is_floor(main, a):
		return true
	if not is_floor(main, b):
		return true
	return false

static func can_step(main: Main, from: Vector2i, dir: Vector2i) -> bool:
	if dir == Vector2i.ZERO:
		return false
	var to: Vector2i = from + dir
	if dir.x != 0 and dir.y != 0:
		if diagonal_blocked(main, from, dir):
			return false
	if not is_floor(main, to):
		return false
	# 敵がいるタイルには「移動」は不可（攻撃は別処理）
	if main._enemy_at(to) != -1:
		return false
	return true

static func attempt_player_step(main: Main, dir: Vector2i) -> void:
	if dir == Vector2i.ZERO:
		return
	var from: Vector2i = main.player
	var to: Vector2i = from + dir

	# 斜め角抜けは移動も攻撃も不可
	if dir.x != 0 and dir.y != 0 and diagonal_blocked(main, from, dir):
		return

	# 敵がいれば攻撃（1入力=1ターン）
	var ei: int = main._enemy_at(to)
	if ei != -1:
		main._trigger_enemy_hit(ei)
		return

	# 空きなら1歩だけ進む
	if can_step(main, from, dir):
		main.player = to
		main._post_turn_update()
