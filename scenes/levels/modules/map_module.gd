class_name MapModule
extends Node2D
## 手工地图模块基类（mapgen-design：1280×1280、四边开放边界、内部障碍+插槽）。
## MVP 用脚本声明障碍矩形与插槽点位（正式素材期换 .tscn 手工场景，接口不变）。
## 插槽坐标为模块本地系；拼接器负责旋转/镜像变换后取全局插槽。

const SIZE: float = 1280.0

## 子类在 _setup() 里填充。障碍：[Rect2 本地矩形, Color]；插槽：本地坐标数组。
var obstacles: Array = []
var supply_slots: Array[Vector2] = []       ## 资源点槽 ×2~4
var vehicle_slots: Array[Vector2] = []      ## 载具槽 ×1~2（M6 用，先建档）
var bandage_slots: Array[Vector2] = []      ## 绷带槽 ×1~2
var spawn_slots: Array[Vector2] = []        ## 玩家投放槽 ×1

var theme_name: String = ""


func _ready() -> void:
	_setup()
	_build_obstacle_bodies()
	queue_redraw()


## 子类实现：声明主题、障碍、插槽。
func _setup() -> void:
	pass


## 障碍矩形 → StaticBody2D（层 1，玩家和敌人都撞）。
func _build_obstacle_bodies() -> void:
	if obstacles.is_empty():
		return
	var body: StaticBody2D = StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	for entry in obstacles:
		var rect: Rect2 = entry[0]
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = rect.size
		shape_node.shape = shape
		shape_node.position = rect.get_center()
		body.add_child(shape_node)
	add_child(body)


## 本地插槽 → 世界坐标（考虑模块自身的位置/旋转/镜像变换）。
func world_slots(slots: Array[Vector2]) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for slot in slots:
		result.append(to_global(slot))
	return result


func _draw() -> void:
	for entry in obstacles:
		var rect: Rect2 = entry[0]
		var color: Color = entry[1]
		draw_rect(rect, color)
		draw_rect(rect, color.darkened(0.35), false, 4.0)
	# 模块名水印（占位识别用）
	draw_string(ThemeDB.fallback_font, Vector2(20, 40), theme_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.18))
