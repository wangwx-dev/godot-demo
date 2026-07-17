class_name ModuleParking
extends MapModule
## 停车场：废车阵列——走位缝隙多，视线碎。


func _setup() -> void:
	theme_name = "停车场"
	obstacles = []
	# 3×3 废车阵（错位摆放留缝）
	for row in 3:
		for col in 3:
			var pos: Vector2 = Vector2(280 + col * 300, 320 + row * 280)
			pos.x += 60 if row % 2 == 1 else 0
			obstacles.append([Rect2(pos.x, pos.y, 140, 70), Color(0.30, 0.32, 0.36)])
	supply_slots = [Vector2(640, 640), Vector2(1050, 300)]
	vehicle_slots = [Vector2(200, 1080), Vector2(1080, 1080)]
	bandage_slots = [Vector2(200, 300)]
	spawn_slots = [Vector2(640, 1150)]
