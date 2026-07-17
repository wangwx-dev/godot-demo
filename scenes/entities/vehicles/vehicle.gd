class_name Vehicle
extends Node2D
## 载具出口（mapgen-design）：迷雾覆盖、靠近发现（目的地牌可读）、
## 按住 E 1.5s 收尾后出发——1.5s 既防误触，也是最后一次"再搜一下？"的犹豫点。
## 松开/走远即中断（被打断细则为待定 2，MVP 先做松手中断）。

const INTERACT_RADIUS: float = 70.0
const BOARD_TIME: float = 1.5

var destination: int = RunState.MapType.BATTLE
var discovered: bool = false  ## FogOverlay 光圈内置 true → 迷你图常驻绿点

var _progress: float = 0.0
var _player: Player


func _ready() -> void:
	add_to_group("vehicles")
	z_index = 5


func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var near: bool = global_position.distance_to(_player.global_position) <= INTERACT_RADIUS
	if near and Input.is_action_pressed("interact"):
		_progress += delta
		if _progress >= BOARD_TIME:
			set_physics_process(false)
			MapFlow.travel(get_tree(), destination)
			return
	else:
		_progress = 0.0
	queue_redraw()


func _draw() -> void:
	var color: Color = MapFlow.type_color(destination)
	# 车身 + 车窗 + 车轮（占位表现，正式皮肤按目的地类型区分——内容期）
	draw_rect(Rect2(-34, -18, 68, 36), Color(0.25, 0.27, 0.3))
	draw_rect(Rect2(-34, -18, 68, 36), color, false, 3.0)
	draw_rect(Rect2(-14, -12, 28, 10), Color(0.5, 0.65, 0.7, 0.8))
	draw_circle(Vector2(-20, 20), 7.0, Color(0.12, 0.12, 0.12))
	draw_circle(Vector2(20, 20), 7.0, Color(0.12, 0.12, 0.12))
	# 目的地牌（MVP 文字牌即可）
	draw_string(ThemeDB.fallback_font, Vector2(-60, -30),
			"→ %s" % MapFlow.type_name(destination),
			HORIZONTAL_ALIGNMENT_CENTER, 120, 15, color)
	var near: bool = _player != null and is_instance_valid(_player) \
			and global_position.distance_to(_player.global_position) <= INTERACT_RADIUS
	if near:
		draw_string(ThemeDB.fallback_font, Vector2(-60, 46),
				"按住 E 出发", HORIZONTAL_ALIGNMENT_CENTER, 120, 13, Color(0.9, 0.9, 0.85))
	if _progress > 0.0:
		draw_arc(Vector2.ZERO, 42.0, -PI / 2.0,
				-PI / 2.0 + TAU * (_progress / BOARD_TIME), 24, Color(0.95, 0.95, 0.9), 4.0)
