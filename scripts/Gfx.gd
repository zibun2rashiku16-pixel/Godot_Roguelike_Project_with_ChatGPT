extends Node2D
class_name Gfx

var main: Main
var _tile: int = 16
var _off: Vector2 = Vector2.ZERO

var player_tex: Texture2D
var enemy_tex: Texture2D
var stairs_tex: Texture2D
var sword_tex: Texture2D
var shield_tex: Texture2D
var herb_tex: Texture2D
var food_tex: Texture2D
var seal_tex: Texture2D
var seal_expand_tex: Texture2D
var pouch_tex: Texture2D
var pouch_fusion_tex: Texture2D
var furniture_tex: Texture2D

# 差し替え可能なパス（エディタから変更可）
@export var stairs_tex_path: String = "res://assets/stairs.png"
@export var sword_tex_path: String = "res://assets/sword.png"
@export var shield_tex_path: String = "res://assets/shield.png"
@export var herb_tex_path: String = "res://assets/herb.png"
@export var food_tex_path: String = "res://assets/food.png"
@export var seal_tex_path: String = "res://assets/seal.png"
@export var seal_expand_tex_path: String = "res://assets/seal_expand.png"
@export var pouch_tex_path: String = "res://assets/pouch.png"
@export var pouch_fusion_tex_path: String = "res://assets/pouch_fusion.png"
@export var furniture_tex_path: String = "res://assets/furniture.png"

var flash_player: float = 0.0
var flash_cells: Array = []
var damage_numbers: Array = []

var show_guides: bool = true

# レベルアップエフェクト
var level_fx: Array = [] # {pos:Vector2i, t:float, dur:float}

func _ready() -> void:
	set_process(false)
	# 既存（プレイヤー／敵）は Params 由来
	var r1: Resource = load(Params.PLAYER_TEXTURE_PATH)
	if r1 is Texture2D:
		player_tex = r1 as Texture2D
	var r2: Resource = load(Params.ENEMY_TEXTURE_PATH)
	if r2 is Texture2D:
		enemy_tex = r2 as Texture2D
	# 新規：アイテム／階段の差し替え可能テクスチャ
	stairs_tex = _load_tex(stairs_tex_path)
	sword_tex = _load_tex(sword_tex_path)
	shield_tex = _load_tex(shield_tex_path)
	herb_tex = _load_tex(herb_tex_path)
	food_tex = _load_tex(food_tex_path)
	seal_tex = _load_tex(seal_tex_path)
	seal_expand_tex = _load_tex(seal_expand_tex_path)
	pouch_tex = _load_tex(pouch_tex_path)
	pouch_fusion_tex = _load_tex(pouch_fusion_tex_path)
	furniture_tex = _load_tex(furniture_tex_path)

func _load_tex(p: String) -> Texture2D:
	if p.is_empty():
		return null
	var r: Resource = load(p)
	if r is Texture2D:
		return r as Texture2D
	return null

func get_tile_size() -> int:
	_update_layout_cache()
	return _tile

func get_draw_offset() -> Vector2:
	_update_layout_cache()
	return _off

func _update_layout_cache() -> void:
	if main == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var reserved: int = 0
	if main.ui != null:
		reserved = main.ui.get_reserved_height()
	var avail_h: float = max(0.0, vp.y - float(reserved))
	var tile_fit_w: float = vp.x / float(Params.W)
	var tile_fit_h: float = avail_h / float(Params.H)
	var tile: int = int(floor(min(tile_fit_w, tile_fit_h)))
	if tile < 8:
		tile = 8
	_tile = tile
	var used_w: float = float(tile * Params.W)
	var used_h: float = float(tile * Params.H)
	var ox: float = max(0.0, (vp.x - used_w) * 0.5)
	var oy: float = 0.0
	_off = Vector2(ox, oy)

