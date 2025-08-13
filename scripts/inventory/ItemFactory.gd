extends Node
class_name ItemFactory

func make_item(inv: Inventory, name: String, w: int, h: int, t: String) -> Dictionary:
	var it: Dictionary = {
		"id": inv._alloc_id(),
		"name": name,
		"size": Vector2i(w, h),
		"type": t
	}
	return it

func create_wood_sword(inv: Inventory, plus: int) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "木の剣+" + str(plus), 1, 3, "weapon")
	it["base"] = 1
	it["plus"] = plus
	return it

func create_wood_shield(inv: Inventory, plus: int) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "木の盾+" + str(plus), 2, 2, "shield")
	it["base"] = 1
	it["plus"] = plus
	return it

func create_herb(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "薬草", 1, 1, "potion")
	it["heal"] = 20
	return it

func create_onigiri(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "おにぎり", 1, 1, "food")
	it["belly"] = 50
	return it

# 通常の袋（2×3 本体）／内部 2×4
func create_pouch(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "袋", 2, 3, "pouch")
	it["pouch_w"] = 2
	it["pouch_h"] = 4
	return it

# 合成の袋（2×3 本体）／内部 2×4
func create_fusion_pouch(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "合成の袋", 2, 3, "pouch_fusion")
	it["pouch_w"] = 2
	it["pouch_h"] = 4
	return it

func create_enhance_seal(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "強化のシール", 1, 1, "seal")
	return it

func create_expand_seal(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "拡張のシール", 1, 1, "seal_expand")
	return it

# ★ 家具（ダンジョン内では機能なし。拠点で機能。サイズ 2×3）
func create_furniture(inv: Inventory) -> Dictionary:
	var it: Dictionary = self.make_item(inv, "家具", 2, 3, "furniture")
	return it
