class_name Minimap
extends CanvasLayer
## 迷你图（ui-design：右上常驻）：已探索轮廓（复用迷雾纹理反相）、玩家箭头、
## 已发现资源点/绷带色点。不显示普通敌人与未探索信息。
## 载具图标 M6 接入（"vehicles" 组 + discovered 即自动显示）。

const MAP_SIZE_PX: float = 170.0

var _fog: FogOverlay
var _panel: Control


func setup(fog: FogOverlay) -> void:
	_fog = fog
	layer = 82
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_panel.position = Vector2(-MAP_SIZE_PX - 16, 52)  # 警戒条下方
	_panel.custom_minimum_size = Vector2(MAP_SIZE_PX, MAP_SIZE_PX)
	_panel.size = Vector2(MAP_SIZE_PX, MAP_SIZE_PX)
	_panel.draw.connect(_on_panel_draw)
	add_child(_panel)


func _physics_process(_delta: float) -> void:
	if _panel != null:
		_panel.queue_redraw()


func _to_map(world_pos: Vector2) -> Vector2:
	var ratio: Vector2 = (world_pos - _fog.map_rect.position) / _fog.map_rect.size
	return Vector2(ratio.x, ratio.y) * MAP_SIZE_PX


func _on_panel_draw() -> void:
	if _fog == null:
		return
	# 底：全黑（未探索）
	_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE_PX, MAP_SIZE_PX)), Color(0.02, 0.02, 0.03, 0.9))
	# 已探索轮廓：迷雾纹理当遮罩画不划算，直接低采样扫 explored 网格
	var step: int = 4  # 每 4 迷雾格采 1 点（20px×4=80px 世界精度，轮廓够用）
	var cell_px: float = MAP_SIZE_PX / (_fog.map_rect.size.x / (FogOverlay.CELL * step))
	for y in range(0, int(_fog.map_rect.size.y / FogOverlay.CELL), step):
		for x in range(0, int(_fog.map_rect.size.x / FogOverlay.CELL), step):
			var world: Vector2 = _fog.map_rect.position + Vector2(x + 0.5, y + 0.5) * FogOverlay.CELL
			if _fog.is_explored(world):
				var map_pos: Vector2 = _to_map(world)
				_panel.draw_rect(Rect2(map_pos, Vector2(cell_px, cell_px)), Color(0.35, 0.36, 0.33, 0.55))
	# 已发现资源点/绷带/载具
	for entry in [["resource_points", Color(0.95, 0.8, 0.2)], ["bandages", Color(0.9, 0.35, 0.3)], ["vehicles", Color(0.3, 0.9, 0.5)], ["rescue_points", Color(0.35, 0.85, 0.95)]]:
		for node in _panel.get_tree().get_nodes_in_group(entry[0]):
			var node_2d: Node2D = node as Node2D
			if node_2d == null or node_2d.get("discovered") != true:
				continue
			_panel.draw_circle(_to_map(node_2d.global_position), 3.0, entry[1])
	# 玩家箭头
	var player: Player = _panel.get_tree().get_first_node_in_group("player") as Player
	if player != null and is_instance_valid(player):
		var pos: Vector2 = _to_map(player.global_position)
		var dir: float = player.velocity.angle() if player.velocity.length() > 10.0 else -PI / 2.0
		var points: PackedVector2Array = PackedVector2Array([
			pos + Vector2(6, 0).rotated(dir),
			pos + Vector2(-4, 4).rotated(dir),
			pos + Vector2(-4, -4).rotated(dir),
		])
		_panel.draw_colored_polygon(points, Color(0.95, 0.95, 0.9))
	# 边框
	_panel.draw_rect(Rect2(Vector2.ZERO, Vector2(MAP_SIZE_PX, MAP_SIZE_PX)), Color(0.5, 0.5, 0.45), false, 2.0)
