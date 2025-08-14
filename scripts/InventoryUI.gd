extends Control
class_name InventoryUI

var main: Main
var inv: Inventory

# オーバーレイ（暗めの薄グレー背景）
var overlay: Panel

# 左上：装備
var equip_panel: Panel
var equip_v: VBoxContainer
var lbl_equip: Label
var btn_equip_weapon: Button
var btn_equip_shield: Button

# 右上：足元（3×3）
var ground_panel: Panel
var ground_v: VBoxContainer
var lbl_ground: Label
var ground_grid: GridContainer
var ground_btns: Array = [] # 3x3

# 下段：持ち物（6×6）
var bag_panel: Panel
var bag_v: VBoxContainer
var lbl_bag: Label
var bag_grid: GridContainer
var bag_btns: Array = [] # 6×6

# 上段：袋（表示は常時 6×6）
var pouch_panel: Panel
var pouch_v: VBoxContainer
var lbl_pouch: Label
var pouch_grid: GridContainer
var pouch_btns: Array = [] # 6×6
var pouch_open: bool = false
var pouch_open_id: int = -1
var _inv_connected: bool = false

# ポップアップ
var popup_ground: PopupMenu
var popup_bag: PopupMenu
var popup_equip: PopupMenu
var popup_pouch: PopupMenu
var ground_popup_cell: Vector2i = Vector2i.ZERO
var ground_popup_item_id: int = -1
var bag_popup_item_id: int = -1
var equip_popup_slot: String = ""
var pouch_popup_item_id: int = -1
var pouch_popup_pos: Vector2i = Vector2i.ZERO

# 「移動」モード
var moving: bool = false
var moving_src_kind: String = ""      # "ground"/"bag"/"pouch"
var moving_item_id: int = -1
var moving_src_ground_cell: Vector2i = Vector2i.ZERO
var moving_src_pouch_id: int = -1

# 強化のシール 選択モード
var enhancing: bool = false
var enhance_from: String = ""                 # "bag" / "pouch"
var enhancing_seal_id: int = -1
var enhancing_seal_from_pouch_id: int = -1    # seal が袋の場合のみ

# レイアウト定数
const PADDING: int = 16
const TOP_H: int = 280
const POUCH_CELL: int = 56
const POUCH_LABEL_H: int = 28
const POUCH_VSEP: int = 6

# 3×3 相対（足元）
const G_OFFSETS: Array = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(-1,  0), Vector2i(0,  0), Vector2i(1,  0),
	Vector2i(-1,  1), Vector2i(0,  1), Vector2i(1,  1)
]

# ラベル用の黒
const COL_BLACK: Color = Color(0, 0, 0, 1)

