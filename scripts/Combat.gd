extends Node
class_name Combat

var main: Main

func player_attack(idx: int) -> bool:
	if main == null:
		return false
	if idx < 0 or idx >= main.enemies.size():
		return false
	var e: Dictionary = main.enemies[idx]
	var ep: Vector2i = e["pos"]
	var dmg: int = _calc_player_damage()
	e["hp"] = int(e.get("hp", 1)) - dmg
	if main.gfx != null:
		main.gfx.add_damage_number(ep, dmg)
		main.gfx.add_flash_cell(ep)
	var dead: bool = int(e["hp"]) <= 0
	if dead:
		var xp_gain: int = int(e.get("xp", 1))
		main.status.gain_xp(xp_gain)
		# 互換性のため、既存の drop_loot を呼ぶ（30%ドロップ）
		ItemSpawner.drop_loot(main, ep, main.rng)
		main.enemies.remove_at(idx)
	else:
		main.enemies[idx] = e
	return true

func enemy_attack(eidx: int) -> bool:
	if main == null:
		return false
	if eidx < 0 or eidx >= main.enemies.size():
		return false
	var e: Dictionary = main.enemies[eidx]
	var dmg: int = _calc_enemy_damage(e)
	main.status.hp = max(0, main.status.hp - dmg)
	if main.gfx != null:
		main.gfx.add_damage_number(main.player, dmg)
		main.gfx.flash_player_now()
	return true

func _calc_player_damage() -> int:
	var base: int = main.status.atk
	if base < 1:
		base = 1
	return base

func _calc_enemy_damage(e: Dictionary) -> int:
	var atk: int = int(e.get("atk", 1))
	var dmg: int = atk - main.status.def
	if dmg < 1:
		dmg = 1
	return dmg