func _process(delta: float) -> void:
	var dirty: bool = false
	if flash_player > 0.0:
		flash_player = max(0.0, flash_player - delta)
		dirty = true
	for i: int in range(flash_cells.size() - 1, -1, -1):
		var e: Dictionary = flash_cells[i]
		var t: float = float(e["t"]) - delta
		if t <= 0.0:
			flash_cells.remove_at(i)
			dirty = true
		else:
			e["t"] = t
			flash_cells[i] = e
			dirty = true
	for i: int in range(damage_numbers.size() - 1, -1, -1):
		var d: Dictionary = damage_numbers[i]
		d["t"] = float(d.get("t", 0.0)) + delta
		if float(d["t"]) >= float(d.get("dur", 0.7)):
			damage_numbers.remove_at(i)
			dirty = true
		else:
			damage_numbers[i] = d
			dirty = true
	# レベルアップFX
	for i2: int in range(level_fx.size() - 1, -1, -1):
		var fx: Dictionary = level_fx[i2]
		fx["t"] = float(fx.get("t", 0.0)) + delta
		if float(fx["t"]) >= float(fx.get("dur", 0.9)):
			level_fx.remove_at(i2)
			dirty = true
		else:
			level_fx[i2] = fx
			dirty = true

	if dirty:
		queue_redraw()
	if flash_player <= 0.0 and flash_cells.is_empty() and damage_numbers.is_empty() and level_fx.is_empty():
		set_process(false)
	
	if show_guides:
		queue_redraw()