# バッグの「開いている袋」ハイライト用 StyleBox
var sb_btn_highlight: StyleBoxFlat
var sb_btn_highlight_hover: StyleBoxFlat
var sb_btn_highlight_pressed: StyleBoxFlat

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	overlay = Panel.new()
	add_child(overlay)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_overlay: StyleBoxFlat = StyleBoxFlat.new()
	sb_overlay.bg_color = Color(0.84, 0.84, 0.84, 0.96)
	overlay.add_theme_stylebox_override("panel", sb_overlay)

	# 装備
	equip_panel = Panel.new()
	overlay.add_child(equip_panel)
	equip_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_e: StyleBoxFlat = _make_panel_style(0.92)
	equip_panel.add_theme_stylebox_override("panel", sb_e)
	equip_v = VBoxContainer.new()
	equip_panel.add_child(equip_v)
	equip_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	equip_v.add_theme_constant_override("separation", 6)
	lbl_equip = Label.new()
	lbl_equip.text = "装備（剣・盾）"
	equip_v.add_child(lbl_equip)
	btn_equip_weapon = Button.new()
	btn_equip_weapon.text = "武器：なし"
	btn_equip_weapon.custom_minimum_size = Vector2(0, 44)
	equip_v.add_child(btn_equip_weapon)
	btn_equip_weapon.pressed.connect(_on_equip_button.bind("weapon"))
	btn_equip_shield = Button.new()
	btn_equip_shield.text = "盾：なし"
	btn_equip_shield.custom_minimum_size = Vector2(0, 44)
	equip_v.add_child(btn_equip_shield)
	btn_equip_shield.pressed.connect(_on_equip_button.bind("shield"))

	# 足元（3×3）
	ground_panel = Panel.new()
	overlay.add_child(ground_panel)
	ground_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_g: StyleBoxFlat = _make_panel_style(0.92)
	ground_panel.add_theme_stylebox_override("panel", sb_g)
	ground_v = VBoxContainer.new()
	ground_panel.add_child(ground_v)
	ground_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	ground_v.add_theme_constant_override("separation", 6)
	lbl_ground = Label.new()
	lbl_ground.text = "足元（中央=自分／周囲8）— タップでメニュー"
	ground_v.add_child(lbl_ground)
	ground_grid = GridContainer.new()
	ground_grid.columns = 3
	ground_v.add_child(ground_grid)
	_build_ground_buttons()

	# 持ち物（6×6）
	bag_panel = Panel.new()
	overlay.add_child(bag_panel)
	bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_b: StyleBoxFlat = _make_panel_style(0.93)
	sb_b.bg_color = Color(0.78, 0.78, 0.78, 0.96)
	bag_panel.add_theme_stylebox_override("panel", sb_b)
	bag_v = VBoxContainer.new()
	bag_panel.add_child(bag_v)
	bag_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	bag_v.add_theme_constant_override("separation", 6)
	lbl_bag = Label.new()
	lbl_bag.text = "持ち物（6×6）— タップでメニュー（移動/使う/詳細）"
	bag_v.add_child(lbl_bag)
	bag_grid = GridContainer.new()
	bag_grid.columns = 6
	bag_v.add_child(bag_grid)
	_build_bag_buttons()

	# 袋（常時 6×6 表示）
	pouch_panel = Panel.new()
	overlay.add_child(pouch_panel)
	pouch_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_p: StyleBoxFlat = _make_panel_style(0.91)
	pouch_panel.add_theme_stylebox_override("panel", sb_p)
	pouch_v = VBoxContainer.new()
	pouch_panel.add_child(pouch_v)
	pouch_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	pouch_v.add_theme_constant_override("separation", POUCH_VSEP)
	lbl_pouch = Label.new()
	lbl_pouch.text = "袋（最大 6×6）— 未拡張は使用不可"
	pouch_v.add_child(lbl_pouch)
	pouch_grid = GridContainer.new()
	pouch_grid.columns = 6
	pouch_v.add_child(pouch_grid)
	_build_pouch_buttons()
	pouch_panel.visible = false

	# ポップアップ（順序：拾う→移動→詳細）
	popup_ground = PopupMenu.new()
	overlay.add_child(popup_ground)
	popup_ground.add_item("拾う", 10)   # ★追加：足元→バッグに自動収納
	popup_ground.add_item("移動", 11)
	popup_ground.add_item("詳細", 12)
	popup_ground.add_separator()
	popup_ground.add_item("閉じる", 0)
	popup_ground.add_theme_font_size_override("font_size", 28)

	popup_bag = PopupMenu.new()
	overlay.add_child(popup_bag)
	popup_bag.add_item("移動", 22)
	popup_bag.add_item("使う", 21)
	popup_bag.add_item("詳細", 23)
	popup_bag.add_separator()
	popup_bag.add_item("閉じる", 0)
	popup_bag.add_theme_font_size_override("font_size", 28)

	popup_equip = PopupMenu.new()
	overlay.add_child(popup_equip)
	popup_equip.add_item("詳細", 31)
	popup_equip.add_item("外す", 32)
	popup_equip.add_separator()
	popup_equip.add_item("閉じる", 0)
	popup_equip.add_theme_font_size_override("font_size", 28)

	popup_pouch = PopupMenu.new()
	overlay.add_child(popup_pouch)
	popup_pouch.add_item("移動", 41)
	popup_pouch.add_item("使う", 43)
	popup_pouch.add_item("詳細", 42)
	popup_pouch.add_separator()
	popup_pouch.add_item("閉じる", 0)
	popup_pouch.add_theme_font_size_override("font_size", 28)

	popup_ground.id_pressed.connect(_on_ground_popup_id)
	popup_bag.id_pressed.connect(_on_bag_popup_id)
	popup_equip.id_pressed.connect(_on_equip_popup_id)
	popup_pouch.id_pressed.connect(_on_pouch_popup_id)

	# ラベルは黒文字
	_apply_label_black_recursive(overlay)

	# ハイライト StyleBox の生成
	_init_highlight_styles()

	_layout_absolute()
	get_viewport().size_changed.connect(_on_viewport_resized)

func _make_panel_style(alpha: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.90, 0.90, 0.90, alpha)
	sb.border_color = Color(0.0, 0.0, 0.0, 0.12)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb

func _init_highlight_styles() -> void:
	sb_btn_highlight = StyleBoxFlat.new()
	sb_btn_highlight.bg_color = Color(1.0, 0.96, 0.60, 0.85)
	sb_btn_highlight.border_color = Color(0.25, 0.25, 0.00, 0.90)
	sb_btn_highlight.border_width_left = 2
	sb_btn_highlight.border_width_top = 2
	sb_btn_highlight.border_width_right = 2
	sb_btn_highlight.border_width_bottom = 2
	sb_btn_highlight.corner_radius_top_left = 6
	sb_btn_highlight.corner_radius_top_right = 6
	sb_btn_highlight.corner_radius_bottom_left = 6
	sb_btn_highlight.corner_radius_bottom_right = 6

	sb_btn_highlight_hover = StyleBoxFlat.new()
	sb_btn_highlight_hover.bg_color = Color(1.00, 0.98, 0.70, 0.90)
	sb_btn_highlight_hover.border_color = Color(0.30, 0.30, 0.00, 0.95)
	sb_btn_highlight_hover.border_width_left = 2
	sb_btn_highlight_hover.border_width_top = 2
	sb_btn_highlight_hover.border_width_right = 2
	sb_btn_highlight_hover.border_width_bottom = 2
	sb_btn_highlight_hover.corner_radius_top_left = 6
	sb_btn_highlight_hover.corner_radius_top_right = 6
	sb_btn_highlight_hover.corner_radius_bottom_left = 6
	sb_btn_highlight_hover.corner_radius_bottom_right = 6

	sb_btn_highlight_pressed = StyleBoxFlat.new()
	sb_btn_highlight_pressed.bg_color = Color(0.95, 0.88, 0.50, 0.95)
	sb_btn_highlight_pressed.border_color = Color(0.20, 0.20, 0.00, 1.00)
	sb_btn_highlight_pressed.border_width_left = 2
	sb_btn_highlight_pressed.border_width_top = 2
	sb_btn_highlight_pressed.border_width_right = 2
	sb_btn_highlight_pressed.border_width_bottom = 2
	sb_btn_highlight_pressed.corner_radius_top_left = 6
	sb_btn_highlight_pressed.corner_radius_top_right = 6
	sb_btn_highlight_pressed.corner_radius_bottom_left = 6
	sb_btn_highlight_pressed.corner_radius_bottom_right = 6

