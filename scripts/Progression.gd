extends Object
class_name Progression

static func add_xp(main: Main, amount: int) -> void:
	if main.status == null:
		return
	main.status.xp += amount
	while main.status.xp >= main.status.level * 10:
		main.status.xp -= main.status.level * 10
		main.status.level += 1
		main.status.max_hp += 5
		main.status.hp = min(main.status.hp + 5, main.status.max_hp)
	main.ui.update_status()
