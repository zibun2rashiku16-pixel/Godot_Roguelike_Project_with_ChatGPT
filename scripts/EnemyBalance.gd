extends Object
class_name EnemyBalance

static func apply(e: Dictionary, fl: int) -> void:
	# ---- base（上げた既定値）----
	# 各敵に base_* が入っていればそれを優先。無ければ既定値を使う。
	var base_hp: int = int(e.get("base_hp", 8))      # 既定HPベース（↑強化）
	var base_atk: int = int(e.get("base_atk", 4))    # 既定攻撃ベース（↑強化）
	var base_def: int = int(e.get("base_def", 0))
	var base_xp: int = int(e.get("base_xp", 3))      # ★与EXPベース=3 に固定

	# ---- 階依存スケール ----
	var fl_clamped: int = max(fl, 1)
	var fl_f: float = float(fl_clamped)
	var hpmax: int = base_hp + 2 * fl_clamped
	var atk: int = base_atk + int(ceil(0.8 * fl_f))
	var df: int = base_def + int(floor(0.4 * fl_f))
	var xp: int = base_xp + fl_clamped

	# ---- 反映（未指定なら自動初期化）----
	e["hpmax"] = hpmax
	e["hp"] = min(int(e.get("hp", hpmax)), hpmax)
	e["atk"] = atk
	e["def"] = df
	e["xp"] = xp
	e["scaled"] = true
