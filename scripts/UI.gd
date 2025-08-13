extends Control
class_name UI

const RESERVED_MIN_H: int = 320
const MENU_ID_FURN_ONLY: int = 1

var main: Main
var root_panel: Panel
var vbox: VBoxContainer
var status_label: Label
var buttons: HBoxContainer
var btn_wait: Button
var btn_item: Button
var btn_stairs: Button
var btn_auto: Button
var btn_menu: Button
var menu: PopupMenu
var _status_connected: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	root_panel = Panel.new()
	add_child(root_panel)
	root_panel.anchor_left = 0.0
	root_panel.anchor_top = 0.0
	root_panel.anchor_right = 0.0
	root_panel.anchor_bottom = 0.0
	root_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	vbox = VBoxContainer.new()
	root_panel.add_child(vbox)
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 0.0
	vbox.offset_top = 0.0
	vbox.offset_right = 0.0
	vbox.offset_bottom = 0.0
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_theme_constant_override("separation", 10)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.custom_minimum_size = Vector2(0, 48)
	status_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(status_label)

	buttons = HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.mouse_filter = Control.MOUSE_FILTER_STOP
	buttons.add_theme_constant_override("separation", 8)
	vbox.add_child(buttons)

	btn_wait = Button.new()
	btn_wait.text = "待機"
	btn_wait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_wait.custom_minimum_size = Vector2(0, 60)
	btn_wait.add_theme_font_size_override("font_size", 20)
	buttons.add_child(btn_wait)
	btn_wait.pressed.connect(_on_wait_pressed)

	btn_item = Button.new()
	btn_item.text = "道具"
	btn_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_item.custom_minimum_size = Vector2(0, 60)
	btn_item.add_theme_font_size_override("font_size", 20)
	buttons.add_child(btn_item)
	btn_item.pressed.connect(_on_item_pressed)

	btn_stairs = Button.new()
	btn_stairs.text = "階段"
	btn_stairs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_stairs.custom_minimum_size = Vector2(0, 60)
	btn_stairs.add_theme_font_size_override("font_size", 20)
	buttons.add_child(btn_stairs)
	btn_stairs.pressed.connect(_on_stairs_pressed)

	btn_auto = Button.new()
	btn_auto.text = "自動"
	btn_auto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_auto.custom_minimum_size = Vector2(0, 60)
	btn_auto.add_theme_font_size_override("font_size", 20)
	btn_auto.toggle_mode = true
	buttons.add_child(btn_auto)
	btn_auto.toggled.connect(_on_auto_toggled)

	btn_menu = Button.new()
	btn_menu.text = "メニュー"
	btn_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_menu.custom_minimum_size = Vector2(0, 60)
	btn_menu.add_theme_font_size_override("font_size", 20)
	buttons.add_child(btn_menu)
	btn_menu.pressed.connect(_on_menu_pressed)

	# メニュー（家具のみ拾うトグル）
	menu = PopupMenu.new()
	add_child(menu)
	menu.add_check_item("家具のみ拾う", MENU_ID_FURN_ONLY)
	menu.id_pressed.connect(_on_menu_id_pressed)

	_layout_bottom_panel()
	get_viewport().size_changed.connect(_on_viewport_resized)

	update_status()
	set_process(true)

func _process(delta: float) -> void:
	if not _status_connected and main != null and main.status != null:
		if not main.status.is_connected("stats_changed", Callable(self, "_on_stats_changed")):
			main.status.stats_changed.connect(_on_stats_changed)
		_status_connected = true
		update_status()
		set_process(false)

func _on_stats_changed() -> void:
	update_status()

func _on_viewport_resized() -> void:
	_layout_bottom_panel()

func _layout_bottom_panel() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var h: float = float(RESERVED_MIN_H)
	root_panel.size = Vector2(vp.x, h)
	root_panel.position = Vector2(0.0, vp.y - h)
	root_panel.visible = true

func get_reserved_height() -> int:
	var h: float = root_panel.size.y
	if h <= 1.0:
		return RESERVED_MIN_H
	return int(ceil(h))

func update_status() -> void:
	if main == null:
		return
	var need: int = main.status.get_xp_to_next()
	status_label.text = "階: %d    Lv: %d    次Lvまで: %d    HP: %d/%d    腹: %d/%d    攻: %d    防: %d" % [
		main.floor_level,
		main.status.level, need,
		main.status.hp, main.status.max_hp,
		main.status.belly, main.status.belly_max,
		main.status.atk, main.status.def
	]

func _on_wait_pressed() -> void:
	if main != null:
		main.action_wait()

func _on_item_pressed() -> void:
	if main != null:
		main.handle_item()

func _on_stairs_pressed() -> void:
	if main != null:
		main.try_stairs()

func _on_auto_toggled(t: bool) -> void:
	if main != null:
		main.set_auto_mode(t)

func _on_menu_pressed() -> void:
	if main == null:
		return
	_sync_menu_checks()
	menu.popup()

func _sync_menu_checks() -> void:
	if main == null:
		return
	menu.set_item_checked(menu.get_item_index(MENU_ID_FURN_ONLY), main.auto_pick_furniture_only)

func _on_menu_id_pressed(id: int) -> void:
	if main == null:
		return
	if id == MENU_ID_FURN_ONLY:
		main.auto_pick_furniture_only = not main.auto_pick_furniture_only
		_sync_menu_checks()

func _on_menu_pressed_deprecated() -> void:
	# 互換用（未使用）
	pass
