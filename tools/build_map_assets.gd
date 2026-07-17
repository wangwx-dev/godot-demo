extends SceneTree
## 构建脚本：从图集清单生成 map_tileset.tres，并程序化搭建 6 个 1280×1280 主题地图模块
## （手工编排布局，烘焙成 .tscn 供编辑器后续手调）。运行方式：
##   godot --headless --path . --import           # 先导入图集资源
##   godot --headless --path . --script res://tools/build_map_assets.gd
## 素材来源：Zombie Apocalypse Tileset (Ittai Manero)，由 tools/import_environment_assets.ps1 导入。

const TILE: int = 32
const CELLS: int = 40  # 40×40 格 = 1280×1280（mapgen-design 模块规格）
const ATLAS_PNG: String = "res://assets/sprites/environment/tileset_ground.png"
const MANIFEST_PATH: String = "res://assets/sprites/environment/tileset_ground.json"
const PROP_DIR: String = "res://assets/sprites/environment/props/"
const MODULE_DIR: String = "res://scenes/levels/modules/tiled/"
const DATA_DIR: String = "res://resources/modules/tiled/"
const MODULE_SCRIPT: String = "res://scenes/levels/modules/map_module_tiled.gd"

const MapModuleDataScript = preload("res://resources/map_module_data.gd")

var coords: Dictionary = {}  # tile 名 -> 图集坐标 Vector2i
var tileset: TileSet
var _prop_seq: int = 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODULE_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DATA_DIR))
	_build_tileset()
	_build_all_modules()
	print("[build_map_assets] 全部完成")
	quit(0)


# ---------------------------------------------------------------- TileSet

func _build_tileset() -> void:
	var txt: String = FileAccess.get_file_as_string(MANIFEST_PATH)
	if txt.length() > 0 and txt.unicode_at(0) == 0xFEFF:
		txt = txt.substr(1)
	var manifest: Dictionary = JSON.parse_string(txt)
	assert(manifest != null, "清单解析失败")

	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	src.texture = load(ATLAS_PNG)
	src.texture_region_size = Vector2i(TILE, TILE)

	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)  # 层 1 = 墙体/障碍（玩家 mask 5、敌人 mask 7 都撞）
	tileset.set_physics_layer_collision_mask(0, 0)
	tileset.add_source(src, 0)

	var full_cell: PackedVector2Array = PackedVector2Array([
		Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16)
	])
	for t in manifest["tiles"]:
		var c: Vector2i = Vector2i(int(t["x"]), int(t["y"]))
		src.create_tile(c)
		coords[t["name"]] = c
		if int(t["solid"]) == 1:
			var td: TileData = src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, full_cell)

	var err: int = ResourceSaver.save(tileset, "res://resources/map_tileset.tres")
	assert(err == OK, "TileSet 保存失败")
	print("[build_map_assets] map_tileset.tres：%d tiles" % coords.size())


# ---------------------------------------------------------------- 模块骨架

func _new_ctx(module_name: String) -> Dictionary:
	var root: Node2D = Node2D.new()
	root.name = module_name.to_pascal_case()
	var ground: TileMapLayer = TileMapLayer.new()
	ground.name = "Ground"
	ground.tile_set = tileset
	var deco: TileMapLayer = TileMapLayer.new()
	deco.name = "Deco"
	deco.tile_set = tileset
	var obst: TileMapLayer = TileMapLayer.new()
	obst.name = "Obstacles"
	obst.tile_set = tileset
	var props: Node2D = Node2D.new()
	props.name = "Props"
	var slots: Node2D = Node2D.new()
	slots.name = "Slots"
	root.add_child(ground)
	root.add_child(deco)
	root.add_child(obst)
	root.add_child(props)
	root.add_child(slots)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(module_name)  # 布局烘焙用固定种子：每次构建产物一致（"手工模块"）
	return {"root": root, "ground": ground, "deco": deco, "obst": obst, "props": props, "slots": slots, "rng": rng}


