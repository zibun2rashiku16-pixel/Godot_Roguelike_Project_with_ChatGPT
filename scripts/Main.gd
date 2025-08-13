extends Node
class_name Main

var gfx: Gfx
var ui: UI
var spawner: Spawner
var combat: Combat

var grid: Array = []
var room_id: Array = []
var rooms: Array[Rect2i] = []
var vis_map: Array = []
var explored: Array = []
var enemies: Array[Dictionary] = []

var player: Vector2i = Vector2i.ZERO
var stairs: Vector2i = Vector2i(-1, -1)

var status: Status
var inv: Inventory
var inv_ui: InventoryUI

var floor_level: int = 1
var turn_count: int = 0

var auto_mode: bool = false
var auto_timer: Timer
var auto_pick_furniture_only: bool = false
var auto_ignore_items: bool = false
var auto_nav: AutoNav

var known_item_cells: Dictionary = {}
var known_stairs_seen: bool = false

var rng: RandomNumberGenerator

func _ready() -> void:
	gfx = $Gfx
	ui = $UI
	spawner = $Spawner
	combat = $Combat
	gfx.main = self
	ui.main = self
	spawner.main = self
	combat.main = self

	status = Status.new()
	status.init_defaults()
	add_child(status)
	status.leveled_up.connect(_on_player_leveled_up)

	inv = Inventory.new()
	inv.main = self
	inv.status = status
	add_child(inv)

	inv_ui = InventoryUI.new()
	inv_ui.main = self
	add_child(inv_ui)
	inv_ui.visible = false

	auto_timer = Timer.new()
	auto_timer.one_shot = false
	auto_timer.wait_time = 0.12
	add_child(auto_timer)
	auto_timer.timeout.connect(_on_auto_timer_timeout)

	rng = RandomNumberGenerator.new()
	if Params.RNG_SEED == 0:
		rng.randomize()
	else:
		rng.seed = int(Params.RNG_SEED)

	auto_nav = AutoNav.new()

	_generate()
	FovUtil.update_fov(self)
	ui.update_status()
	gfx.queue_redraw()

func _generate() -> void:
	if inv != null:
		ItemSpawner.reset_ground(inv)
	known_item_cells.clear()
	known_stairs_seen = false

	grid.clear()
	room_id.clear()
	rooms.clear()
	enemies.clear()
	vis_map.clear()
	explored.clear()

	MapGen.carve_rooms_and_corridors(Params.W, Params.H, Params.RNG_SEED, grid, room_id, rooms)

	for y in Params.H:
		var rowv: Array = []
		var rowe: Array = []
		for x in Params.W:
			rowv.append(false)
			rowe.append(false)
		vis_map.append(rowv)
		explored.append(rowe)

	if rooms.size() > 0:
		player = rooms[0].get_center()
	else:
		for y2 in Params.H:
			for x2 in Params.W:
				if (grid[y2] as Array)[x2] == 0:
					player = Vector2i(x2, y2)
					break
			if (grid[player.y] as Array)[player.x] == 0:
				break

	for i in range(1, rooms.size()):
		var p: Vector2i = rooms[i].get_center()
		var fl: int = floor_level
		var ehp: int = 8 + fl * 3
		# ★ 敵ATKを 1 下げる
		var eatk: int = 2 + int(ceil(float(fl) * 0.75))
		enemies.append({ "pos": p, "hp": ehp, "atk": eatk, "xp": 1 })

	if rooms.size() > 1:
		stairs = rooms[rooms.size() - 1].get_center()
	else:
		stairs = player + Vector2i(5, 0)

	if Params.RNG_SEED == 0:
		rng.randomize()
	else:
		rng.seed = int(Params.RNG_SEED + floor_level * 10007)

	ItemSpawner.scatter_items_in_rooms(self, rng, 1, 3, 5)

	auto_nav.reset_for_new_floor()
	# 自動拾い無視フラグはフロア生成時にクリア
	auto_ignore_items = false

func _unhandled_input(event: InputEvent) -> void:
	InputTap.process_unhandled_input(self, event)

func _enemy_at(p: Vector2i) -> int:
	for i in enemies.size():
		var e: Dictionary = enemies[i]
		if e["pos"] == p:
			return i
	return -1

func _post_turn_update() -> void:
	turn_count += 1
	status.apply_turn_effects(turn_count)

	# 自然回復：5ターンごとに最大HPの5%回復（最低1）
	if (turn_count % 5) == 0:
		var heal_f: float = float(status.max_hp) * 0.05
		var heal: int = int(ceil(heal_f))
		if heal < 1:
			heal = 1
		status.hp = min(status.max_hp, status.hp + heal)
		status.stats_changed.emit()

	FovUtil.update_fov(self)
	if (turn_count % Params.SPAWN_TRY_EVERY) == 0:
		spawner.maybe_spawn()
	ui.update_status()
	gfx.queue_redraw()
	EnemyAI.enemies_turn(self)
	ui.update_status()
	gfx.queue_redraw()

func _trigger_enemy_hit(idx: int) -> bool:
	return combat.player_attack(idx)

func try_stairs() -> void:
	if player == stairs:
		floor_level += 1
		_generate()
		FovUtil.update_fov(self)
		ui.update_status()
		gfx.queue_redraw()

func action_wait() -> void:
	_post_turn_update()

func handle_item() -> void:
	inv_ui.toggle()

func set_auto_mode(t: bool) -> void:
	auto_mode = t
	if auto_mode:
		auto_timer.start()
	else:
		auto_timer.stop()
		# ユーザーが自動を解除したら、以降の自動拾い無視を解除
		auto_ignore_items = false

func _on_auto_timer_timeout() -> void:
	if not auto_mode:
		return
	var acted: bool = auto_nav.step(self)
	if not acted:
		auto_mode = false
		auto_timer.stop()

func show_menu_popup() -> void:
	# UI 側でポップアップを表示する実装に移行
	pass

func recalc_memory_visible() -> void:
	MapMemory.remember_objects(self)
	gfx.queue_redraw()

func _on_player_leveled_up(new_level: int) -> void:
	gfx.play_level_up_effect(player)
	ui.update_status()
