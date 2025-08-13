extends Node
class_name Combat

var main: Main

func player_attack(idx: int) -> bool:
	if idx < 0 or idx >= main.enemies.size():
		return false
	var e: Dictionary = main.enemies[idx]
	var pos: Vector2i = e["pos"]
	var ep: Vector2i = e["pos"]

	# 斜め角抜けは攻撃不可
	var dx: int = ep.x - main.player.x
	var dy: int = ep.y - main.player.y
	var sx: int = 0
	if dx > 0:
		sx = 1
	elif dx < 0:
		sx = -1
	var sy: int = 0
	if dy > 0:
		sy = 1
	elif dy < 0:
		sy = -1
	if sx != 0 and sy != 0:
		if Movement.diagonal_blocked(main, main.player, Vector2i(sx, sy)):
			return false

	# ダメージ
	var dmg: int = max(1, main.status.atk)
	e["hp"] = int(e["hp"]) - dmg
	main.enemies[idx] = e
	main.gfx.add_flash_cell(ep)
	main.gfx.add_damage_number(ep, dmg)

	# 撃破
	if int(e["hp"]) <= 0:
		main.enemies.remove_at(idx)
		# ★ XP付与（軽め）
		main.status.gain_xp(5)
		ItemSpawner.drop_from_enemy(main, main.rng, pos)

	# 攻撃は1ターン消費
	main._post_turn_update()
	return true

func enemy_attack(idx: int) -> void:
	if idx < 0 or idx >= main.enemies.size():
		return
	var e: Dictionary = main.enemies[idx]
	var dmg: int = max(1, int(e.get("atk", 1)) - main.status.def)
	main.status.hp = max(0, main.status.hp - dmg)
	main.gfx.add_damage_number(main.player, dmg)
	main.gfx.flash_player_now()
