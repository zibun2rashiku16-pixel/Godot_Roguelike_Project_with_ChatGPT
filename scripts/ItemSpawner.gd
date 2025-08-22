extends Node
class_name ItemSpawner

# 床落ち生成で id が未設定のまま ground に置かれる事故を防ぐためのフォールバック連番
static var _fallback_id_seq: int = 1000000

static func reset_ground(inv: Inventory) -> void:
	# ground マップを初期化
	if inv == null:
		return
	if inv.ground == null:
		inv.ground = {}
	else:
		inv.ground.clear()

static func scatter_items_in_rooms(main: Main, rng: RandomNumberGenerator, min_per_room: int, max_per_room: int, extra: int) -> void:
	# 各部屋にアイテムをばらまく（床落ち生成）
	if main == null:
		return
	if main.inv == null:
		return
	var rr: RandomNumberGenerator = rng
	if rr == null:
		rr = RandomNumberGenerator.new()
		rr.randomize()

	# ★ 1F限定：プレイヤー足元に「識別済みの薬草」を2個
	if int(main.floor_level) == 1:
		_place_initial_herbs_on_foot(main)

	# 以降：従来の散布（簡易）
	var rooms: Array = main.rooms
	for i: int in rooms.size():
		var rect: Rect2i = rooms[i]
		var n: int = rr.randi_range(min_per_room, max_per_room)
		for k: int in n:
			var pos: Vector2i = _random_point_in_room(main, rr, rect)
			if pos.x < 0:
				continue
			var it: Dictionary = _roll_item(main.inv, rr)
			_add_to_ground_with_id(main, pos, it)

	# 部屋外にも追加で散布
	for m: int in extra:
		var pos2: Vector2i = _random_floor_anywhere(main, rr)
		if pos2.x < 0:
			continue
		var it2: Dictionary = _roll_item(main.inv, rr)
		_add_to_ground_with_id(main, pos2, it2)

static func drop_item_with_chance(main: Main, pos: Vector2i, rng: RandomNumberGenerator, chance: float = 0.30) -> void:
	# 確率で床に戦利品を落とす
	if main == null:
		return
	if main.inv == null:
		return
	var rr: RandomNumberGenerator = rng
	if rr == null:
		rr = RandomNumberGenerator.new()
		rr.randomize()
	var ch: float = chance
	if ch > 1.0:
		ch = ch * 0.01
	if ch <= 0.0:
		return
	if rr.randf() < ch:
		var it: Dictionary = _roll_item(main.inv, rr)
		_add_to_ground_with_id(main, pos, it)

static func drop_loot(main: Main, pos: Vector2i, rng: RandomNumberGenerator) -> void:
	# デフォルト戦利品（30%）
	drop_item_with_chance(main, pos, rng, 0.30)

# --- 内部ヘルパー ---

# 足元に薬草×2。Dictionary は毎回新規生成して ID 競合を回避
static func _place_initial_herbs_on_foot(main: Main) -> void:
	var p: Vector2i = main.player
	var a: Dictionary = _mk_herb(main.inv)
	var b: Dictionary = _mk_herb(main.inv)
	# チュートリアル用に識別済みフラグを付与
	a["identified"] = true
	b["identified"] = true
	_add_to_ground_with_id(main, p, a)
	_add_to_ground_with_id(main, p, b)

# ground 追加時に id を必ず保証してから追加する
static func _add_to_ground_with_id(main: Main, pos: Vector2i, item: Dictionary) -> void:
	if main == null:
		return
	if main.inv == null:
		return
	_ensure_item_id(main.inv, item)  # 既に付いていれば何もしない
	# 正式API経由で地面に追加
	main.inv.add_item_to_ground(pos, item)

# item に id が無い/無効の場合に採番して付与する
static func _ensure_item_id(inv: Inventory, d: Dictionary) -> void:
	var has_id: bool = d.has("id")
	var idv: int = -1
	if has_id:
		idv = int(d.get("id", -1))
	if idv >= 0:
		return
	# Inventory に採番APIがあればそれを使う
	var issued: int = -1
	if inv != null:
		if inv.has_method("issue_item_id"):
			issued = int(inv.call("issue_item_id"))
		elif inv.has_method("alloc_item_id"):
			issued = int(inv.call("alloc_item_id"))
	# フォールバック：ローカル連番（衝突しにくい高番から）
	if issued < 0:
		issued = _fallback_id_seq
		_fallback_id_seq += 1
	d["id"] = issued