func toggle() -> void:
	visible = not visible
	if visible:
		if main != null and inv == null:
			inv = main.inv
		if inv != null and not _inv_connected:
			inv.pouch_toggled.connect(_on_pouch_toggled)
			_inv_connected = true
			pouch_open_id = inv.get_open_pouch_id()
			pouch_open = (pouch_open_id != -1)
			_update_pouch_visibility()
		_layout_absolute()
		_refresh_all()
	else:
		if inv != null:
			inv.close_pouch()
		_cancel_move_mode()
		_cancel_enhance_mode()

# レイアウト
func _on_viewport_resized() -> void:
	_layout_absolute()

func _layout_absolute() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var reserved: int = 0
	if main != null and main.ui != null:
		reserved = main.ui.get_reserved_height()
	var usable_h: float = max(0.0, vp.y - float(reserved))
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(vp.x, usable_h)

	var pad: float = float(PADDING)
	var y0: float = pad
	var avail_w: float = vp.x - pad * 2.0
	var panel_w: float = floor((avail_w - pad) * 0.5)

	var pouch_rows: float = 6.0
	var panel_h_pouch: float = float(POUCH_LABEL_H) + pouch_rows * float(POUCH_CELL) + float(POUCH_VSEP) + 8.0

	if pouch_open:
		pouch_panel.position = Vector2(pad, y0)
		pouch_panel.size = Vector2(avail_w, panel_h_pouch)
		var bag_y: float = y0 + panel_h_pouch + pad
		var bag_hh: float = max(0.0, usable_h - bag_y - pad)
		bag_panel.position = Vector2(pad, bag_y)
		bag_panel.size = Vector2(avail_w, bag_hh)
		equip_panel.visible = false
		ground_panel.visible = false
	else:
		var panel_h: float = float(TOP_H)
		equip_panel.position = Vector2(pad, y0)
		equip_panel.size = Vector2(panel_w, panel_h)
		ground_panel.position = Vector2(pad + panel_w + pad, y0)
		ground_panel.size = Vector2(panel_w, panel_h)
		var bag_y2: float = y0 + panel_h + pad
		var bag_hh2: float = max(0.0, usable_h - bag_y2 - pad)
		bag_panel.position = Vector2(pad, bag_y2)
		bag_panel.size = Vector2(avail_w, bag_hh2)

# 子ノードクリア
func _clear_children(n: Node) -> void:
	var arr: Array = n.get_children()
	for c: Node in arr:
		c.queue_free()

# ラベル黒化
func _apply_label_black_recursive(n: Node) -> void:
	if n is Label:
		var lb: Label = n
		lb.add_theme_color_override("font_color", COL_BLACK)
	for child: Node in n.get_children():
		_apply_label_black_recursive(child)

# ボタン構築
func _build_ground_buttons() -> void:
	ground_btns.clear()
	_clear_children(ground_grid)
	for i: int in 9:
		var gb: Button = Button.new()
		gb.custom_minimum_size = Vector2(64, 64)
		gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		gb.text = "" # 空きマスはバッグと同じ見た目
		gb.disabled = false # 初期から有効（移動先として使用可）
		gb.set_meta("id", -1)
		gb.set_meta("cx", 0)
		gb.set_meta("cy", 0)
		ground_grid.add_child(gb)
		gb.pressed.connect(_on_ground_pressed.bind(gb))
		ground_btns.append(gb)

func _build_bag_buttons() -> void:
	bag_btns.clear()
	_clear_children(bag_grid)
	for y: int in 6:
		for x: int in 6:
			var b: Button = Button.new()
			b.custom_minimum_size = Vector2(48, 48)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			b.text = ""
			b.set_meta("x", x)
			b.set_meta("y", y)
			b.set_meta("id", -1)
			bag_grid.add_child(b)
			b.pressed.connect(_on_bag_pressed.bind(b))
			bag_btns.append(b)

func _build_pouch_buttons() -> void:
	pouch_btns.clear()
	_clear_children(pouch_grid)
	for y: int in 6:
		for x: int in 6:
			var b: Button = Button.new()
			b.custom_minimum_size = Vector2(POUCH_CELL, POUCH_CELL)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.size_flags_vertical = Control.SIZE_EXPAND_FILL
			b.text = ""
			b.set_meta("px", x)
			b.set_meta("py", y)
			b.set_meta("id", -1)
			pouch_grid.add_child(b)
			b.pressed.connect(_on_pouch_pressed.bind(b))
			pouch_btns.append(b)