func _save_module(ctx: Dictionary, module_name: String, display_name: String, theme: String) -> void:
	var root: Node2D = ctx["root"]
	# 挂 MapModuleTiled：接入 MapAssembler 的 MapModule 接口（插槽从 Marker2D 分组读取）
	root.set_script(load(MODULE_SCRIPT))
	_own(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	assert(err == OK, "pack 失败：" + module_name)
	var scene_path: String = MODULE_DIR + module_name + ".tscn"
	err = ResourceSaver.save(packed, scene_path)
	assert(err == OK, "场景保存失败：" + module_name)

	var data: Resource = MapModuleDataScript.new()
	data.display_name = display_name
	data.theme_name = theme
	data.scene = load(scene_path)
	err = ResourceSaver.save(data, DATA_DIR + module_name + ".tres")
	assert(err == OK, "模块数据保存失败：" + module_name)
	print("[build_map_assets] %s（%s）完成" % [module_name, display_name])
	root.free()


func _own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		_own(child, root)


# ---------------------------------------------------------------- 绘制原语

func _g(ctx: Dictionary, x: int, y: int, n: String) -> void:
	ctx["ground"].set_cell(Vector2i(x, y), 0, coords[n])


func _d(ctx: Dictionary, x: int, y: int, n: String) -> void:
	ctx["deco"].set_cell(Vector2i(x, y), 0, coords[n])


func _o(ctx: Dictionary, x: int, y: int, n: String) -> void:
	ctx["obst"].set_cell(Vector2i(x, y), 0, coords[n])


func _occupied(ctx: Dictionary, x: int, y: int) -> bool:
	return ctx["obst"].get_cell_source_id(Vector2i(x, y)) != -1


## 底层泥地：加权随机变体
func _fill_base(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for y in range(CELLS):
		for x in range(CELLS):
			var r: float = rng.randf()
			var n: String = "dirt_a"
			if r > 0.55 and r <= 0.85:
				n = "dirt_b"
			elif r > 0.85 and r <= 0.93:
				n = "dirt_twigs_a"
			elif r > 0.93:
				n = "dirt_twigs_b"
			_g(ctx, x, y, n)


## 横向沥青路（5 格高：上边线/路面/中线/路面/下边线）
func _road_h(ctx: Dictionary, y0: int, x0: int = 0, x1: int = CELLS - 1) -> void:
	for x in range(x0, x1 + 1):
		_g(ctx, x, y0, "road_edge_h_top")
		_g(ctx, x, y0 + 1, "road_plain")
		_g(ctx, x, y0 + 2, "road_line_h_mid")
		_g(ctx, x, y0 + 3, "road_plain")
		_g(ctx, x, y0 + 4, "road_edge_h_bottom")


## 纵向沥青路
func _road_v(ctx: Dictionary, x0: int, y0: int = 0, y1: int = CELLS - 1) -> void:
	for y in range(y0, y1 + 1):
		_g(ctx, x0, y, "road_edge_v_left")
		_g(ctx, x0 + 1, y, "road_plain")
		_g(ctx, x0 + 2, y, "road_dash_v")
		_g(ctx, x0 + 3, y, "road_plain")
		_g(ctx, x0 + 4, y, "road_edge_v_right")


## 横路上的斑马线（两列宽，竖条纹 tile）
func _crosswalk_on_road_h(ctx: Dictionary, x: int, y0: int) -> void:
	for dx in range(2):
		_g(ctx, x + dx, y0 + 1, "road_cross_v_a")
		_g(ctx, x + dx, y0 + 2, "road_cross_v_b")
		_g(ctx, x + dx, y0 + 3, "road_cross_v_c")


## 纵路上的斑马线（两行高，横条纹 tile）
func _crosswalk_on_road_v(ctx: Dictionary, x0: int, y: int) -> void:
	for dy in range(2):
		_g(ctx, x0 + 1, y + dy, "road_cross_h_a")
		_g(ctx, x0 + 2, y + dy, "road_cross_h_b")
		_g(ctx, x0 + 3, y + dy, "road_cross_h_a")


func _manholes(ctx: Dictionary, count: int, y0: int, x0: int = 2, x1: int = CELLS - 3) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for i in range(count):
		var x: int = rng.randi_range(x0, x1)
		_g(ctx, x, y0 + 1 + rng.randi_range(0, 1) * 2, "road_manhole")


## 泥土小径（横，2 格宽）
func _path_h(ctx: Dictionary, y0: int, x0: int = 0, x1: int = CELLS - 1) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for x in range(x0, x1 + 1):
		_g(ctx, x, y0, "path_h")
		_g(ctx, x, y0 + 1, "path_h" if rng.randf() < 0.8 else "path_patch")


## 泥土小径（纵，2 格宽）
func _path_v(ctx: Dictionary, x0: int, y0: int = 0, y1: int = CELLS - 1) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for y in range(y0, y1 + 1):
		_g(ctx, x0, y, "path_v")
		_g(ctx, x0 + 1, y, "path_v" if rng.randf() < 0.8 else "path_patch")


## 农田块：庄稼行与垄沟交替
func _crop_field(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, grown: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_g(ctx, x, y, grown if y % 2 == 0 else "crops_tilled")


## 矮木围栏矩形（gaps 里的格子留口）
func _rail_rect(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, gaps: Array) -> void:
	for x in range(x0, x1 + 1):
		for y in [y0, y1]:
			if Vector2i(x, y) in gaps:
				continue
			var n: String = "rail_h_plain"
			if x == x0:
				n = "rail_h_left"
			elif x == x1:
				n = "rail_h_right"
			_o(ctx, x, y, n)
	for y in range(y0 + 1, y1):
		for x in [x0, x1]:
			if Vector2i(x, y) in gaps:
				continue
			_o(ctx, x, y, "rail_v_a" if y % 2 == 0 else "rail_v_b")


## 白桩栅栏矩形（花园）
func _picket_rect(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, gaps: Array) -> void:
	for x in range(x0 + 1, x1):
		for y in [y0, y1]:
			if Vector2i(x, y) in gaps:
				continue
			_o(ctx, x, y, "picket_g" if x % 2 == 0 else "picket_h")
	for y in range(y0 + 1, y1):
		for x in [x0, x1]:
			if Vector2i(x, y) in gaps:
				continue
			_o(ctx, x, y, "picket_e" if y % 2 == 0 else "picket_f")
	_o(ctx, x0, y0, "picket_a")
	_o(ctx, x1, y0, "picket_b")
	_o(ctx, x0, y1, "picket_c")
	_o(ctx, x1, y1, "picket_d")


## 木板院墙矩形（谷仓院）
func _board_rect(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, gaps: Array) -> void:
	var pieces: Array = ["board_a", "board_b", "board_c", "board_f", "board_g", "board_h"]
	var rng: RandomNumberGenerator = ctx["rng"]
	for x in range(x0, x1 + 1):
		for y in [y0, y1]:
			if Vector2i(x, y) in gaps:
				continue
			_o(ctx, x, y, pieces[rng.randi_range(0, pieces.size() - 1)])
	for y in range(y0 + 1, y1):
		for x in [x0, x1]:
			if Vector2i(x, y) in gaps:
				continue
			_o(ctx, x, y, pieces[rng.randi_range(0, pieces.size() - 1)])


## 区域内随机撒（deco 层；避开障碍与外圈）
func _scatter(ctx: Dictionary, names: Array, count: int, x0: int, y0: int, x1: int, y1: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for i in range(count):
		var x: int = rng.randi_range(maxi(x0, 2), mini(x1, CELLS - 3))
		var y: int = rng.randi_range(maxi(y0, 2), mini(y1, CELLS - 3))
		if _occupied(ctx, x, y):
			continue
		_d(ctx, x, y, names[rng.randi_range(0, names.size() - 1)])


## 树丛：绿冠（可走）里混实心树干（障碍）
func _grove(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, canopies: int, trunks: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	_scatter(ctx, ["bush_a", "bush_b", "bush_c", "bush_d", "bush_e", "bush_f"], canopies, x0, y0, x1, y1)
	for i in range(trunks):
		var x: int = rng.randi_range(maxi(x0, 2), mini(x1, CELLS - 3))
		var y: int = rng.randi_range(maxi(y0, 2), mini(y1, CELLS - 3))
		if not _occupied(ctx, x, y):
			_o(ctx, x, y, ["tree_bare", "tree_blossom", "tree_stump"][rng.randi_range(0, 2)])


## 玉米秆密林块（视觉密、可走）
func _corn_patch(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, clear_rect: Rect2i = Rect2i()) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if clear_rect.size != Vector2i.ZERO and clear_rect.has_point(Vector2i(x, y)):
				continue
			_d(ctx, x, y, "corn_wall")


## 摆 prop：坐标为格中心（可用 .5），solid 时挂 StaticBody2D 层 1
func _prop(ctx: Dictionary, n: String, cx: float, cy: float, solid: bool = true, shrink: Vector2 = Vector2(0.85, 0.7)) -> void:
	var tex: Texture2D = load(PROP_DIR + n + ".png")
	assert(tex != null, "缺少 prop：" + n)
	_prop_seq += 1
	var sprite: Sprite2D = Sprite2D.new()
	sprite.name = "%s_%d" % [n.to_pascal_case(), _prop_seq]
	sprite.texture = tex
	sprite.position = Vector2(cx * TILE, cy * TILE)
	if solid:
		var body: StaticBody2D = StaticBody2D.new()
		body.name = "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		shape_node.name = "Shape"
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(tex.get_width() * shrink.x, tex.get_height() * shrink.y)
		shape_node.shape = rect
		# 碰撞盒贴地：往 sprite 下半部压（顶上留出屋顶/立面的视觉余量）
		shape_node.position = Vector2(0, tex.get_height() * (1.0 - shrink.y) * 0.5)
		body.add_child(shape_node)
		sprite.add_child(body)
	ctx["props"].add_child(sprite)


## 插槽 Marker2D（分组承载，mapgen-design 插槽系统）
func _slot(ctx: Dictionary, group: String, cx: float, cy: float) -> void:
	var m: Marker2D = Marker2D.new()
	m.name = "%s_%d" % [group.to_pascal_case(), ctx["slots"].get_child_count()]
	m.position = Vector2(cx * TILE, cy * TILE)
	m.add_to_group(group, true)
	ctx["slots"].add_child(m)


# ---------------------------------------------------------------- 六个模块

func _build_all_modules() -> void:
	_prop_seq = 0
	_module_gas_station()
	_module_crossroad()
	_module_farm()
	_module_barnyard()
	_module_town()
	_module_grove()


## 加油站：横路贯穿，路北加油站主楼+双泵，路面车祸残骸
func _module_gas_station() -> void:
	var ctx: Dictionary = _new_ctx("module_gas_station")
	_fill_base(ctx)
	_road_h(ctx, 18)
	_crosswalk_on_road_h(ctx, 30, 18)
	_manholes(ctx, 3, 18)
	_path_v(ctx, 19, 23, 39)

	# 加油站主楼（99×90 原图 → 约 6.2×5.6 格），泵岛在楼南
	_prop(ctx, "gas_station", 10.0, 9.0)
	_prop(ctx, "gas_pump", 8.5, 14.0, true, Vector2(0.9, 0.9))
	_prop(ctx, "gas_pump", 12.0, 14.0, true, Vector2(0.9, 0.9))
	_prop(ctx, "gas_sign", 15.5, 15.0)

	# 路面残骸带
	_prop(ctx, "wreck_white_h", 22.0, 20.5)
	_prop(ctx, "wreck_red_top", 27.5, 19.5)
	_prop(ctx, "wreck_brown_h2", 7.5, 21.0)
	_prop(ctx, "tires_a", 18.0, 16.5, false)
	_prop(ctx, "tires_b", 24.5, 22.5, false)
	_prop(ctx, "traffic_cone", 20.5, 22.0, false)
	_prop(ctx, "traffic_cone", 25.0, 18.5, false)
	_prop(ctx, "barrier_striped", 33.0, 21.5)
	_prop(ctx, "sign_50", 34.0, 17.0)
	_prop(ctx, "sign_stop", 16.0, 23.5)

	# 战损痕迹与植被
	_scatter(ctx, ["blood_a", "blood_b", "blood_c"], 6, 6, 15, 26, 24)
	_d(ctx, 13, 16, "corpse_a")
	_d(ctx, 23, 21, "corpse_b")
	_grove(ctx, 24, 3, 36, 9, 8, 3)
	_corn_patch(ctx, 2, 26, 6, 33)
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_e"], 8, 4, 25, 36, 36)

	_slot(ctx, "slot_spawn", 20.5, 30.5)
	_slot(ctx, "slot_vehicle", 5.5, 6.5)
	_slot(ctx, "slot_vehicle", 33.5, 32.5)
	_slot(ctx, "slot_resource", 10.5, 4.5)
	_slot(ctx, "slot_resource", 30.5, 27.5)
	_slot(ctx, "slot_resource", 16.5, 33.5)
	_slot(ctx, "slot_bandage", 26.5, 12.5)
	_slot(ctx, "slot_bandage", 6.5, 24.5)
	_save_module(ctx, "module_gas_station", "废弃加油站", "gas_station")


## 十字路口：横纵路交汇，中心车祸堆，四象限各有主题角落
func _module_crossroad() -> void:
	var ctx: Dictionary = _new_ctx("module_crossroad")
	_fill_base(ctx)
	_road_h(ctx, 18)
	_road_v(ctx, 18, 0, 17)
	_road_v(ctx, 18, 23, 39)
	# 十字中心补平路面（盖掉边线相交的杂线）
	for y in range(18, 23):
		for x in range(18, 23):
			_g(ctx, x, y, "road_plain")
	_crosswalk_on_road_h(ctx, 15, 18)
	_crosswalk_on_road_h(ctx, 24, 18)
	_crosswalk_on_road_v(ctx, 18, 15)
	_crosswalk_on_road_v(ctx, 18, 24)
	_manholes(ctx, 2, 18)

	# 中心车祸堆——路口即地标
	_prop(ctx, "wreck_red_v", 20.0, 15.5)
	_prop(ctx, "wreck_white_h", 25.5, 20.5)
	_prop(ctx, "wreck_brown_top", 19.0, 25.0)
	_prop(ctx, "tires_c", 22.5, 17.5, false)
	_prop(ctx, "traffic_cone", 17.0, 20.0, false)
	_prop(ctx, "traffic_cone", 23.5, 23.0, false)
	_prop(ctx, "barrier_striped", 14.0, 19.5)
	_prop(ctx, "sign_stop", 16.5, 16.0)
	_prop(ctx, "sign_noentry", 24.0, 16.0)
	_prop(ctx, "sign_nopark", 16.0, 24.5)

	# 西北：白栅栏花园宅基
	_picket_rect(ctx, 4, 4, 11, 11, [Vector2i(11, 7), Vector2i(11, 8)])
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_b", "bush_d"], 10, 5, 5, 10, 10)
	_prop(ctx, "mailbox", 12.5, 9.5)
	# 东北：小树林
	_grove(ctx, 26, 3, 36, 12, 10, 4)
	# 西南：荒坟角
	_prop(ctx, "tombstone", 6.0, 27.0)
	_prop(ctx, "tombstone", 8.5, 28.5)
	_prop(ctx, "tombstone", 6.5, 30.5)
	_prop(ctx, "tombstone", 10.0, 31.0)
	_o(ctx, 5, 26, "tree_bare")
	_o(ctx, 11, 29, "tree_bare")
	_d(ctx, 8, 30, "corpse_a")
	_scatter(ctx, ["blood_a", "blood_b"], 4, 5, 26, 12, 33)
	# 东南：农地角
	_crop_field(ctx, 27, 27, 35, 34, "crops_tall_a")
	_prop(ctx, "scarecrow", 31.0, 30.5)
	_scatter(ctx, ["blood_a", "blood_c", "flowers_a"], 6, 13, 24, 26, 36)

	_slot(ctx, "slot_spawn", 9.5, 20.5)
	_slot(ctx, "slot_vehicle", 32.5, 8.5)
	_slot(ctx, "slot_vehicle", 8.5, 34.5)
	_slot(ctx, "slot_resource", 7.5, 7.5)
	_slot(ctx, "slot_resource", 31.5, 30.5)
	_slot(ctx, "slot_resource", 28.5, 5.5)
	_slot(ctx, "slot_bandage", 13.5, 14.5)
	_slot(ctx, "slot_bandage", 26.5, 26.5)
	_save_module(ctx, "module_crossroad", "十字路口", "crossroad")


## 农田：围栏麦田+棕顶谷仓+干草堆+风车，小径贯穿
func _module_farm() -> void:
	var ctx: Dictionary = _new_ctx("module_farm")
	_fill_base(ctx)
	_path_h(ctx, 19)
	_path_v(ctx, 19, 0, 19)

	# 北侧大麦田（围栏留南口）
	_crop_field(ctx, 5, 5, 16, 15, "crops_tall_a")
	_rail_rect(ctx, 4, 4, 17, 16, [Vector2i(10, 16), Vector2i(11, 16)])
	_prop(ctx, "scarecrow", 10.5, 9.5)
	# 谷仓区（东北）
	_prop(ctx, "barn_tan", 26.5, 10.5)
	_o(ctx, 31, 13, "straw_big")
	_o(ctx, 32, 13, "straw_big")
	_o(ctx, 31, 14, "straw_mid")
	_prop(ctx, "straw_tall", 33.5, 14.0)
	_prop(ctx, "straw_small", 30.0, 15.0, false)
	_prop(ctx, "windmill", 21.0, 5.5)
	_d(ctx, 26, 14, "blood_b")
	_d(ctx, 27, 15, "corpse_b")
	# 南侧新垦田（围栏留北口）
	_crop_field(ctx, 24, 26, 35, 35, "crops_sprout")
	_rail_rect(ctx, 23, 25, 36, 36, [Vector2i(29, 25), Vector2i(30, 25)])
	# 西缘树带 + 东北玉米密林
	_grove(ctx, 2, 22, 8, 36, 6, 4)
	_corn_patch(ctx, 33, 2, 38, 6)
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_a", "bush_f"], 10, 2, 2, 37, 17)
	_scatter(ctx, ["blood_a"], 3, 10, 22, 30, 36)

	_slot(ctx, "slot_spawn", 14.5, 22.5)
	_slot(ctx, "slot_vehicle", 7.5, 33.5)
	_slot(ctx, "slot_vehicle", 35.5, 20.5)
	_slot(ctx, "slot_resource", 26.5, 13.5)
	_slot(ctx, "slot_resource", 10.5, 11.5)
	_slot(ctx, "slot_resource", 31.5, 30.5)
	_slot(ctx, "slot_bandage", 21.5, 5.5)
	_slot(ctx, "slot_bandage", 30.5, 18.5)
	_save_module(ctx, "module_farm", "农田", "farm")


## 谷仓院：红顶大谷仓+木板院墙（南门），院内尸横遍野
func _module_barnyard() -> void:
	var ctx: Dictionary = _new_ctx("module_barnyard")
	_fill_base(ctx)
	_path_h(ctx, 19)
	_path_v(ctx, 19, 17, 19)

	# 院墙（南侧留门）与红谷仓
	_board_rect(ctx, 12, 4, 27, 17, [Vector2i(19, 17), Vector2i(20, 17)])
	_prop(ctx, "barn_red", 19.5, 8.5)
	_o(ctx, 14, 13, "straw_big")
	_o(ctx, 14, 14, "straw_big")
	_o(ctx, 15, 13, "straw_mid")
	_prop(ctx, "straw_tall", 24.5, 6.0)
	_prop(ctx, "tires_b", 24.0, 15.0, false)
	_prop(ctx, "scarecrow", 25.5, 12.5)
	# 院内战损（谷仓门口的惨案现场）
	_d(ctx, 19, 13, "blood_a")
	_d(ctx, 20, 14, "blood_b")
	_d(ctx, 18, 14, "corpse_a")
	_d(ctx, 21, 13, "corpse_b")
	_d(ctx, 16, 15, "blood_c")
	# 院外
	_grove(ctx, 3, 3, 9, 12, 6, 3)
	_corn_patch(ctx, 30, 5, 37, 11)
	_prop(ctx, "windmill", 33.0, 26.5)
	_prop(ctx, "wreck_brown_h", 9.5, 24.5)
	_o(ctx, 30, 30, "straw_big")
	_o(ctx, 31, 30, "straw_mid")
	_prop(ctx, "tombstone", 7.0, 29.0)
	_prop(ctx, "tombstone", 9.0, 30.5)
	_d(ctx, 8, 28, "blood_b")
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_c"], 9, 2, 21, 37, 37)

	_slot(ctx, "slot_spawn", 19.5, 30.5)
	_slot(ctx, "slot_vehicle", 5.5, 8.5)
	_slot(ctx, "slot_vehicle", 34.5, 33.5)
	_slot(ctx, "slot_resource", 19.5, 12.5)
	_slot(ctx, "slot_resource", 14.5, 7.5)
	_slot(ctx, "slot_resource", 30.5, 31.5)
	_slot(ctx, "slot_bandage", 25.5, 14.5)
	_slot(ctx, "slot_bandage", 7.5, 22.5)
	_save_module(ctx, "module_barnyard", "谷仓院", "barnyard")


## 街区：横路+杂货店主楼+花园宅与围栏地块，路障与残骸
func _module_town() -> void:
	var ctx: Dictionary = _new_ctx("module_town")
	_fill_base(ctx)
	_road_h(ctx, 18)
	_crosswalk_on_road_h(ctx, 19, 18)
	_manholes(ctx, 3, 18)
	_path_v(ctx, 19, 23, 39)

	# 杂货店（路北正对斑马线）
	_prop(ctx, "building_store", 16.0, 12.0)
	_prop(ctx, "mailbox", 20.5, 15.5)
	_prop(ctx, "sign_nopark", 11.5, 16.0)
	# 西侧白栅栏花园宅
	_picket_rect(ctx, 3, 9, 10, 16, [Vector2i(10, 12), Vector2i(10, 13)])
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_b", "bush_e"], 9, 4, 10, 9, 15)
	# 东侧围栏玉米地块
	_rail_rect(ctx, 25, 6, 35, 14, [Vector2i(29, 14), Vector2i(30, 14)])
	_crop_field(ctx, 26, 7, 34, 13, "crops_mid")
	# 路面
	_prop(ctx, "wreck_red_h", 9.5, 19.5)
	_prop(ctx, "wreck_white_v", 24.0, 20.5)
	_prop(ctx, "wreck_brown_h2", 31.5, 19.5)
	_prop(ctx, "tires_a", 27.0, 22.0, false)
	_prop(ctx, "traffic_cone", 13.5, 22.0, false)
	_prop(ctx, "traffic_cone", 22.0, 17.5, false)
	_prop(ctx, "barrier_striped", 35.0, 19.5)
	_prop(ctx, "sign_noentry", 23.0, 16.0)
	_prop(ctx, "sign_50", 5.0, 23.0)
	# 南侧
	_corn_patch(ctx, 28, 28, 34, 33)
	_prop(ctx, "tombstone", 8.0, 30.0)
	_prop(ctx, "tombstone", 10.5, 31.5)
	_prop(ctx, "tombstone", 8.5, 33.0)
	_o(ctx, 6, 29, "tree_bare")
	_grove(ctx, 13, 27, 24, 36, 7, 3)
	_scatter(ctx, ["blood_a", "blood_b", "blood_c"], 7, 8, 15, 30, 25)
	_d(ctx, 18, 16, "corpse_a")

	_slot(ctx, "slot_spawn", 16.5, 26.5)
	_slot(ctx, "slot_vehicle", 33.5, 30.5)
	_slot(ctx, "slot_vehicle", 5.5, 4.5)
	_slot(ctx, "slot_resource", 16.5, 15.5)
	_slot(ctx, "slot_resource", 6.5, 12.5)
	_slot(ctx, "slot_resource", 30.5, 10.5)
	_slot(ctx, "slot_bandage", 24.5, 26.5)
	_slot(ctx, "slot_bandage", 12.5, 7.5)
	_save_module(ctx, "module_town", "街区", "town")


## 树林墓园：小径十字，西北密林、西南墓园、东南玉米迷丛
func _module_grove() -> void:
	var ctx: Dictionary = _new_ctx("module_grove")
	_fill_base(ctx)
	_path_h(ctx, 19)
	_path_v(ctx, 19)
	_g(ctx, 19, 19, "path_cross")
	_g(ctx, 20, 20, "path_cross")

	# 西北密林
	_grove(ctx, 4, 3, 16, 14, 16, 6)
	# 东北花甸
	_scatter(ctx, ["flowers_a", "flowers_b", "bush_a", "bush_d"], 14, 24, 3, 37, 13)
	_o(ctx, 30, 8, "tree_blossom")
	_o(ctx, 26, 5, "tree_blossom")
	# 西南墓园（围栏留北口）
	_rail_rect(ctx, 4, 25, 13, 34, [Vector2i(8, 25), Vector2i(9, 25)])
	_prop(ctx, "tombstone", 6.0, 28.0)
	_prop(ctx, "tombstone", 9.0, 28.5)
	_prop(ctx, "tombstone", 11.5, 28.0)
	_prop(ctx, "tombstone", 6.5, 31.0)
	_prop(ctx, "tombstone", 9.5, 31.5)
	_prop(ctx, "tombstone", 11.0, 33.0)
	_o(ctx, 5, 26, "tree_bare")
	_o(ctx, 12, 32, "tree_bare")
	_d(ctx, 8, 30, "corpse_a")
	_d(ctx, 10, 29, "blood_b")
	# 东南玉米迷丛（中央空腔藏资源点）
	_corn_patch(ctx, 26, 25, 36, 35, Rect2i(29, 28, 5, 5))
	_o(ctx, 31, 30, "straw_mid")
	# 小径东侧一辆弃车
	_prop(ctx, "wreck_white_top", 29.5, 19.0)
	_prop(ctx, "scarecrow", 23.5, 6.0)
	_scatter(ctx, ["blood_a", "tree_shrub_a", "tree_shrub_b"], 8, 2, 15, 37, 24)

	_slot(ctx, "slot_spawn", 19.5, 34.5)
	_slot(ctx, "slot_vehicle", 34.5, 5.5)
	_slot(ctx, "slot_vehicle", 5.5, 20.5)
	_slot(ctx, "slot_resource", 8.5, 29.5)
	_slot(ctx, "slot_resource", 31.5, 30.5)
	_slot(ctx, "slot_resource", 12.5, 6.5)
	_slot(ctx, "slot_bandage", 22.5, 12.5)
	_slot(ctx, "slot_bandage", 27.5, 33.5)
	_save_module(ctx, "module_grove", "林间墓园", "grove")
