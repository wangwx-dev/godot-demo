class_name ModuleConstruction
extends MapModule
## 工地：钢架+建材堆成的窄巷迷阵——资源最密、地形最险。


func _setup() -> void:
	theme_name = "工地"
	obstacles = [
		[Rect2(280, 280, 500, 80), Color(0.40, 0.36, 0.24)],   # 钢梁堆
		[Rect2(280, 280, 80, 460), Color(0.40, 0.36, 0.24)],
		[Rect2(700, 480, 80, 400), Color(0.38, 0.34, 0.26)],   # 脚手架
		[Rect2(880, 280, 180, 120), Color(0.35, 0.33, 0.28)],  # 板房
		[Rect2(420, 880, 260, 90), Color(0.38, 0.34, 0.26)],   # 建材堆
	]
	supply_slots = [Vector2(520, 560), Vector2(960, 640), Vector2(200, 1050)]
	vehicle_slots = [Vector2(1080, 1080)]
	bandage_slots = [Vector2(560, 200)]
	spawn_slots = [Vector2(160, 160)]
