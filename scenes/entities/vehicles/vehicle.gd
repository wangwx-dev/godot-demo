class_name Vehicle
extends Node2D
## 载具出口（mapgen-design）：迷雾覆盖、靠近发现（目的地牌可读）、
## 按住 E 1.5s 收尾后出发——1.5s 既防误触，也是最后一次"再搜一下？"的犹豫点。
## 松开/走远即中断（被打断细则为待定 2，MVP 先做松手中断）。

const INTERACT_RADIUS: float = 70.0
const BOARD_TIME: float = 1.5

var destination: int = RunState.MapType.BATTLE
var discovered: bool = false:  ## FogOverlay 光圈内置 true → 迷你图常驻绿点
	set(value):
		if value and not discovered:
			Sfx.play("vehicle_found", -6.0)
		discovered = value

var _progress: float = 0.0
var _player: Player


func _ready() -> void:
	add_to_group("vehicles")
	z_index = 5
	# 完好像素车（识别表提取 vehicle_0170 侧视角）——载具是"能开走的希望"，不能用残骸
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/environment/props/vehicle_0170.png")
	add_child(sprite)


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var near: bool = global_position.distance_to(_player.global_position) <= INTERACT_RADIUS
	if near and Input.is_action_pressed("interact"):
		_progress += delta
		if _progress >= BOARD_TIME:
			set_physics_process(false)
			Sfx.play("vehicle_depart", -4.0)
			MapFlow.travel(get_tree(), destination)
			return
	else:
		_progress = 0.0
	queue_redraw()


func _draw() -> void:
	var color: Color = MapFlow.type_color(destination)
	# 目的地牌：类型色小旗 + 文字（车身是贴图子节点）
	draw_rect(Rect2(-42, -46, 84, 20), Color(0.08, 0.08, 0.1, 0.72))
	draw_rect(Rect2(-42, -46, 84, 20), color, false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-40, -31),
			"→ %s" % MapFlow.type_name(destination),
			HORIZONTAL_ALIGNMENT_CENTER, 80, 14, color)
	var near: bool = _player != null and is_instance_valid(_player) 			and global_position.distance_to(_player.global_position) <= INTERACT_RADIUS
	if near:
		draw_string(ThemeDB.fallback_font, Vector2(-60, 52),
				"按住 E 出发", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.9, 0.9, 0.85))
	if _progress > 0.0:
		draw_arc(Vector2.ZERO, 46.0, -PI / 2.0,
				-PI / 2.0 + TAU * (_progress / BOARD_TIME), 24, Color(0.95, 0.95, 0.9), 4.0)
