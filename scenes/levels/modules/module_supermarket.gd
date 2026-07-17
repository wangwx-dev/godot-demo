class_name ModuleSupermarket
extends MapModule
## 废弃超市：中央大卖场（可绕行）+ 停车位排。货架区资源多。


func _setup() -> void:
	theme_name = "废弃超市"
	obstacles = [
		[Rect2(400, 380, 480, 300), Color(0.32, 0.30, 0.34)],  # 卖场主体
		[Rect2(300, 800, 160, 60), Color(0.28, 0.27, 0.30)],   # 购物车堆
		[Rect2(820, 800, 160, 60), Color(0.28, 0.27, 0.30)],
	]
	supply_slots = [Vector2(640, 740), Vector2(340, 320), Vector2(940, 320)]
	vehicle_slots = [Vector2(200, 1080)]
	bandage_slots = [Vector2(1080, 640), Vector2(200, 640)]
	spawn_slots = [Vector2(640, 1130)]