# リフレッシュ
func _refresh_all() -> void:
	if main == null:
		return
	if inv == null:
		inv = main.inv

	if inv.equip_weapon.is_empty():
		btn_equip_weapon.text = "武器：なし"
	else:
		btn_equip_weapon.text = "武器：" + String(inv.equip_weapon.get("name", "？"))
	if inv.equip_shield.is_empty():
		btn_equip_shield.text = "盾：なし"
	else:
		btn_equip_shield.text = "盾：" + String(inv.equip_shield.get("name", "？"))

	_refresh_ground_grid()
	_refresh_bag_grid()
	_refresh_pouch_grid()

func _refresh_ground_grid() -> void:
	for i: int in ground_btns.size():
		var b0: Button = ground_btns[i]
		b0.text = ""
		b0.disabled = false
		b0.tooltip_text = ""
		var rel: Vector2i = G_OFFSETS[i]
		var cell: Vector2i = main.player + rel
		b0.set_meta("cx", cell.x)
		b0.set_meta("cy", cell.y)
		b0.set_meta("id", -1)

	for i2: int in ground_btns.size():
		var b1: Button = ground_btns[i2]
		var cell2: Vector2i = Vector2i(int(b1.get_meta("cx")), int(b1.get_meta("cy")))
		var items: Array = inv.get_ground_items_at(cell2)
		if items.size() > 0:
			var it: Dictionary = items[0]
			var name: String = String(it.get("name", "？"))
			var count_suffix: String = ""
			if items.size() > 1:
				count_suffix = " ×" + str(items.size())
			b1.text = name + count_suffix
			b1.tooltip_text = "@(%d,%d) 先頭のみ表示" % [cell2.x, cell2.y]
			b1.set_meta("id", int(it.get("id", -1)))
			b1.disabled = false

func _refresh_bag_grid() -> void:
	# いったんハイライトを全消去し、初期状態に戻す
	for idx: int in bag_btns.size():
		var b0: Button = bag_btns[idx]
		b0.text = ""
		b0.disabled = false
		b0.tooltip_text = ""
		b0.set_meta("id", -1)
		b0.remove_theme_stylebox_override("normal")
		b0.remove_theme_stylebox_override("hover")
		b0.remove_theme_stylebox_override("pressed")

	# アイテム配置
	for y: int in inv.bag_h:
		var row: Array = inv.bag_cells[y]
		for x: int in inv.bag_w:
			var idv: int = int(row[x])
			var b: Button = bag_btns[y * 6 + x]
			if idv == -1:
				continue
			if inv.bag_items.has(idv):
				var it: Dictionary = inv.bag_items[idv]
				var pos: Vector2i = it.get("pos", Vector2i.ZERO)
				var size: Vector2i = it.get("size", Vector2i(1, 1))
				if x == pos.x and y == pos.y:
					b.text = String(it.get("name", "？"))
					b.tooltip_text = "[%dx%d] %s" % [size.x, size.y, String(it.get("type",""))]
					b.set_meta("id", idv)
					b.disabled = false
				else:
					b.text = ""
					b.disabled = true
					b.tooltip_text = ""

	# ★ 開いている袋（通常/合成）をハイライト
	var open_id: int = -1
	if inv != null:
		open_id = inv.get_open_pouch_id()
	if open_id != -1:
		for y2: int in inv.bag_h:
			var row2: Array = inv.bag_cells[y2]
			for x2: int in inv.bag_w:
				if int(row2[x2]) == open_id:
					var b_open: Button = bag_btns[y2 * 6 + x2]
					b_open.add_theme_stylebox_override("normal", sb_btn_highlight)
					b_open.add_theme_stylebox_override("hover", sb_btn_highlight_hover)
					b_open.add_theme_stylebox_override("pressed", sb_btn_highlight_pressed)
					break

func _refresh_pouch_grid() -> void:
	# 全マス未拡張として無効化
	for idx: int in pouch_btns.size():
		var b0: Button = pouch_btns[idx]
		b0.text = ""
		b0.disabled = true
		b0.tooltip_text = "未拡張"
		b0.set_meta("id", -1)

	if not pouch_open or inv == null or pouch_open_id == -1:
		return

	# 合成ロック表示
	if inv.pouches.has(pouch_open_id):
		var c: Dictionary = inv.pouches[pouch_open_id]
		var locked: bool = bool(c.get("fusion_locked", false))
		var locked_id: int = int(c.get("fusion_locked_item", -1))
		if locked and locked_id != -1:
			var items: Dictionary = c["items"]
			if items.has(locked_id):
				var itl: Dictionary = items[locked_id]
				var posl: Vector2i = itl.get("pos", Vector2i.ZERO)
				var sizel: Vector2i = itl.get("size", Vector2i(1, 1))
				var b: Button = pouch_btns[posl.y * 6 + posl.x]
				b.text = String(itl.get("name","？"))
				b.tooltip_text = "[袋 %dx%d] %s（合成済み）" % [sizel.x, sizel.y, String(itl.get("type",""))]
				b.set_meta("id", locked_id)
				b.disabled = false
			return

	var dims: Vector2i = inv.pouch_dims(pouch_open_id)
	var w: int = clamp(dims.x, 0, 6)
	var h: int = clamp(dims.y, 0, 6)
	for y: int in h:
		for x: int in w:
			var idv: int = inv.pouch_id_at(pouch_open_id, x, y)
			var b: Button = pouch_btns[y * 6 + x]
			if idv == -1:
				b.text = ""
				b.disabled = false
				b.tooltip_text = ""
				continue
			var it: Dictionary = inv.pouches[pouch_open_id]["items"][idv]
			var pos: Vector2i = it.get("pos", Vector2i.ZERO)
			var size: Vector2i = it.get("size", Vector2i(1, 1))
			if x == pos.x and y == pos.y:
				b.text = String(it.get("name", "？"))
				b.tooltip_text = "[袋 %dx%d] %s" % [size.x, size.y, String(it.get("type",""))]
				b.set_meta("id", idv)
				b.disabled = false
			else:
				b.text = ""
				b.disabled = true
				b.tooltip_text = ""

