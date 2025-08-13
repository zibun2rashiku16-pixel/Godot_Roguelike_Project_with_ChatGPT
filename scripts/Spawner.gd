extends Node
class_name Spawner

var main: Main
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if Params.RNG_SEED == 0:
		rng.randomize()
	else:
		rng.seed = int(Params.RNG_SEED)

func maybe_spawn() -> void:
	if main == null:
		return
	if main.enemies.size() >= Params.SPAWN_MAX:
		return

	var cand: Array[Vector2i] = []
	for y in Params.H:
		for x in Params.W:
			if (main.grid[y] as Array)[x] == 0 and (main.vis_map[y] as Array)[x] == false:
				var p: Vector2i = Vector2i(x, y)
				if p.distance_to(main.player) >= Params.SPAWN_MIN_DIST:
					cand.append(p)
	if cand.is_empty():
		return

	var p: Vector2i = cand[rng.randi_range(0, cand.size() - 1)]

	# ★ 階依存ステータス
	var fl: int = main.floor_level
	var ehp: int = 5 + fl * 2
	var eatk: int = 2 + int(floor(float(fl) * 0.5))

	main.enemies.append({ "pos": p, "hp": ehp, "atk": eatk })
