class_name ModulePark
extends MapModule
## 公园：开阔草地+零星树丛——最空旷，涌潮最凶险的地形。


func _setup() -> void:
	theme_name = "公园"
	obstacles = [
		[Rect2(300, 300, 120, 120), Color(0.22, 0.34, 0.24)],
		[Rect2(860, 380, 120, 120), Color(0.22, 0.34, 0.24)],
		[Rect2(540, 760, 120, 120), Color(0.22, 0.34, 0.24)],
		[Rect2(320, 900, 100, 100), Color(0.22, 0.34, 0.24)],
	]
	supply_slots = [Vector2(640, 400), Vector2(1000, 1000)]
	vehicle_slots = [Vector2(1100, 200)]
	bandage_slots = [Vector2(200, 640), Vector2(880, 700)]
	spawn_slots = [Vector2(640, 640)]