func _update_pouch_visibility() -> void:
	pouch_panel.visible = pouch_open
	equip_panel.visible = not pouch_open
	ground_panel.visible = not pouch_open
	_layout_absolute()

# 足元：タップ
func _on_ground_pressed(b: Button) -> void:
	var cell: Vector2i = Vector2i(int(b.get_meta("cx")), int(b.get_meta("cy")))
	var idv: int = int(b.get_meta("id"))

	# 移動モード：移動元に応じて足元へドロップ
	if moving:
		if moving_src_kind == "bag":
			var dropped: Dictionary = inv.remove_item_from_bag(moving_item_id)
			if not dropped.is_empty():
				inv.add_item_to_ground(cell, dropped)
				_end_move_success()
				return
		elif moving_src_kind == "ground":
			var it_take: Dictionary = inv.take_item_from_ground(moving_src_ground_cell, moving_item_id)
			if not it_take.is_empty():
				inv.add_item_to_ground(cell, it_take)
				_end_move_success()
				return
		elif moving_src_kind == "pouch":
			var it_p: Dictionary = inv.pouch_remove_item(moving_src_pouch_id, moving_item_id)
			if not it_p.is_empty():
				inv.add_item_to_ground(cell, it_p)
				_end_move_success()
				return
		_end_move_fail("その場所へは移動できません。")
		return

	# 強化選択中は無視（持ち物と同様）
	if enhancing:
		return

	# ★修正ポイント：idv が -1（メタ未設定）でも、セルにアイテムがあれば取得してメニューを開く
	if idv == -1:
		var arr: Array = inv.get_ground_items_at(cell)
		if arr.size() > 0:
			var it2: Dictionary = arr[0]
			idv = int(it2.get("id", -1))
			if idv == -1:
				return
		else:
			return

	# ここまで来れば ground にアイテムがあるのでメニューを開く
	ground_popup_item_id = idv
	ground_popup_cell = cell
	var gp: Vector2 = get_viewport().get_mouse_position()
	popup_ground.popup(Rect2i(Vector2i(int(gp.x), int(gp.y)), Vector2i(1, 1)))

func _on_ground_popup_id(id: int) -> void:
	if id == 10:
		# ★ 「拾う」= 足元 → バッグ（入れば1ターン経過）
		var picked: Dictionary = inv.take_item_from_ground(ground_popup_cell, ground_popup_item_id)
		if picked.is_empty():
			_show_info("その場所には拾えるものがありません。")
			return
		var ok_put: bool = inv.place_item_in_bag(picked)
		if ok_put:
			_refresh_all()
			if main != null:
				main._post_turn_update()
		else:
			inv.add_item_to_ground(ground_popup_cell, picked)
			_show_info("バッグに空きがありません。")
	elif id == 11:
		moving = true
		moving_src_kind = "ground"
		moving_item_id = ground_popup_item_id
		moving_src_ground_cell = ground_popup_cell
	elif id == 12:
		var txt: String = "不明なアイテム"
		var arr: Array = inv.get_ground_items_at(ground_popup_cell)
		if arr.size() > 0:
			var it: Dictionary = arr[0]
			var t: String = it.get("type", "")
			if t == "weapon":
				txt = "%s\n種類:剣  基礎:%d  修正:+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "shield":
				txt = "%s\n種類:盾  基礎:%d  修正:+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
					int((it.get("size",Vector2i(2,2)) as Vector2i).x), int((it.get("size",Vector2i(2,2)) as Vector2i).y)
				]
			elif t == "potion":
				txt = "%s\n種類:薬草  HP+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("heal",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "food":
				txt = "%s\n種類:食料  腹+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("belly",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
		var dlg: AcceptDialog = AcceptDialog.new()
		overlay.add_child(dlg)
		dlg.title = "詳細"
		var lb: Label = Label.new()
		lb.text = txt
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		dlg.add_child(lb)
		dlg.popup_centered()

