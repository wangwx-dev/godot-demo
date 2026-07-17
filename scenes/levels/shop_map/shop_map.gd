extends Node2D
## 商店图占位（M6）：进图自动兑换背包（物资唯一变现渠道，economy-design v2）。
## 正式版（M7）补：兑换播报动画 + 2 格货架。本版只做兑换结算文字 + 出口。

const MAP_W: float = 1280.0
const MAP_H: float = 720.0

var _report: String = ""

@onready var player: Player = $Player


func _ready() -> void:
	player.set_camera_limits(Rect2(0, 0, MAP_W, MAP_H))
	player.position = Vector2(180, MAP_H / 2.0)
	_build_walls()
	add_child(EconomyHud.new())
	var redeemed: Array[LootData] = RunState.redeem_backpack()
	if redeemed.is_empty():
		_report = "背包是空的——这趟白跑了"
	else:
		var total: int = 0
		var names: Array[String] = []
		for item in redeemed:
			total += item.value
			names.append(item.display_name)
		_report = "自动兑换：%s → +%d 金" % ["、".join(names), total]
	print("[ShopMap] %s" % _report)
	_place_vehicles()
	queue_redraw()


func _place_vehicles() -> void:
	var candidates: Array[int] = RunState.roll_candidates()
	var spots: Array = [Vector2(1120, 240), Vector2(1120, 480)]
	for i in candidates.size():
		var vehicle: Vehicle = Vehicle.new()
		vehicle.destination = candidates[i]
		vehicle.discovered = true
		vehicle.position = spots[i % spots.size()]
		add_child(vehicle)


func _build_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var specs: Array = [
		[Vector2(MAP_W / 2.0, -30), Vector2(MAP_W + 120, 60)],
		[Vector2(MAP_W / 2.0, MAP_H + 30), Vector2(MAP_W + 120, 60)],
		[Vector2(-30, MAP_H / 2.0), Vector2(60, MAP_H + 120)],
		[Vector2(MAP_W + 30, MAP_H / 2.0), Vector2(60, MAP_H + 120)],
	]
	for spec in specs:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = spec[1]
		shape_node.shape = shape
		shape_node.position = spec[0]
		walls.add_child(shape_node)
	add_child(walls)


func _draw() -> void:
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.4, 0.6, 0.85), false, 6.0)
	draw_string(ThemeDB.fallback_font, Vector2(MAP_W / 2.0 - 100, 60),
			"以物易物点（商店）", HORIZONTAL_ALIGNMENT_CENTER, 200, 26, Color(0.6, 0.75, 0.95))
	draw_string(ThemeDB.fallback_font, Vector2(MAP_W / 2.0 - 320, 120),
			_report, HORIZONTAL_ALIGNMENT_CENTER, 640, 17, Color(0.95, 0.85, 0.4))
	draw_string(ThemeDB.fallback_font, Vector2(MAP_W / 2.0 - 160, 160),
			"（货架 M7 进货）", HORIZONTAL_ALIGNMENT_CENTER, 320, 13, Color(0.6, 0.6, 0.6))
