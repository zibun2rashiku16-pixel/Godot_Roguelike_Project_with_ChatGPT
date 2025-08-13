extends Object
class_name MapMemory

static func remember_visible(vis_map: Array, explored: Array) -> void:
	var H: int = vis_map.size()
	if H != explored.size():
		return
	for y in H:
		var rowv: Array = vis_map[y]
		var rowe: Array = explored[y]
		var W: int = rowv.size()
		if W != rowe.size():
			continue
		for x in W:
			if (rowv[x] as bool):
				rowe[x] = true

# ★ 追加：可視セル内の「アイテム／階段」を記憶
static func remember_objects(main: Main) -> void:
	if main == null:
		return
	# アイテムの記憶：可視セルで ground をスキャンして更新
	for y in Params.H:
		var row_vis: Array = main.vis_map[y]
		for x in Params.W:
			if not (row_vis[x] as bool):
				continue
			var cell: Vector2i = Vector2i(x, y)
			var arr: Array = []
			if main.inv != null:
				arr = main.inv.get_ground_items_at(cell)
			if arr.size() > 0:
				# 先頭アイテムの種類を記憶（描画色に使用）
				var it: Dictionary = arr[0]
				var t: String = String(it.get("type", ""))
				main.known_item_cells[cell] = t
			else:
				# 可視で空なら記憶から消す
				if main.known_item_cells.has(cell):
					main.known_item_cells.erase(cell)
	# 階段の記憶：可視なら既知化
	if main.stairs.y >= 0 and main.stairs.y < Params.H and main.stairs.x >= 0 and main.stairs.x < Params.W:
		var vrow: Array = main.vis_map[main.stairs.y]
		if vrow[main.stairs.x] as bool:
			main.known_stairs_seen = true