# 持ち物：タップ
func _on_bag_pressed(b: Button) -> void:
	var x: int = int(b.get_meta("x"))
	var y: int = int(b.get_meta("y"))
	var idv: int = int(b.get_meta("id"))

	# 強化選択中：バッグ対象
	if enhancing and not moving:
		if idv == -1:
			return
		if enhance_from == "bag" and idv == enhancing_seal_id:
			return
		var ok_en: bool = false
		if enhance_from == "bag":
			ok_en = inv.apply_seal_from_bag_to_bag(enhancing_seal_id, idv)
		else:
			ok_en = inv.apply_seal_from_pouch_to_bag(enhancing_seal_from_pouch_id, enhancing_seal_id, idv)
		if ok_en:
			_refresh_all()
			_cancel_enhance_mode()
			if inv.last_use_consumed_turn and main != null:
				main._post_turn_update()
		return

	if moving:
		if moving_src_kind == "ground":
			var it_take: Dictionary = inv.take_item_from_ground(moving_src_ground_cell, moving_item_id)
			if it_take.is_empty():
				_end_move_fail("元の場所から取り出せませんでした。")
				return
			var ok: bool = inv.place_item_in_bag_at(it_take, Vector2i(x, y))
			if ok:
				_end_move_success()
				return
			inv.add_item_to_ground(moving_src_ground_cell, it_take)
			_end_move_fail("その位置には入りません。")
			return
		elif moving_src_kind == "bag":
			var ok2: bool = inv.move_item_in_bag_to(moving_item_id, Vector2i(x, y))
			if ok2:
				_end_move_success()
			else:
				_end_move_fail("その位置には入りません。")
			return
		elif moving_src_kind == "pouch":
			var old_pos: Vector2i = Vector2i.ZERO
			if inv.pouches.has(moving_src_pouch_id):
				var items0: Dictionary = inv.pouches[moving_src_pouch_id]["items"]
				if items0.has(moving_item_id):
					var it0: Dictionary = items0[moving_item_id]
					old_pos = it0.get("pos", Vector2i.ZERO)
			var it_from_p: Dictionary = inv.pouch_remove_item(moving_src_pouch_id, moving_item_id)
			if it_from_p.is_empty():
				_end_move_fail("袋から取り出せません。")
				return
			if inv.place_item_in_bag_at(it_from_p, Vector2i(x, y)):
				_end_move_success()
			else:
				if inv.place_item_in_bag(it_from_p):
					_end_move_success()
				else:
					inv.pouch_place_item_at(moving_src_pouch_id, it_from_p, old_pos)
					_end_move_fail("バッグに空きがありません。")
			return

	if idv == -1:
		return
	bag_popup_item_id = idv

	var enable_use: bool = false
	if inv.bag_items.has(idv):
		var it_bag: Dictionary = inv.bag_items[idv]
		var t2: String = it_bag.get("type", "")
		if t2 == "potion" or t2 == "food" or t2 == "weapon" or t2 == "shield" or t2 == "pouch" or t2 == "pouch_fusion" or t2 == "seal" or t2 == "seal_expand":
			enable_use = true

	var use_index: int = popup_bag.get_item_index(21)
	if use_index >= 0:
		popup_bag.set_item_disabled(use_index, not enable_use)

	var gp: Vector2 = get_viewport().get_mouse_position()
	popup_bag.popup(Rect2i(Vector2i(int(gp.x), int(gp.y)), Vector2i(1, 1)))

