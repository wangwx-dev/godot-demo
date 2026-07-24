class_name FogOverlay
extends Sprite2D
## 战争迷雾（图内生命周期，tech-design §2）：未探索全黑、已探索半暗记忆、
## 光圈内全亮。低分辨率 Image 遮罩拉伸盖图（20px/格），10Hz 更新省性能。
## 兼职"发现"判定：光圈扫到资源点/绷带/载具时置 discovered（迷你图读）。

const CELL: float = 20.0
const LIGHT_RADIUS: float = 340.0
const EXPLORED_ALPHA: float = 0.62
const UPDATE_INTERVAL: float = 0.1

var map_rect: Rect2

var _grid_w: int
var _grid_h: int
var _image: Image
var _texture: ImageTexture
var _explored: PackedByteArray
var _timer: float = 0.0
var _player: Player


func setup(rect: Rect2) -> void:
	map_rect = rect
	_grid_w = ceili(rect.size.x / CELL)
	_grid_h = ceili(rect.size.y / CELL)
	_image = Image.create(_grid_w, _grid_h, false, Image.FORMAT_RGBA8)
	_image.fill(Color(0, 0, 0, 1))
	_explored = PackedByteArray()
	_explored.resize(_grid_w * _grid_h)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	centered = false
	position = rect.position
	scale = Vector2(CELL, CELL)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	z_index = 60  # 盖过实体，HUD 在 CanvasLayer 更上层
	_player = get_tree().get_first_node_in_group("player") as Player
	_refresh()


## 迷你图用：已探索纹理（黑=未探索，透明度低=已探索/光圈）。
func fog_texture() -> ImageTexture:
	return _texture


func is_explored(world_pos: Vector2) -> bool:
	var cell: Vector2i = _to_cell(world_pos)
	if cell.x < 0 or cell.y < 0 or cell.x >= _grid_w or cell.y >= _grid_h:
		return false
	return _explored[cell.y * _grid_w + cell.x] != 0


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = UPDATE_INTERVAL
	_refresh()


func _refresh() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var center: Vector2i = _to_cell(_player.global_position)
	var radius_cells: int = ceili(LIGHT_RADIUS / CELL)
	# 上一帧光圈回落为"已探索半暗"：直接重刷光圈邻域两倍范围（含旧光圈）
	for y in range(maxi(center.y - radius_cells * 2, 0), mini(center.y + radius_cells * 2 + 1, _grid_h)):
		for x in range(maxi(center.x - radius_cells * 2, 0), mini(center.x + radius_cells * 2 + 1, _grid_w)):
			var index: int = y * _grid_w + x
			var distance: float = Vector2(center - Vector2i(x, y)).length() * CELL
			if distance <= LIGHT_RADIUS:
				_explored[index] = 1
				# 光圈边缘 20% 渐变
				var edge: float = clampf((distance - LIGHT_RADIUS * 0.8) / (LIGHT_RADIUS * 0.2), 0.0, 1.0)
				_image.set_pixel(x, y, Color(0, 0, 0, edge * EXPLORED_ALPHA))
			elif _explored[index] != 0:
				_image.set_pixel(x, y, Color(0, 0, 0, EXPLORED_ALPHA))
	_texture.update(_image)
	_discover_points()


## 光圈内的可发现物打标（迷你图渲染依据）。
func _discover_points() -> void:
	for group_name in ["resource_points", "bandages", "vehicles", "rescue_points"]:
		for node in get_tree().get_nodes_in_group(group_name):
			var node_2d: Node2D = node as Node2D
			if node_2d == null or node_2d.get("discovered") == true:
				continue
			if _player.global_position.distance_to(node_2d.global_position) <= LIGHT_RADIUS:
				node_2d.set("discovered", true)


func _to_cell(world_pos: Vector2) -> Vector2i:
	var local: Vector2 = (world_pos - map_rect.position) / CELL
	return Vector2i(local)