static func _is_floor(main: Main, p: Vector2i) -> bool:
	# マップ境界内かつ床タイル（0）かどうか
	if p.x < 0 or p.y < 0 or p.x >= Params.W or p.y >= Params.H:
		return false
	var row: Array = main.grid[p.y]
	return int(row[p.x]) == 0

# --- ここから生成系：ファクトリに統一（効果量 heal/belly を必ず付与） ---

static func _compat_add_size_wh(d: Dictionary) -> void:
	# 互換用：Factory は "size" を必ず持つ。旧コードが参照する "size_w/h" を補完。
	var sz: Vector2i = Vector2i(1, 1)
	if d.has("size"):
		sz = Vector2i(d["size"])
	if not d.has("size_w"):
		d["size_w"] = int(sz.x)
	if not d.has("size_h"):
		d["size_h"] = int(sz.y)

static func _mk_herb(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_herb(inv)  # heal を内包
	_compat_add_size_wh(d)
	return d

static func _mk_food(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_onigiri(inv)  # belly を内包
	_compat_add_size_wh(d)
	return d

static func _mk_weapon(inv: Inventory, rng: RandomNumberGenerator) -> Dictionary:
	# 木の剣（1x3）、+0～+2
	var plus: int = rng.randi_range(0, 2)
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_wood_sword(inv, plus)
	_compat_add_size_wh(d)
	return d

static func _mk_shield(inv: Inventory, rng: RandomNumberGenerator) -> Dictionary:
	# 木の盾（2x2）、+0～+2
	var plus: int = rng.randi_range(0, 2)
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_wood_shield(inv, plus)
	_compat_add_size_wh(d)
	return d

static func _mk_seal(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_enhance_seal(inv)
	_compat_add_size_wh(d)
	return d

static func _mk_seal_expand(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_expand_seal(inv)
	_compat_add_size_wh(d)
	return d

static func _mk_pouch(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_pouch(inv)  # pouch_w/h を内包
	_compat_add_size_wh(d)
	return d

static func _mk_pouch_fusion(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_fusion_pouch(inv)  # pouch_w/h を内包
	_compat_add_size_wh(d)
	return d

static func _mk_furniture(inv: Inventory) -> Dictionary:
	var fac: ItemFactory = ItemFactory.new()
	var d: Dictionary = fac.create_furniture(inv)
	_compat_add_size_wh(d)
	return d

static func _random_point_in_room(main: Main, rng: RandomNumberGenerator, rect: Rect2i) -> Vector2i:
	# 部屋矩形内の床をランダムに探索
	var tries: int = 32
	while tries > 0:
		tries -= 1
		var x: int = rng.randi_range(rect.position.x, rect.position.x + rect.size.x - 1)
		var y: int = rng.randi_range(rect.position.y, rect.position.y + rect.size.y - 1)
		var p: Vector2i = Vector2i(x, y)
		if _is_floor(main, p):
			return p
	return Vector2i(-1, -1)

static func _random_floor_anywhere(main: Main, rng: RandomNumberGenerator) -> Vector2i:
	# マップ全体から床をランダムに探索
	var tries: int = 64
	while tries > 0:
		tries -= 1
		var x: int = rng.randi_range(0, Params.W - 1)
		var y: int = rng.randi_range(0, Params.H - 1)
		var p: Vector2i = Vector2i(x, y)
		if _is_floor(main, p):
			return p
	return Vector2i(-1, -1)

static func _roll_item(inv: Inventory, rng: RandomNumberGenerator) -> Dictionary:
	# ざっくり確率で種別を決定（すべてファクトリ経由）
	var r: float = rng.randf()
	if r < 0.25:
		return _mk_herb(inv)
	elif r < 0.45:
		return _mk_food(inv)
	elif r < 0.61:
		return _mk_weapon(inv, rng)       # 剣：+0～+2
	elif r < 0.75:
		return _mk_shield(inv, rng)       # 盾：+0～+2
	elif r < 0.83:
		return _mk_seal(inv)
	elif r < 0.88:
		return _mk_seal_expand(inv)
	elif r < 0.94:
		return _mk_pouch(inv)
	elif r < 0.97:
		return _mk_pouch_fusion(inv)
	else:
		return _mk_furniture(inv)
