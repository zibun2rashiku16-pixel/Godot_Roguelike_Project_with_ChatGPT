extends Object
class_name InputTap

static var _pointer_active: bool = false
static var _pointer_source: String = "" # "touch" or "mouse"

static func process_unhandled_input(main: Main, event: InputEvent) -> void:
	if main.inv_ui != null and main.inv_ui.visible:
		return

	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			if _pointer_active and _pointer_source != "touch":
				return
			if not _pointer_active:
				_pointer_active = true
				_pointer_source = "touch"
				var dir: Vector2i = _tap_to_dir(main, st.position)
				if dir != Vector2i.ZERO:
					Movement.attempt_player_step(main, dir)
		else:
			if _pointer_active and _pointer_source == "touch":
				_pointer_active = false
				_pointer_source = ""
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			if _pointer_active and _pointer_source != "mouse":
				return
			if not _pointer_active:
				_pointer_active = true
				_pointer_source = "mouse"
				var dir2: Vector2i = _tap_to_dir(main, mb.position)
				if dir2 != Vector2i.ZERO:
					Movement.attempt_player_step(main, dir2)
		else:
			if _pointer_active and _pointer_source == "mouse":
				_pointer_active = false
				_pointer_source = ""

static func _tap_to_dir(main: Main, pos: Vector2) -> Vector2i:
	if main == null or main.gfx == null:
		return Vector2i.ZERO

	var tile: int = main.gfx.get_tile_size()
	if tile <= 0:
		return Vector2i.ZERO
	var off: Vector2 = main.gfx.get_draw_offset()

	var map_rect: Rect2 = Rect2(off, Vector2(float(tile * Params.W), float(tile * Params.H)))
	if not map_rect.has_point(pos):
		return Vector2i.ZERO

	var center: Vector2 = off + Vector2(float(main.player.x * tile + tile / 2), float(main.player.y * tile + tile / 2))
	var d: Vector2 = pos - center
	var ax: float = abs(d.x)
	var ay: float = abs(d.y)

	var threshold: float = 4.0
	var sx: int = 0
	if d.x > threshold:
		sx = 1
	elif d.x < -threshold:
		sx = -1
	var sy: int = 0
	if d.y > threshold:
		sy = 1
	elif d.y < -threshold:
		sy = -1

	if sx == 0 and sy == 0:
		return Vector2i.ZERO

	# ★ ここは Params の値そのまま（1.15 を使用）
	var bias: float = Params.TAP_CARDINAL_BIAS
	if sx != 0 and sy != 0:
		if ax > ay * bias:
			sy = 0
		elif ay > ax * bias:
			sx = 0

	return Vector2i(sx, sy)