func _draw() -> void:
	if main == null:
		return
	_update_layout_cache()
	var tile: int = _tile
	var off: Vector2 = _off

	# 地形
	for y in Params.H:
		var row_grid: Array = main.grid[y]
		var row_exp: Array = main.explored[y]
		var row_vis: Array = main.vis_map[y]
		for x in Params.W:
			var r: Rect2 = Rect2(off + Vector2(x * tile, y * tile), Vector2(tile, tile))
			var is_wall: bool = ((row_grid[x] as int) == 1)
			var seen: bool = (row_exp[x] as bool)
			var vis: bool = (row_vis[x] as bool)
			if seen:
				var base_col: Color
				if is_wall:
					base_col = Color(0.15, 0.15, 0.18)
				else:
					base_col = Color(0.08, 0.08, 0.1)
				draw_rect(r, base_col, true)
			if vis:
				var vis_col: Color
				if is_wall:
					vis_col = Color(0.35, 0.35, 0.45)
				else:
					vis_col = Color(0.22, 0.22, 0.25)
				draw_rect(r, vis_col, true)

	# アイテム（可視）
	if main.inv != null:
		var cells: Array = main.inv.ground.keys()
		for cell: Vector2i in cells:
			if cell.y < 0 or cell.y >= Params.H or cell.x < 0 or cell.x >= Params.W:
				continue
			var vis_row: Array = main.vis_map[cell.y]
			if not (vis_row[cell.x] as bool):
				continue
			var base: Vector2 = off + Vector2(cell.x * tile, cell.y * tile)
			var ir: Rect2 = Rect2(base, Vector2(tile, tile))
			var it: Dictionary = main.inv.get_ground_top_item(cell)
			var tname: String = String(it.get("type", ""))
			var tex: Texture2D = _item_texture_for_type(tname)
			if tex != null:
				draw_texture_rect(tex, ir, false)
			else:
				var m: float = float(tile) * 0.2
				var sz: Vector2 = Vector2(float(tile) - m * 2.0, float(tile) - m * 2.0)
				var irc: Rect2 = Rect2(base + Vector2(m, m), sz)
				var col: Color = _item_color(tname, 1.0)
				draw_rect(irc, col, true)

	# アイテム（記憶のみ：薄表示）
	if main.known_item_cells.size() > 0:
		var keys2: Array = main.known_item_cells.keys()
		for cell2: Vector2i in keys2:
			if cell2.y < 0 or cell2.y >= Params.H or cell2.x < 0 or cell2.x >= Params.W:
				continue
			var vis_row2: Array = main.vis_map[cell2.y]
			if vis_row2[cell2.x] as bool:
				continue
			var exp_row: Array = main.explored[cell2.y]
			if not (exp_row[cell2.x] as bool):
				continue
			var base2: Vector2 = off + Vector2(cell2.x * tile, cell2.y * tile)
			var ir2: Rect2 = Rect2(base2, Vector2(tile, tile))
			var tname2: String = String(main.known_item_cells[cell2])
			var tex2: Texture2D = _item_texture_for_type(tname2)
			if tex2 != null:
				draw_texture_rect(tex2, ir2, false, Color(1.0, 1.0, 1.0, 0.45))
			else:
				var m2: float = float(tile) * 0.35
				var sz2: Vector2 = Vector2(float(tile) - m2 * 2.0, float(tile) - m2 * 2.0)
				var irc2: Rect2 = Rect2(base2 + Vector2(m2, m2), sz2)
				var col2: Color = _item_color(tname2, 0.45)
				draw_rect(irc2, col2, true)

	# 階段
	if main.stairs.x >= 0 and main.stairs.y >= 0:
		var sr: Rect2 = Rect2(off + Vector2(main.stairs.x * tile, main.stairs.y * tile), Vector2(tile, tile))
		var vrow: Array = main.vis_map[main.stairs.y]
		if vrow[main.stairs.x] as bool:
			if stairs_tex != null:
				draw_texture_rect(stairs_tex, sr, false)
			else:
				draw_rect(sr, Color(0.6, 0.6, 0.2), true)
		elif main.known_stairs_seen:
			if stairs_tex != null:
				draw_texture_rect(stairs_tex, sr, false, Color(1.0, 1.0, 1.0, 0.4))
			else:
				draw_rect(sr, Color(0.6, 0.6, 0.2, 0.4), true)

	# 敵
	for e: Dictionary in main.enemies:
		var ep: Vector2i = e["pos"]
		var er: Rect2 = Rect2(off + Vector2(ep.x * tile, ep.y * tile), Vector2(tile, tile))
		if enemy_tex != null:
			draw_texture_rect(enemy_tex, er, false)
		else:
			draw_rect(er, Color(0.7, 0.2, 0.2), true)

	# プレイヤー
	var pr: Rect2 = Rect2(off + Vector2(main.player.x * tile, main.player.y * tile), Vector2(tile, tile))
	if player_tex != null:
		draw_texture_rect(player_tex, pr, false)
	else:
		draw_rect(pr, Color(0.2, 0.7, 0.2), true)

	# 点滅・ダメージ数字
	if flash_player > 0.0:
		draw_rect(pr, Color(1.0, 1.0, 1.0, 0.55), true)
	for e2: Dictionary in flash_cells:
		var cp: Vector2i = e2["pos"]
		var rr: Rect2 = Rect2(off + Vector2(cp.x * tile, cp.y * tile), Vector2(tile, tile))
		draw_rect(rr, Color(1.0, 1.0, 1.0, 0.55), true)
	if not damage_numbers.is_empty():
		var font: Font = ThemeDB.fallback_font
		for d: Dictionary in damage_numbers:
			var cell3: Vector2i = d["pos"]
			var t: float = float(d["t"])
			var dur: float = float(d.get("dur", 0.7))
			var alpha: float = clamp(1.0 - (t / dur), 0.0, 1.0)
			var lift: float = float(tile) * 0.9 * (t / dur)
			var center_txt: Vector2 = off + Vector2(float(cell3.x * tile + tile / 2), float(cell3.y * tile + tile / 2 - lift))
			var size_px: int = max(16, int(float(tile) * 0.9))
			var start: Vector2 = center_txt + Vector2(-float(tile) * 0.5, -float(tile) * 0.4)
			var txt: String = str(int(d["val"]))
			draw_string(font, start, txt, HORIZONTAL_ALIGNMENT_CENTER, float(tile), size_px, Color(1.0, 0.6, 0.0, alpha))

	# レベルアップ・リング
	for fx: Dictionary in level_fx:
		var tprog: float = clamp(float(fx.get("t", 0.0)) / float(fx.get("dur", 0.9)), 0.0, 1.0)
		var center: Vector2 = off + Vector2(float((fx["pos"] as Vector2i).x * tile + tile / 2), float((fx["pos"] as Vector2i).y * tile + tile / 2))
		var r1: float = float(tile) * (0.4 + 1.0 * tprog)
		var r2: float = float(tile) * (0.7 + 1.7 * tprog)
		var r3: float = float(tile) * (1.0 + 2.4 * tprog)
		var a: float = 0.8 * (1.0 - tprog)
		var col_fx: Color = Color(1.0, 0.9, 0.3, a)
		draw_arc(center, r1, 0.0, TAU, 48, col_fx, 3.0, true)
		draw_arc(center, r2, 0.0, TAU, 48, col_fx, 2.0, true)
		draw_arc(center, r3, 0.0, TAU, 48, col_fx, 1.0, true)

	# 8方向ガイド
	if show_guides:
		_draw_guides()

