extends Node
class_name Status

signal leveled_up(new_level: int)

var hp: int = 0
var max_hp: int = 0
var level: int = 1
var xp: int = 0
var belly: int = 0
var belly_max: int = 0
var atk: int = 0
var def: int = 0

const HUNGER_INTERVAL: int = 10
const STARVATION_DAMAGE: int = 1

func init_defaults() -> void:
	hp = 20
	max_hp = 20
	level = 1
	xp = 0
	belly_max = 100
	belly = belly_max
	atk = 3
	def = 1

func apply_turn_effects(turn_count: int) -> void:
	if belly > 0:
		if hp < max_hp:
			var regen: int = int(ceil(float(max_hp) * 0.01))
			if regen < 1:
				regen = 1
			hp = min(max_hp, hp + regen)
	else:
		hp = max(0, hp - STARVATION_DAMAGE)

	if (turn_count % HUNGER_INTERVAL) == 0:
		if belly > 0:
			belly = max(0, belly - 1)

# --- レベルアップ関連 ---
func _xp_required(lv: int) -> int:
	# 必要経験値を従来の2倍に
	return 10 * lv

func get_xp_to_next() -> int:
	var need: int = _xp_required(level)
	var rem: int = need - xp
	if rem < 0:
		rem = 0
	return rem

func gain_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var changed: bool = false
	while xp >= _xp_required(level):
		xp -= _xp_required(level)
		level += 1
		# （必要なら能力上昇をここに）
		changed = true
	if changed:
		leveled_up.emit(level)
