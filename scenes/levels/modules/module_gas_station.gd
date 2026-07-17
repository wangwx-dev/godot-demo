class_name ModuleGasStation
extends MapModule
## 加油站：顶棚岛+便利店，油罐区是天然掩体阵。


func _setup() -> void:
	theme_name = "加油站"
	obstacles = [
		[Rect2(480, 300, 320, 140), Color(0.36, 0.30, 0.26)],  # 便利店
		[Rect2(430, 620, 90, 90), Color(0.42, 0.24, 0.22)],    # 油罐 ×3
		[Rect2(600, 660, 90, 90), Color(0.42, 0.24, 0.22)],
		[Rect2(770, 620, 90, 90), Color(0.42, 0.24, 0.22)],
	]
	supply_slots = [Vector2(640, 500), Vector2(300, 900), Vector2(980, 900)]
	vehicle_slots = [Vector2(1080, 200)]
	bandage_slots = [Vector2(640, 1080)]
	spawn_slots = [Vector2(180, 180)]