func _on_bag_popup_id(id: int) -> void:
	if id == 21:
		# 使う
		if inv.bag_items.has(bag_popup_item_id):
			var t: String = String(inv.bag_items[bag_popup_item_id].get("type",""))
			if t == "seal":
				enhancing = true
				enhance_from = "bag"
				enhancing_seal_id = bag_popup_item_id
				return
			elif t == "seal_expand":
				var okx: bool = inv.apply_expand_from_bag(bag_popup_item_id)
				if okx:
					_refresh_all()
					if inv.last_use_consumed_turn and main != null:
						main._post_turn_update()
				else:
					_show_info("拡張できません（袋が開いていない／最大）。")
				return
		if inv.use_item_from_bag(bag_popup_item_id):
			_refresh_all()
			if inv.last_use_consumed_turn and main != null:
				main._post_turn_update()
	elif id == 22:
		# 移動
		moving = true
		moving_src_kind = "bag"
		moving_item_id = bag_popup_item_id
	elif id == 23:
		var txt: String = "不明なアイテム"
		if inv.bag_items.has(bag_popup_item_id):
			var it: Dictionary = inv.bag_items[bag_popup_item_id]
			var t: String = it.get("type","")
			if t == "weapon":
				txt = "%s\n種類:剣  基礎:%d  修正:+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "shield":
				txt = "%s\n種類:盾  基礎:%d  修正:+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
					int((it.get("size",Vector2i(2,2)) as Vector2i).x), int((it.get("size",Vector2i(2,2)) as Vector2i).y)
				]
			elif t == "potion":
				txt = "%s\n種類:薬草  HP+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("heal",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "food":
				txt = "%s\n種類:食料  腹+%d  サイズ:%dx%d" % [
					String(it.get("name","？")), int(it.get("belly",0)),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "pouch":
				txt = "%s\n種類:袋  本体:%dx%d  中身:%dx%d" % [
					String(it.get("name","？")),
					int((it.get("size",Vector2i(2,3)) as Vector2i).x), int((it.get("size",Vector2i(2,3)) as Vector2i).y),
					int(it.get("pouch_w",2)), int(it.get("pouch_h",4))
				]
			elif t == "pouch_fusion":
				txt = "%s\n種類:合成の袋  本体:%dx%d  中身:%dx%d（装備のみ）" % [
					String(it.get("name","？")),
					int((it.get("size",Vector2i(2,3)) as Vector2i).x), int((it.get("size",Vector2i(2,3)) as Vector2i).y),
					int(it.get("pouch_w",2)), int(it.get("pouch_h",4))
				]
			elif t == "seal":
				txt = "%s\n種類:強化  対象の修正値+1（上限:%d）  サイズ:%dx%d" % [
					String(it.get("name","？")), int(inv.get_max_plus_limit()),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
			elif t == "seal_expand":
				txt = "%s\n種類:拡張  開いている袋の容量を拡張（通常袋のみ） サイズ:%dx%d" % [
					String(it.get("name","？")),
					int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
				]
		var dlg: AcceptDialog = AcceptDialog.new()
		overlay.add_child(dlg)
		dlg.title = "詳細"
		var lb: Label = Label.new()
		lb.text = txt
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		dlg.add_child(lb)
		dlg.popup_centered()

# 袋：タップ
func _on_pouch_pressed(b: Button) -> void:
	if not pouch_open:
		return
	var x: int = int(b.get_meta("px"))
	var y: int = int(b.get_meta("py"))
	var idv: int = int(b.get_meta("id"))

	# 強化選択中：袋対象
	if enhancing and not moving:
		if idv == -1:
			return
		if enhance_from == "pouch" and pouch_open_id == enhancing_seal_from_pouch_id and idv == enhancing_seal_id:
			return
		var ok_en: bool = false
		if enhance_from == "bag":
			ok_en = inv.apply_seal_from_bag_to_pouch(enhancing_seal_id, pouch_open_id, idv)
		else:
			ok_en = inv.apply_seal_from_pouch_to_pouch(enhancing_seal_from_pouch_id, enhancing_seal_id, idv)
		if ok_en:
			_refresh_all()
			_cancel_enhance_mode()
			if inv.last_use_consumed_turn and main != null:
				main._post_turn_update()
		return

	if moving:
		if moving_src_kind == "ground":
			var it_take: Dictionary = inv.take_item_from_ground(moving_src_ground_cell, moving_item_id)
			if it_take.is_empty():
				_end_move_fail("元の場所から取り出せませんでした。")
				return
			if inv.pouch_place_item_at(pouch_open_id, it_take, Vector2i(x, y)):
				_end_move_success()
				return
			inv.add_item_to_ground(moving_src_ground_cell, it_take)
			_end_move_fail("袋に入りません。")
			return
		elif moving_src_kind == "bag":
			var it_from_bag: Dictionary = inv.remove_item_from_bag(moving_item_id)
			if it_from_bag.is_empty():
				_end_move_fail("バッグから取り出せません。")
				return
			if inv.pouch_place_item_at(pouch_open_id, it_from_bag, Vector2i(x, y)):
				_end_move_success()
			else:
				if not inv.place_item_in_bag(it_from_bag):
					_show_info("バッグへ戻せませんでした。")
				_end_move_fail("袋に入りません。")
			return
		elif moving_src_kind == "pouch":
			var ok: bool = inv.pouch_move_item_to(pouch_open_id, moving_item_id, Vector2i(x, y))
			if ok:
				_end_move_success()
			else:
				_end_move_fail("その位置には入りません。")
			return

	if idv == -1:
		return
	pouch_popup_item_id = idv
	pouch_popup_pos = Vector2i(x, y)

	# 「使う」の有効/無効をIDで制御
	var enable_use: bool = true
	if inv != null and inv.pouches.has(pouch_open_id):
		var items: Dictionary = inv.pouches[pouch_open_id]["items"]
		if items.has(idv):
			var t: String = String(items[idv].get("type",""))
			enable_use = (t == "potion" or t == "food" or t == "weapon" or t == "shield" or t == "seal" or t == "seal_expand")
	var idx_use: int = popup_pouch.get_item_index(43)
	if idx_use >= 0:
		popup_pouch.set_item_disabled(idx_use, not enable_use)

	var gp: Vector2 = get_viewport().get_mouse_position()
	popup_pouch.popup(Rect2i(Vector2i(int(gp.x), int(gp.y)), Vector2i(1, 1)))

func _on_pouch_popup_id(id: int) -> void:
	if id == 41:
		moving = true
		moving_src_kind = "pouch"
		moving_item_id = pouch_popup_item_id
		moving_src_pouch_id = pouch_open_id
	elif id == 42:
		var txt: String = "不明なアイテム"
		if inv != null and inv.pouches.has(pouch_open_id):
			var items: Dictionary = inv.pouches[pouch_open_id]["items"]
			if items.has(pouch_popup_item_id):
				var it: Dictionary = items[pouch_popup_item_id]
				var t: String = it.get("type","")
				if t == "weapon":
					txt = "%s\n種類:剣  基礎:%d  修正:+%d  サイズ:%dx%d" % [
						String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
						int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
					]
				elif t == "shield":
					txt = "%s\n種類:盾  基礎:%d  修正:+%d  サイズ:%dx%d" % [
						String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
						int((it.get("size",Vector2i(2,2)) as Vector2i).x), int((it.get("size",Vector2i(2,2)) as Vector2i).y)
					]
				elif t == "potion":
					txt = "%s\n種類:薬草  HP+%d  サイズ:%dx%d" % [
						String(it.get("name","？")), int(it.get("heal",0)),
						int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
					]
				elif t == "food":
					txt = "%s\n種類:食料  腹+%d  サイズ:%dx%d" % [
						String(it.get("name","？")), int(it.get("belly",0)),
						int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
					]
				elif t == "seal":
					txt = "%s\n種類:強化  対象の修正値+1（上限:%d）  サイズ:%dx%d" % [
						String(it.get("name","？")), int(inv.get_max_plus_limit()),
						int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
					]
				elif t == "seal_expand":
					txt = "%s\n種類:拡張  開いている袋の容量を拡張（通常袋のみ） サイズ:%dx%d" % [
						String(it.get("name","？")),
						int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
					]
		var dlg: AcceptDialog = AcceptDialog.new()
		overlay.add_child(dlg)
		dlg.title = "詳細"
		var lb: Label = Label.new()
		lb.text = txt
		lb.autowrap_mode = TextServer.AUTOWRAP_WORD
		dlg.add_child(lb)
		dlg.popup_centered()
	elif id == 43:
		# 使う（袋から）
		if inv != null and inv.pouches.has(pouch_open_id):
			var items: Dictionary = inv.pouches[pouch_open_id]["items"]
			if items.has(pouch_popup_item_id):
				var t: String = String(items[pouch_popup_item_id].get("type",""))
				if t == "seal":
					enhancing = true
					enhance_from = "pouch"
					enhancing_seal_id = pouch_popup_item_id
					enhancing_seal_from_pouch_id = pouch_open_id
					return
				elif t == "seal_expand":
					var okx: bool = inv.apply_expand_from_pouch(pouch_open_id, pouch_popup_item_id)
					if okx:
						_refresh_all()
						if inv.last_use_consumed_turn and main != null:
							main._post_turn_update()
					else:
						_show_info("拡張できません（袋が開いていない／最大 or 合成袋）。")
					return
		if inv.use_item_from_pouch(pouch_open_id, pouch_popup_item_id):
			_refresh_all()
			if inv.last_use_consumed_turn and main != null:
				main._post_turn_update()

# 装備欄：タップ
func _on_equip_button(slot: String) -> void:
	equip_popup_slot = slot
	var has_item: bool = false
	if slot == "weapon":
		has_item = not inv.equip_weapon.is_empty()
	elif slot == "shield":
		has_item = not inv.equip_shield.is_empty()
	if not has_item:
		_show_info("装備なし")
		return
	var gp: Vector2 = get_viewport().get_mouse_position()
	popup_equip.popup(Rect2i(Vector2i(int(gp.x), int(gp.y)), Vector2i(1, 1)))

func _on_equip_popup_id(id: int) -> void:
	if equip_popup_slot == "":
		return
	if id == 31:
		var txt: String = "不明な装備"
		if equip_popup_slot == "weapon" and not inv.equip_weapon.is_empty():
			var it: Dictionary = inv.equip_weapon
			txt = "%s\n種類:剣  基礎:%d  修正:+%d  サイズ:%dx%d" % [
				String(it.get("name","？")), int(it.get("base",0)), int(it.get("plus",0)),
				int((it.get("size",Vector2i(1,1)) as Vector2i).x), int((it.get("size",Vector2i(1,1)) as Vector2i).y)
			]
		elif equip_popup_slot == "shield" and not inv.equip_shield.is_empty():
			var it2: Dictionary = inv.equip_shield
			txt = "%s\n種類:盾  基礎:%d  修正:+%d  サイズ:%dx%d" % [
				String(it2.get("name","？")), int(it2.get("base",0)), int(it2.get("plus",0)),
				int((it2.get("size",Vector2i(2,2)) as Vector2i).x), int((it2.get("size",Vector2i(2,2)) as Vector2i).y)
			]
		_show_info(txt)
	elif id == 32:
		var ok2: bool = inv.unequip_to_bag(equip_popup_slot)
		if not ok2:
			_show_info("バッグに空きがありません。")
		_refresh_all()

# 袋トグル通知
func _on_pouch_toggled(open: bool, id: int) -> void:
	pouch_open = open
	pouch_open_id = id
	_update_pouch_visibility()
	_refresh_pouch_grid()
	_refresh_bag_grid() # ★ 開いている袋のハイライトを更新

# モード終了
func _end_move_success() -> void:
	_refresh_all()
	if main != null:
		main.recalc_memory_visible()
	_cancel_move_mode()

func _end_move_fail(msg: String) -> void:
	_show_info(msg)
	_cancel_move_mode()

func _cancel_move_mode() -> void:
	moving = false
	moving_src_kind = ""
	moving_item_id = -1
	moving_src_ground_cell = Vector2i.ZERO
	moving_src_pouch_id = -1

func _cancel_enhance_mode() -> void:
	enhancing = false
	enhance_from = ""
	enhancing_seal_id = -1
	enhancing_seal_from_pouch_id = -1

# ユーティリティ
func _show_info(text: String) -> void:
	var dlg: AcceptDialog = AcceptDialog.new()
	overlay.add_child(dlg)
	dlg.title = "情報"
	var lb: Label = Label.new()
	lb.text = text
	lb.autowrap_mode = TextServer.AUTOWRAP_WORD
	dlg.add_child(lb)
	dlg.popup_centered()