func _item_texture_for_type(tname: String) -> Texture2D:
	if tname == "weapon":
		return sword_tex
	if tname == "shield":
		return shield_tex
	if tname == "potion":
		return herb_tex
	if tname == "food":
		return food_tex
	if tname == "seal":
		return seal_tex
	if tname == "seal_expand":
		return seal_expand_tex
	if tname == "pouch":
		return pouch_tex
	if tname == "pouch_fusion":
		return pouch_fusion_tex
	if tname == "furniture":
		return furniture_tex
	return null

func _item_color(tname: String, alpha: float) -> Color:
	var col: Color = Color(0.8, 0.8, 0.8, alpha)
	if tname == "weapon":
		col = Color(0.85, 0.85, 0.95, alpha)
	elif tname == "shield":
		col = Color(0.6, 0.7, 1.0, alpha)
	elif tname == "potion":
		col = Color(0.25, 0.85, 0.35, alpha)
	elif tname == "food":
		col = Color(0.95, 0.75, 0.3, alpha)
	return col

func add_flash_cell(cell: Vector2i) -> void:
	var e: Dictionary = { "pos": cell, "t": 0.2 }
	flash_cells.append(e)
	set_process(true)
	queue_redraw()

func flash_player_now() -> void:
	flash_player = 0.2
	set_process(true)
	queue_redraw()

func add_damage_number(cell: Vector2i, amount: int) -> void:
	var d: Dictionary = { "pos": cell, "val": amount, "t": 0.0, "dur": 0.7 }
	damage_numbers.append(d)
	set_process(true)
	queue_redraw()

# レベルアップ開始
func play_level_up_effect(cell: Vector2i) -> void:
	var e: Dictionary = { "pos": cell, "t": 0.0, "dur": 0.9 }
	level_fx.append(e)
	set_process(true)
	queue_redraw()

func clear_effects() -> void:
	flash_player = 0.0
	flash_cells.clear()
	damage_numbers.clear()
	level_fx.clear()
	set_process(false)
	queue_redraw()

# 8方向ガイド（壁に関わらず、最大5マス先まで／より細く・より透明）
func _draw_guides() -> void:
	if main == null:
		return
	# 画面サイズとUI予約領域
	var vp: Vector2 = get_viewport_rect().size
	var reserved: int = 0
	if main.ui != null:
		reserved = main.ui.get_reserved_height()
	var usable_h: float = max(0.0, vp.y - float(reserved))

	# タイルピクセルサイズ（W,Hにフィット）— 端数は床で切る
	var cell: float = floor(min(vp.x / float(Params.W), usable_h / float(Params.H)))
	if cell <= 0.0:
		return

	# 横は中央寄せ、縦は上詰め（UIを下に避ける）
	var ox: float = floor((vp.x - cell * float(Params.W)) * 0.5)
	var oy: float = 0.0

	# プレイヤー中心（ピクセル座標）
	var pc: Vector2 = Vector2(
		ox + (float(main.player.x) + 0.5) * cell,
		oy + (float(main.player.y) + 0.5) * cell
	)

	# 8方向
	var dirs: Array = [
		Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
		Vector2i(-1,  0),                    Vector2i(1,  0),
		Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
	]

	# より透明な色・より細い線
	var col: Color = Color(1.0, 0.8, 0.2, 0.25)
	var w: float = max(0.5, cell * 0.05)

	for d: Vector2i in dirs:
		var last: Vector2i = main.player
		# 壁に関わらず、最大5マスまで進める（マップ外は停止）
		for _step: int in range(5):
			var nx: int = last.x + d.x
			var ny: int = last.y + d.y
			if nx < 0 or ny < 0 or nx >= Params.W or ny >= Params.H:
				break
			last = Vector2i(nx, ny)

		var ec: Vector2 = Vector2(
			ox + (float(last.x) + 0.5) * cell,
			oy + (float(last.y) + 0.5) * cell
		)
		if ec != pc:
			draw_line(pc, ec, col, w, true)
