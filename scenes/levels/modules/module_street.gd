class_name ModuleStreet
extends MapModule
## 街区：两排临街房夹一条竖街——通道感最强的模块。


func _setup() -> void:
	theme_name = "街区"
	obstacles = [
		[Rect2(240, 260, 280, 200), Color(0.34, 0.30, 0.28)],
		[Rect2(240, 620, 280, 200), Color(0.31, 0.28, 0.30)],
		[Rect2(760, 260, 280, 200), Color(0.34, 0.30, 0.28)],
		[Rect2(760, 620, 280, 200), Color(0.31, 0.28, 0.30)],
	]
	supply_slots = [Vector2(380, 540), Vector2(900, 540), Vector2(640, 980)]
	vehicle_slots = [Vector2(640, 160)]
	bandage_slots = [Vector2(640, 460), Vector2(1100, 1100)]
	spawn_slots = [Vector2(160, 1120)]
