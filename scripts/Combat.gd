extends Node
class_name Combat

var main: Main

# --- 内部ユーティリティ ---
func _enemy_index_at(pos: Vector2i) -> int:
	for i: int in range(main.enemies.size()):
		var e: Dictionary = main.enemies[i]
		var ep: Vector2i = e.get("pos", Vector2i(-1, -1))
		if ep == pos:
			return i
	return -1

func _is_adjacent_4(a: Vector2i, b: Vector2i) -> bool:
	var dx: int = abs(a.x - b.x)
	var dy: int = abs(a.y - b.y)
	return (dx + dy) == 1

# プレイヤーが敵 idx を攻撃。行動消費なら true。
func player_attack(idx: int) -> bool:
	if main == null:
		return false
	if idx < 0 or idx >= main.enemies.size():
		return false

	var e: Dictionary = main.enemies[idx]
	var pos: Vector2i = e.get("pos", Vector2i.ZERO)

	var base_dmg: int = max(1, int(main.status.atk))
	var jitter: int = 0
	if main.rng != null:
		jitter = int(round(main.rng.randf_range(-0.5, 0.5)))
	var dmg: int = max(1, base_dmg + jitter)

	e["hp"] = int(e.get("hp", 1)) - dmg
	main.gfx.add_damage_number(pos, dmg)

	# 撃破処理
	if int(e["hp"]) <= 0:
		var xp_gain: int = int(e.get("xp", 1))
		main.status.gain_xp(xp_gain)
		main.enemies.remove_at(idx)
		# 撃破ドロップ：30%
		if main.rng != null:
			ItemSpawner.drop_item_with_chance(main, main.rng, pos, 0.30)
		main.recalc_memory_visible()
		return true

	# 生存していれば即時反撃（隣接時のみ）
	if _is_adjacent_4(pos, main.player):
		enemy_attack_player(idx)

	# HP 反映（辞書は参照だが明示更新）
	main.enemies[idx] = e
	return true

# 互換用エントリ：引数の型に応じて攻撃
# - int       : 敵インデックス
# - Vector2i  : 敵の座標
# - Dictionary: {pos: Vector2i, ...} を想定
func enemy_attack(arg) -> bool:
	if main == null:
		return false
	var idx: int = -1
	var t: int = typeof(arg)
	if t == TYPE_INT:
		idx = int(arg)
	elif t == TYPE_VECTOR2I:
		idx = _enemy_index_at(arg)
	elif t == TYPE_DICTIONARY:
		var d: Dictionary = arg
		var p: Vector2i = d.get("pos", Vector2i(-1, -1))
		idx = _enemy_index_at(p)
	if idx < 0 or idx >= main.enemies.size():
		return false
	enemy_attack_player(idx)
	return true

# 敵からプレイヤーへの攻撃
func enemy_attack_player(idx: int) -> void:
	if main == null:
		return
	if idx < 0 or idx >= main.enemies.size():
		return
	var e: Dictionary = main.enemies[idx]
	var atk: int = int(e.get("atk", 1))
	var jitter: int = 0
	if main.rng != null:
		jitter = int(round(main.rng.randf_range(-0.5, 0.5)))
	var dmg: int = max(1, atk + jitter)
	main.status.hp = max(0, main.status.hp - dmg)
	main.gfx.add_damage_number(main.player, dmg)
