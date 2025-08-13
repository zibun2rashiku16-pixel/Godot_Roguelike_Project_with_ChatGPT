extends Node
class_name Status

signal leveled_up(new_level: int)
signal stats_changed()

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
	stats_changed.emit()

func apply_turn_effects(turn_count: int) -> void:
	# ★ 自然回復は Main._post_turn_update に集約（ここでは行わない）
	var changed: bool = false

	# 空腹時のダメージ
	if belly <= 0:
		var new_hp: int = max(0, hp - STARVATION_DAMAGE)
		if new_hp != hp:
			hp = new_hp
			changed = true

	# 空腹度の減少（一定ターンごと）
	if (turn_count % HUNGER_INTERVAL) == 0:
		if belly > 0:
			var new_belly: int = max(0, belly - 1)
			if new_belly != belly:
				belly = new_belly
				changed = true

	if changed:
		stats_changed.emit()

# --- レベルアップ関連 ---
func _xp_required(lv: int) -> int:
	# 必要経験値（2倍版）
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
		changed = true
	if changed:
		leveled_up.emit(level)
	stats_changed.emit()
