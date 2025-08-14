extends Node
class_name Combat

# Main への参照
var main: Main

# 撃破時に得られる経験値のベース値（ご要望：3）
const KILL_EXP_BASE: int = 3

#---------------------------------------
# プレイヤーが敵（インデックス指定）を攻撃
# 成功時 true を返す
# - 撃破時：ベース3 + 敵固有xp(任意) を付与、ドロップ抽選、敵を除去
# - 生存時：その場で敵が即時反撃
#---------------------------------------
func player_attack(idx: int) -> bool:
	# 参照・範囲チェック
	if main == null:
		return false
	if idx < 0 or idx >= main.enemies.size():
		return false

	# 対象取得
	var e: Dictionary = main.enemies[idx]
	var ep: Vector2i = e.get("pos", Vector2i.ZERO)

	# ダメージ計算と適用
	var dmg: int = _calc_player_damage()
	var hp_now: int = int(e.get("hp", 1))
	var hp_next: int = hp_now - dmg
	e["hp"] = hp_next

	# 演出（ダメージ数表示・ヒットフラッシュ）
	if main.gfx != null:
		main.gfx.add_damage_number(ep, dmg)
		main.gfx.add_flash_cell(ep)

	# 撃破判定
	var dead: bool = hp_next <= 0
	if dead:
		# ★ 経験値：ベース3 + 敵側ボーナス（"xp" があれば加算）
		var xp_gain: int = KILL_EXP_BASE
		var xp_bonus: int = int(e.get("xp", 0))
		xp_gain += xp_bonus
		main.status.gain_xp(xp_gain)

		# ドロップ（既存仕様：30%）
		ItemSpawner.drop_loot(main, ep, main.rng)

		# 敵除去
		main.enemies.remove_at(idx)
	else:
		# 敵が生存していれば更新して即時反撃
		main.enemies[idx] = e
		enemy_attack(idx)

	return true

#---------------------------------------
# 敵の攻撃（インデックス指定）
# 成功時 true
#---------------------------------------
func enemy_attack(eidx: int) -> bool:
	if main == null:
		return false
	if eidx < 0 or eidx >= main.enemies.size():
		return false

	var e: Dictionary = main.enemies[eidx]

	# 敵→プレイヤーへのダメージ
	var dmg: int = _calc_enemy_damage(e)

	# HP減算（最低0まで）
	var hp_now: int = int(main.status.hp)
	var hp_next: int = hp_now - dmg
	if hp_next < 0:
		hp_next = 0
	main.status.hp = hp_next

	# 演出（プレイヤーダメージ表示・フラッシュ）
	if main.gfx != null:
		main.gfx.add_damage_number(main.player, dmg)
		main.gfx.flash_player_now()

	return true

#---------------------------------------
# プレイヤー与ダメージ計算（最低1保証）
# ここでは main.status.atk を使用（装備補正はそちらで反映想定）
#---------------------------------------
func _calc_player_damage() -> int:
	var base: int = int(main.status.atk)
	if base < 1:
		base = 1
	return base

#---------------------------------------
# 敵与ダメージ計算（最低1保証）
#---------------------------------------
func _calc_enemy_damage(e: Dictionary) -> int:
	var atk: int = int(e.get("atk", 1))
	var defv: int = int(main.status.def)
	var dmg: int = atk - defv
	if dmg < 1:
		dmg = 1
	return dmg
