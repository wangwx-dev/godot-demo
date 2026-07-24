extends SceneTree
## 构建脚本：从图集清单生成 map_tileset.tres，并程序化搭建 6 个 1280×1280 主题地图模块
## （手工编排布局，烘焙成 .tscn 供编辑器后续手调）。运行方式：
##   godot --headless --path . --import           # 先导入图集资源
##   godot --headless --path . --script res://tools/build_map_assets.gd
## 素材来源：Zombie Apocalypse Tileset (Ittai Manero)，由 tools/import_environment_assets.ps1 导入。
##
## 布局规则（2026-07-18 重设计，试玩反馈修订）：
##   1. 道路统一：全部模块横向沥青主干道贯穿 rows 18-22（乡村模块用磨损版），拼接无缝；
##      纵向路只在模块内部走行，端头用路障封口，不触上下接缝
##   2. 围栏不再画封闭矩形：只留两端开放的短段/残角做掩体与视觉引导
##   3. 碰撞白名单：建筑/整车残骸/油泵/风车/大干草垛才有碰撞；
##      树桩、路牌、墓碑、稻草人、轮胎、锥桶等一律纯装饰
##   4. 装饰成簇摆放、底噪减量；每模块可走面积 ≥85%，障碍岛状分布不成墙

const TILE: int = 32
const CELLS: int = 40  # 40×40 格 = 1280×1280（mapgen-design 模块规格）
const ATLAS_PNG: String = "res://assets/sprites/environment/tileset_ground.png"
const MANIFEST_PATH: String = "res://assets/sprites/environment/tileset_ground.json"
const PROP_DIR: String = "res://assets/sprites/environment/props/"
const MODULE_DIR: String = "res://scenes/levels/modules/tiled/"
const DATA_DIR: String = "res://resources/modules/tiled/"
const MODULE_SCRIPT: String = "res://scenes/levels/modules/map_module_tiled.gd"

const MapModuleDataScript = preload("res://resources/map_module_data.gd")

## 碰撞白名单修正：清单里标 solid 但按新规则应为纯装饰的 tile
## （2026-07-18 试玩反馈二轮：树木全部去碰撞——点状障碍剐蹭走位很不爽）
const SOLID_OVERRIDES: Dictionary = {
	"tree_stump": false,  # 膝盖高的树桩不该挡人
	"straw_mid": false,   # 小草垛过得去，只有 straw_big 当掩体
	"tree_bare": false,   # 树木纯装饰：kiting 游戏里点状碰撞只带来剐蹭
	"tree_blossom": false,
}

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
		var solid: bool = int(t["solid"]) == 1
		if SOLID_OVERRIDES.has(t["name"]):
			solid = SOLID_OVERRIDES[t["name"]]
		if solid:
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


## 底层地面（2026-07-24 翻修）：值噪声分区——同类地表成大片、草土交界铺过渡 tile，
## 消除逐格白噪声的椒盐/棋盘感。style = "dirt"（城镇）/ "grass"（乡村）/ "scorched"（焦土）。
## 分区噪声 + 过渡 tile 由 tools/extend_atlas_grass.py + build_ground_transitions.py 合成。
## 走 ctx rng 派生噪声种子，保持整局种子可复现。
func _fill_base(ctx: Dictionary, style: String = "dirt") -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	var seed_a: int = rng.randi()
	var seed_b: int = rng.randi()
	# grass_ratio：不同 style 下"草区"占比阈值（噪声 < 阈值 → 草，否则土）
	var grass_thresh: float = 0.70 if style == "grass" else (0.40 if style == "dirt" else 0.20)
	# 第一遍：按噪声定草/土大区
	var is_grass: Array = []
	for y in range(CELLS):
		var row: Array = []
		for x in range(CELLS):
			row.append(_noise2(x, y, seed_a, 11.0) < grass_thresh)
		is_grass.append(row)
	# 第二遍：落 tile——草区内用草/枯草肌理，土区用土；交界处用过渡
	for y in range(CELLS):
		for x in range(CELLS):
			if is_grass[y][x]:
				# 交界方向：邻格是土 → 用对应边缘/角过渡
				var edge: String = _grass_edge_tile(is_grass, x, y)
				if edge != "":
					_g(ctx, x, y, edge)
				else:
					_g(ctx, x, y, _grass_body_tile(x, y, seed_b))
			else:
				_g(ctx, x, y, _dirt_body_tile(x, y, seed_b, style))


## 值噪声：格点哈希 + 双线性插值，scale 越大区块越大。确定性（种子+坐标）。
func _noise2(x: int, y: int, seed_val: int, scale: float) -> float:
	var fx: float = x / scale
	var fy: float = y / scale
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var tx: float = fx - x0
	var ty: float = fy - y0
	var v00: float = _hash2(x0, y0, seed_val)
	var v10: float = _hash2(x0 + 1, y0, seed_val)
	var v01: float = _hash2(x0, y0 + 1, seed_val)
	var v11: float = _hash2(x0 + 1, y0 + 1, seed_val)
	# smoothstep 插值
	var sx: float = tx * tx * (3.0 - 2.0 * tx)
	var sy: float = ty * ty * (3.0 - 2.0 * ty)
	var a: float = lerp(v00, v10, sx)
	var b: float = lerp(v01, v11, sx)
	return lerp(a, b, sy)


func _hash2(x: int, y: int, seed_val: int) -> float:
	var v: int = (x * 374761393 + y * 668265263 + seed_val * 2246822519) & 0x7fffffff
	v = ((v ^ (v >> 13)) * 1274126177) & 0x7fffffff
	return float((v ^ (v >> 16)) & 0xffff) / 65535.0


## 草区交界过渡：看四邻/四角是否土，返回合适的 grass_edge/corner，全草返回 ""。
func _grass_edge_tile(is_grass: Array, x: int, y: int) -> String:
	var n_dirt: bool = not _grass_at(is_grass, x, y - 1)
	var s_dirt: bool = not _grass_at(is_grass, x, y + 1)
	var w_dirt: bool = not _grass_at(is_grass, x - 1, y)
	var e_dirt: bool = not _grass_at(is_grass, x + 1, y)
	# 直边优先
	if n_dirt and not s_dirt and not w_dirt and not e_dirt:
		return "grass_edge_n"
	if s_dirt and not n_dirt and not w_dirt and not e_dirt:
		return "grass_edge_s"
	if w_dirt and not e_dirt and not n_dirt and not s_dirt:
		return "grass_edge_w"
	if e_dirt and not w_dirt and not n_dirt and not s_dirt:
		return "grass_edge_e"
	# 外角（相邻两边都是土）
	if n_dirt and w_dirt:
		return "grass_corner_nw"
	if n_dirt and e_dirt:
		return "grass_corner_ne"
	if s_dirt and w_dirt:
		return "grass_corner_sw"
	if s_dirt and e_dirt:
		return "grass_corner_se"
	# 只有对角是土（内角）——用磨损中间态柔化
	if not _grass_at(is_grass, x - 1, y - 1) or not _grass_at(is_grass, x + 1, y - 1) 			or not _grass_at(is_grass, x - 1, y + 1) or not _grass_at(is_grass, x + 1, y + 1):
		return "grass_worn"
	return ""


func _grass_at(is_grass: Array, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= CELLS or y >= CELLS:
		return true  # 图外当草，不在边界硬切
	return is_grass[y][x]


func _grass_body_tile(x: int, y: int, seed_val: int) -> String:
	var r: float = _hash2(x, y, seed_val)
	if r < 0.52:
		return "grass_a"
	if r < 0.86:
		return "grass_b"
	if r < 0.96:
		return "grass_dry_a"
	return "grass_worn"


func _dirt_body_tile(x: int, y: int, seed_val: int, style: String) -> String:
	var r: float = _hash2(x, y, seed_val + 99)
	if style == "grass":
		# 乡村的土区更多枯草感
		if r < 0.5:
			return "dirt_a"
		if r < 0.75:
			return "grass_dry_b"
		if r < 0.95:
			return "dirt_b"
		return "dirt_twigs_a"
	if style == "scorched":
		if r < 0.5:
			return "dirt_a"
		if r < 0.78:
			return "dirt_b"
		if r < 0.93:
			return "grass_dry_b"
		return "dirt_twigs_b"
	# dirt（城镇）
	if r < 0.52:
		return "dirt_a"
	if r < 0.85:
		return "dirt_b"
	if r < 0.96:
		return "grass_dry_a"
	return "dirt_twigs_a"


func _ground_tile(rng: RandomNumberGenerator, style: String) -> String:
	var r: float = rng.randf()
	match style:
		"grass":
			if r < 0.45:
				return "grass_a"
			if r < 0.72:
				return "grass_b"
			if r < 0.87:
				return "grass_dry_a"
			if r < 0.97:
				return "grass_dry_b"
			return "dirt_twigs_a"  # 只留枯枝点缀，不混整块泥土（棋盘感反馈）
		"scorched":
			if r < 0.50:
				return "dirt_a"
			if r < 0.72:
				return "dirt_b"
			if r < 0.86:
				return "grass_dry_b"
			if r < 0.94:
				return "grass_dry_a"
			return "dirt_twigs_b"
		_:
			if r < 0.60:
				return "dirt_a"
			if r < 0.82:
				return "dirt_b"
			if r < 0.89:
				return "grass_dry_a"
			if r < 0.94:
				return "grass_dry_b"
			if r < 0.97:
				return "dirt_twigs_a"
			return "dirt_twigs_b"


## 草地斑块：不规则圆斑（城镇模块的绿化残余，画在铺路之前）
func _grass_blob(ctx: Dictionary, cx: int, cy: int, radius: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for y in range(maxi(cy - radius, 0), mini(cy + radius + 1, CELLS)):
		for x in range(maxi(cx - radius, 0), mini(cx + radius + 1, CELLS)):
			var d: float = Vector2(x - cx, y - cy).length() / radius
			if d <= 1.0 and rng.randf() > d * d:
				_g(ctx, x, y, _ground_tile(rng, "grass"))


## 横向沥青路（5 格高：上边线/路面/中线/路面/下边线），城镇干净版
func _road_h(ctx: Dictionary, y0: int, x0: int = 0, x1: int = CELLS - 1) -> void:
	for x in range(x0, x1 + 1):
		_g(ctx, x, y0, "road_edge_h_top")
		_g(ctx, x, y0 + 1, "road_plain")
		_g(ctx, x, y0 + 2, "road_line_h_mid")
		_g(ctx, x, y0 + 3, "road_plain")
		_g(ctx, x, y0 + 4, "road_edge_h_bottom")


## 横向沥青路磨损版（乡村）：中线断续褪色 + 路面泥土斑块做旧
func _road_h_worn(ctx: Dictionary, y0: int, wear: int = 8) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for x in range(CELLS):
		_g(ctx, x, y0, "road_edge_h_top")
		_g(ctx, x, y0 + 1, "road_plain")
		_g(ctx, x, y0 + 2, "road_line_h_mid" if rng.randf() < 0.45 else "road_plain")
		_g(ctx, x, y0 + 3, "road_plain")
		_g(ctx, x, y0 + 4, "road_edge_h_bottom")
	for i in range(wear):
		_d(ctx, rng.randi_range(1, CELLS - 2), y0 + 1 + rng.randi_range(0, 2), "path_patch")


## 纵向沥青路段（只在模块内部使用，端头必须 _roadblock 封口，不触上下接缝）
func _road_v(ctx: Dictionary, x0: int, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		_g(ctx, x0, y, "road_edge_v_left")
		_g(ctx, x0 + 1, y, "road_plain")
		_g(ctx, x0 + 2, y, "road_dash_v")
		_g(ctx, x0 + 3, y, "road_plain")
		_g(ctx, x0 + 4, y, "road_edge_v_right")


## 纵向路端头路障封口：残骸横堵 + 锥桶警示（叙事：疏散封锁线）
func _roadblock_v(ctx: Dictionary, x0: int, y: float, wreck: String) -> void:
	_prop(ctx, wreck, x0 + 2.5, y, true)
	_prop(ctx, "barrier_striped", x0 + 0.8, y + 0.9, false)
	_prop(ctx, "barrier_striped", x0 + 4.2, y - 0.9, false)
	_prop(ctx, "traffic_cone", x0 + 1.2, y - 1.3, false)
	_prop(ctx, "traffic_cone", x0 + 3.8, y + 1.4, false)


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


## 泥土支径（纵，2 格宽）：从主干道通向 POI 的短接驳，不做贯穿路
func _path_v(ctx: Dictionary, x0: int, y0: int, y1: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for y in range(y0, y1 + 1):
		_g(ctx, x0, y, "path_v")
		_g(ctx, x0 + 1, y, "path_v" if rng.randf() < 0.8 else "path_patch")


## 泥土支径（横，2 格宽）
func _path_h(ctx: Dictionary, y0: int, x0: int, x1: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for x in range(x0, x1 + 1):
		_g(ctx, x, y0, "path_h")
		_g(ctx, x, y0 + 1, "path_h" if rng.randf() < 0.8 else "path_patch")


## 农田块：庄稼行与垄沟交替（无围栏，可走的视觉密度层）
func _crop_field(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, grown: String) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_g(ctx, x, y, grown if y % 2 == 0 else "crops_tilled")


## 矮木围栏横向短段（两端开放；≤6 格，只做掩体/引导不围圈）
func _rail_run_h(ctx: Dictionary, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		var n: String = "rail_h_plain"
		if x == x0:
			n = "rail_h_left"
		elif x == x1:
			n = "rail_h_right"
		_o(ctx, x, y, n)


## 矮木围栏纵向短段
func _rail_run_v(ctx: Dictionary, x: int, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		_o(ctx, x, y, "rail_v_a" if y % 2 == 0 else "rail_v_b")


## 白桩栅栏横向短段
func _picket_run_h(ctx: Dictionary, x0: int, x1: int, y: int) -> void:
	for x in range(x0, x1 + 1):
		_o(ctx, x, y, "picket_g" if x % 2 == 0 else "picket_h")


## 白桩栅栏纵向短段
func _picket_run_v(ctx: Dictionary, x: int, y0: int, y1: int) -> void:
	for y in range(y0, y1 + 1):
		_o(ctx, x, y, "picket_e" if y % 2 == 0 else "picket_f")


## 木板院墙 L 形残角（corner: "nw"/"ne"/"sw"/"se"；arm 为两臂长度）
func _board_corner(ctx: Dictionary, cx: int, cy: int, corner: String, arm: int = 4) -> void:
	var pieces: Array = ["board_a", "board_b", "board_c", "board_f", "board_g", "board_h"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var dx: int = 1 if corner in ["nw", "sw"] else -1
	var dy: int = 1 if corner in ["nw", "ne"] else -1
	for i in range(arm):
		_o(ctx, cx + dx * i, cy, pieces[rng.randi_range(0, pieces.size() - 1)])
	for i in range(1, arm):
		_o(ctx, cx, cy + dy * i, pieces[rng.randi_range(0, pieces.size() - 1)])


## 区域内随机撒（deco 层；避开障碍与外圈）——只用于血迹等战损痕迹
func _scatter(ctx: Dictionary, names: Array, count: int, x0: int, y0: int, x1: int, y1: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for i in range(count):
		var x: int = rng.randi_range(maxi(x0, 2), mini(x1, CELLS - 3))
		var y: int = rng.randi_range(maxi(y0, 2), mini(y1, CELLS - 3))
		if _occupied(ctx, x, y):
			continue
		_d(ctx, x, y, names[rng.randi_range(0, names.size() - 1)])


## 装饰簇：围绕中心点成团摆放（花丛/灌木不再均匀撒满地）
func _cluster(ctx: Dictionary, names: Array, cx: int, cy: int, radius: int, count: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	for i in range(count):
		var x: int = clampi(cx + rng.randi_range(-radius, radius), 2, CELLS - 3)
		var y: int = clampi(cy + rng.randi_range(-radius, radius), 2, CELLS - 3)
		if _occupied(ctx, x, y):
			continue
		_d(ctx, x, y, names[rng.randi_range(0, names.size() - 1)])


## 树丛：绿冠灌木 + 树木（2026-07-18 起全部纯装饰，不再有点状碰撞）
func _grove(ctx: Dictionary, x0: int, y0: int, x1: int, y1: int, canopies: int, trunks: int) -> void:
	var rng: RandomNumberGenerator = ctx["rng"]
	_scatter(ctx, ["bush_a", "bush_b", "bush_c", "bush_d", "bush_e", "bush_f"], canopies, x0, y0, x1, y1)
	_scatter(ctx, ["tree_stump", "tree_shrub_a", "tree_shrub_b"], maxi(2, canopies / 3), x0, y0, x1, y1)
	for i in range(trunks):
		var x: int = rng.randi_range(maxi(x0, 2), mini(x1, CELLS - 3))
		var y: int = rng.randi_range(maxi(y0, 2), mini(y1, CELLS - 3))
		if not _occupied(ctx, x, y):
			_d(ctx, x, y, "tree_bare" if rng.randf() < 0.6 else "tree_blossom")


## 玉米秆密丛块——2026-07-18 弃用：corn_wall tile 视觉误读为"茅草屋"（试玩反馈 6）
#func _corn_patch(...) 已移除，密度遮蔽改用熟麦田/灌木簇承担


## 摆 prop：坐标为格中心（可用 .5）。默认纯装饰；只有白名单大件显式传 solid=true
func _prop(ctx: Dictionary, n: String, cx: float, cy: float, solid: bool = false, shrink: Vector2 = Vector2(0.85, 0.7)) -> void:
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
	_build_assault_arena()


## 总攻竞技场（M8，非模块）：西侧接应点铺装 + 东侧尸巢，无插槽无迷雾，
## 出生/Boss 位由 assault_map.gd 硬编码。存成独立场景不挂 MapModuleTiled。
func _build_assault_arena() -> void:
	var ctx: Dictionary = _new_ctx("assault_arena")
	_fill_base(ctx, "scorched")
	_road_h_worn(ctx, 18, 16)
	# 西侧接应点：整片铺装停机坪 + 封锁线残骸（最后的防线叙事）
	for y in range(13, 28):
		for x in range(2, 10):
			_g(ctx, x, y, "road_plain")
	_prop(ctx, "vehicle_0164", 6.0, 15.5, true)  # 接应车：完好车头朝上（识别表提取），随时能走
	_prop(ctx, "barrier_striped", 10.5, 14.0)
	_prop(ctx, "barrier_striped", 10.5, 26.0)
	_prop(ctx, "traffic_cone", 9.5, 17.5)
	_prop(ctx, "traffic_cone", 9.0, 23.0)
	_prop(ctx, "sign_warning", 11.5, 20.5)
	_d(ctx, 7, 19, "blood_b")
	_d(ctx, 5, 24, "corpse_a")
	_d(ctx, 8, 25, "blood_a")
	# 中场掩体：残骸车两台 + 大草垛岛
	_prop(ctx, "wreck_brown_h", 17.5, 14.5, true)
	_prop(ctx, "wreck_red_v", 22.0, 26.5, true)
	_o(ctx, 19, 31, "straw_big")
	_o(ctx, 20, 31, "straw_big")
	_o(ctx, 14, 7, "straw_big")
	# 东侧尸巢：血肉地毯 + 尸堆 + 枯树圈（Boss 老巢，视觉密度拉满）
	_scatter(ctx, ["blood_a", "blood_b", "blood_c"], 42, 26, 6, 37, 34)
	_scatter(ctx, ["corpse_a", "corpse_b"], 12, 27, 8, 37, 33)
	_cluster(ctx, ["bush_c", "bush_f", "tree_shrub_b"], 33, 10, 4, 8)
	_cluster(ctx, ["bush_c", "bush_f", "tree_shrub_a"], 34, 30, 4, 8)
	_o(ctx, 28, 9, "tree_bare")
	_o(ctx, 36, 14, "tree_bare")
	_o(ctx, 29, 33, "tree_bare")
	_o(ctx, 37, 27, "tree_bare")
	_d(ctx, 31, 19, "corpse_b")
	_d(ctx, 33, 21, "corpse_a")
	_d(ctx, 32, 20, "blood_c")
	# 全场零散战损
	_scatter(ctx, ["blood_a", "blood_c"], 10, 11, 5, 25, 35)
	_save_plain(ctx, "res://scenes/levels/assault_map/assault_arena.tscn", "AssaultArena")


## 存成普通场景（无模块脚本/插槽/数据 .tres）。
func _save_plain(ctx: Dictionary, scene_path: String, root_name: String) -> void:
	var root: Node2D = ctx["root"]
	root.name = root_name
	_own(root, root)
	var packed: PackedScene = PackedScene.new()
	var err: int = packed.pack(root)
	assert(err == OK, "pack 失败：" + root_name)
	err = ResourceSaver.save(packed, scene_path)
	assert(err == OK, "场景保存失败：" + scene_path)
	print("[build_map_assets] %s 完成" % scene_path)
	root.free()


## 加油站：干线贯穿，路北站房+泵岛前场（沥青铺装），路面残骸岛
func _module_gas_station() -> void:
	var ctx: Dictionary = _new_ctx("module_gas_station")
	_fill_base(ctx)
	_grass_blob(ctx, 30, 6, 5)
	_grass_blob(ctx, 5, 30, 5)
	_grass_blob(ctx, 20, 34, 4)
	_road_h(ctx, 18)
	_crosswalk_on_road_h(ctx, 30, 18)
	_manholes(ctx, 3, 18)

	# 泵岛前场：站房到干线之间整片沥青铺装，加油站才像加油站
	for y in range(13, 18):
		for x in range(5, 17):
			_g(ctx, x, y, "road_plain")
	_prop(ctx, "gas_station", 10.0, 9.0, true)
	_prop(ctx, "gas_pump", 8.0, 14.5, true, Vector2(0.9, 0.9))
	_prop(ctx, "gas_pump", 12.0, 14.5, true, Vector2(0.9, 0.9))
	_prop(ctx, "gas_sign", 16.5, 13.0)
	_d(ctx, 6, 16, "blood_b")
	_d(ctx, 10, 16, "corpse_a")
	_prop(ctx, "tires_a", 5.5, 13.5)
	_prop(ctx, "traffic_cone", 14.5, 16.5)

	# 干线残骸岛（车距拉开，走位空间充足）
	_prop(ctx, "wreck_white_h", 23.0, 20.5, true)
	_prop(ctx, "wreck_red_top", 32.0, 19.5, true)
	_prop(ctx, "traffic_cone", 25.5, 21.5)
	_prop(ctx, "tires_b", 30.0, 22.3)
	_prop(ctx, "sign_50", 36.0, 16.8)
	_prop(ctx, "sign_stop", 18.5, 23.5)
	_d(ctx, 26, 20, "blood_a")

	# 北：站房东侧疏林；南：西缘草甸灌木 + 弃车 + 花簇
	_grove(ctx, 24, 3, 36, 10, 9, 3)
	_cluster(ctx, ["bush_a", "bush_c", "bush_f"], 4, 30, 3, 7)
	_prop(ctx, "wreck_brown_h2", 12.0, 28.0, true)
	_d(ctx, 13, 26, "blood_c")
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_e"], 30, 31, 3, 7)
	_cluster(ctx, ["bush_a", "bush_d", "tree_stump"], 20, 34, 3, 5)

	_slot(ctx, "slot_spawn", 20.5, 30.5)
	_slot(ctx, "slot_vehicle", 5.5, 6.5)
	_slot(ctx, "slot_vehicle", 33.5, 32.5)
	_slot(ctx, "slot_resource", 10.5, 4.5)
	_slot(ctx, "slot_resource", 30.5, 27.5)
	_slot(ctx, "slot_resource", 16.5, 33.5)
	_slot(ctx, "slot_bandage", 26.5, 12.5)
	_slot(ctx, "slot_bandage", 6.5, 24.5)
	_save_module(ctx, "module_gas_station", "废弃加油站", "gas_station")


## 十字路口：横干线 + 纵路两段（路障封口不出图），中心车祸地标，四象限开放主题角
func _module_crossroad() -> void:
	var ctx: Dictionary = _new_ctx("module_crossroad")
	_fill_base(ctx)
	_grass_blob(ctx, 8, 8, 5)
	_grass_blob(ctx, 31, 7, 5)
	_grass_blob(ctx, 8, 30, 4)
	_road_h(ctx, 18)
	_road_v(ctx, 18, 6, 17)
	_road_v(ctx, 18, 23, 34)
	# 十字中心补平路面（盖掉边线相交的杂线）
	for y in range(18, 23):
		for x in range(18, 23):
			_g(ctx, x, y, "road_plain")
	_crosswalk_on_road_h(ctx, 15, 18)
	_crosswalk_on_road_h(ctx, 24, 18)
	_crosswalk_on_road_v(ctx, 18, 15)
	_crosswalk_on_road_v(ctx, 18, 24)
	_manholes(ctx, 2, 18)
	# 纵路端头封锁线（疏散路障，路不出上下接缝）
	_roadblock_v(ctx, 18, 6.0, "wreck_red_v")
	_roadblock_v(ctx, 18, 34.0, "wreck_brown_top")

	# 中心车祸地标
	_prop(ctx, "wreck_white_h", 26.5, 20.5, true)
	_prop(ctx, "tires_c", 22.5, 17.3)
	_prop(ctx, "traffic_cone", 17.0, 20.0)
	_prop(ctx, "traffic_cone", 23.5, 23.0)
	_prop(ctx, "sign_stop", 16.5, 16.0)
	_prop(ctx, "sign_noentry", 24.0, 16.0)
	_prop(ctx, "sign_nopark", 16.0, 24.5)
	_d(ctx, 24, 21, "blood_b")

	# 西北：花园宅基残迹（白栅栏 L 形开放短段 + 花簇 + 信箱）
	_picket_run_h(ctx, 5, 9, 6)
	_picket_run_v(ctx, 4, 7, 10)
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_b"], 8, 9, 3, 9)
	_prop(ctx, "mailbox", 12.5, 9.5)
	# 东北：疏林
	_grove(ctx, 26, 3, 36, 12, 10, 3)
	# 西南：荒坟角（墓碑与枯树全部纯装饰）
	_prop(ctx, "tombstone", 6.0, 27.0)
	_prop(ctx, "tombstone", 8.5, 28.5)
	_prop(ctx, "tombstone", 6.5, 30.5)
	_prop(ctx, "tombstone", 10.0, 31.0)
	_d(ctx, 5, 26, "tree_bare")
	_d(ctx, 11, 29, "tree_bare")
	_d(ctx, 8, 30, "corpse_a")
	_scatter(ctx, ["blood_a", "blood_b"], 4, 5, 26, 12, 33)
	# 东南：无围栏庄稼行 + 稻草人
	_crop_field(ctx, 28, 28, 35, 33, "crops_tall_a")
	_prop(ctx, "scarecrow", 31.5, 30.5)
	_scatter(ctx, ["blood_a", "blood_c"], 4, 13, 24, 26, 36)

	_slot(ctx, "slot_spawn", 9.5, 20.5)
	_slot(ctx, "slot_vehicle", 32.5, 8.5)
	_slot(ctx, "slot_vehicle", 8.5, 34.5)
	_slot(ctx, "slot_resource", 7.5, 7.5)
	_slot(ctx, "slot_resource", 31.5, 30.5)
	_slot(ctx, "slot_resource", 28.5, 5.5)
	_slot(ctx, "slot_bandage", 13.5, 14.5)
	_slot(ctx, "slot_bandage", 26.5, 26.5)
	_save_module(ctx, "module_crossroad", "十字路口", "crossroad")


## 农田：乡道贯穿（磨损），北大麦田+谷仓支径，南新垦田，围栏只留残段
func _module_farm() -> void:
	var ctx: Dictionary = _new_ctx("module_farm")
	_fill_base(ctx, "grass")
	_road_h_worn(ctx, 18, 9)

	# 北侧大麦田（无围栏，西/南缘留两截残栏引导视线）
	_crop_field(ctx, 5, 5, 16, 15, "crops_tall_a")
	_rail_run_v(ctx, 3, 6, 10)
	_rail_run_h(ctx, 6, 10, 16)
	_prop(ctx, "scarecrow", 10.5, 9.5)
	# 谷仓区（东北）+ 支径接乡道
	_prop(ctx, "barn_tan", 27.0, 9.0, true)
	_path_v(ctx, 26, 13, 17)
	_o(ctx, 31, 12, "straw_big")
	_o(ctx, 32, 12, "straw_big")
	_d(ctx, 31, 13, "straw_mid")
	_prop(ctx, "straw_tall", 34.0, 13.5)
	_prop(ctx, "straw_small", 30.0, 14.5)
	_prop(ctx, "windmill", 21.0, 5.5, true)
	_d(ctx, 26, 14, "blood_b")
	_d(ctx, 27, 15, "corpse_b")
	# 乡道弃车
	_prop(ctx, "wreck_brown_h", 8.5, 20.5, true)
	_prop(ctx, "traffic_cone", 11.0, 21.5)
	# 南侧新垦田（无围栏）+ 西缘疏林 + 东北角熟田
	_crop_field(ctx, 24, 27, 35, 34, "crops_sprout")
	_rail_run_h(ctx, 24, 28, 26)
	_grove(ctx, 2, 23, 8, 36, 7, 3)
	_crop_field(ctx, 33, 2, 38, 6, "crops_mid")
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_a"], 20, 26, 3, 8)
	_cluster(ctx, ["bush_f", "tree_stump", "flowers_b"], 13, 31, 3, 6)
	_scatter(ctx, ["blood_a"], 3, 10, 23, 30, 36)

	_slot(ctx, "slot_spawn", 14.5, 22.5)
	_slot(ctx, "slot_vehicle", 7.5, 33.5)
	_slot(ctx, "slot_vehicle", 35.5, 20.5)
	_slot(ctx, "slot_resource", 27.5, 13.5)
	_slot(ctx, "slot_resource", 10.5, 11.5)
	_slot(ctx, "slot_resource", 31.5, 30.5)
	_slot(ctx, "slot_bandage", 21.5, 8.5)
	_slot(ctx, "slot_bandage", 30.5, 17.5)
	_save_module(ctx, "module_farm", "农田", "farm")


## 谷仓院：乡道贯穿（磨损），红谷仓+院墙只留两处 L 形残角（全向可进出）
func _module_barnyard() -> void:
	var ctx: Dictionary = _new_ctx("module_barnyard")
	_fill_base(ctx, "grass")
	_road_h_worn(ctx, 18, 8)

	# 红谷仓与院墙残角（西北/东北两个 L 角，院子四面敞开）
	_board_corner(ctx, 12, 4, "nw", 4)
	_board_corner(ctx, 27, 4, "ne", 4)
	_prop(ctx, "barn_red", 19.5, 8.5, true)
	_path_v(ctx, 19, 13, 17)
	_o(ctx, 13, 12, "straw_big")
	_o(ctx, 14, 12, "straw_big")
	_d(ctx, 13, 13, "straw_mid")
	_prop(ctx, "straw_tall", 24.5, 6.0)
	_prop(ctx, "tires_b", 24.0, 14.0)
	_prop(ctx, "scarecrow", 26.0, 12.0)
	# 谷仓门口的惨案现场（装饰簇）
	_d(ctx, 19, 13, "blood_a")
	_d(ctx, 20, 14, "blood_b")
	_d(ctx, 18, 14, "corpse_a")
	_d(ctx, 21, 13, "corpse_b")
	_d(ctx, 16, 15, "blood_c")
	# 西北疏林，东南熟田，南侧敞牧场
	_grove(ctx, 3, 3, 9, 12, 6, 2)
	_crop_field(ctx, 30, 28, 37, 34, "crops_tall_a")
	_prop(ctx, "windmill", 33.0, 25.0, true)
	_prop(ctx, "wreck_brown_h", 9.5, 24.5, true)
	_o(ctx, 29, 24, "straw_big")
	_d(ctx, 30, 24, "straw_mid")
	_prop(ctx, "tombstone", 7.0, 29.0)
	_prop(ctx, "tombstone", 9.0, 30.5)
	_d(ctx, 8, 28, "blood_b")
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_c"], 17, 30, 3, 7)
	_cluster(ctx, ["bush_a", "bush_e", "tree_stump"], 24, 33, 3, 5)

	_slot(ctx, "slot_spawn", 19.5, 30.5)
	_slot(ctx, "slot_vehicle", 5.5, 8.5)
	_slot(ctx, "slot_vehicle", 34.5, 33.5)
	_slot(ctx, "slot_resource", 19.5, 12.5)
	_slot(ctx, "slot_resource", 14.5, 7.5)
	_slot(ctx, "slot_resource", 33.5, 30.5)
	_slot(ctx, "slot_bandage", 25.5, 14.5)
	_slot(ctx, "slot_bandage", 7.5, 22.5)
	_save_module(ctx, "module_barnyard", "谷仓院", "barnyard")


## 街区：干线+杂货店门前铺装，西花园宅残迹，东无围栏田，南疏林坟角
func _module_town() -> void:
	var ctx: Dictionary = _new_ctx("module_town")
	_fill_base(ctx)
	_grass_blob(ctx, 6, 13, 5)
	_grass_blob(ctx, 31, 31, 5)
	_grass_blob(ctx, 18, 32, 4)
	_road_h(ctx, 18)
	_crosswalk_on_road_h(ctx, 19, 18)
	_manholes(ctx, 3, 18)

	# 杂货店门前人行铺装（正对斑马线）
	for y in range(15, 18):
		for x in range(12, 21):
			_g(ctx, x, y, "road_plain")
	_prop(ctx, "building_store", 16.0, 12.0, true)
	_prop(ctx, "mailbox", 21.5, 15.5)
	_prop(ctx, "sign_nopark", 11.5, 16.0)
	_d(ctx, 18, 16, "corpse_a")
	_d(ctx, 15, 16, "blood_b")
	# 西侧花园宅残迹（白栅栏开放 L）
	_picket_run_h(ctx, 4, 8, 10)
	_picket_run_v(ctx, 3, 11, 14)
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_b"], 6, 13, 3, 8)
	# 东侧无围栏庄稼田 + 北缘残栏
	_crop_field(ctx, 26, 7, 34, 13, "crops_mid")
	_rail_run_h(ctx, 27, 31, 6)
	# 干线残骸（两台，间距拉开）
	_prop(ctx, "wreck_red_h", 9.5, 19.5, true)
	_prop(ctx, "wreck_white_v", 25.0, 20.5, true)
	_prop(ctx, "tires_a", 28.0, 22.0)
	_prop(ctx, "traffic_cone", 13.5, 22.0)
	_prop(ctx, "traffic_cone", 22.0, 17.5)
	_prop(ctx, "barrier_striped", 35.5, 19.5)
	_prop(ctx, "sign_noentry", 23.0, 16.0)
	_prop(ctx, "sign_50", 5.0, 23.0)
	# 南侧：撞出路外的弃车 + 疏林 + 坟角 + 熟田
	_prop(ctx, "wreck_brown_h2", 31.5, 26.0, true)
	_d(ctx, 30, 25, "blood_c")
	_grove(ctx, 13, 27, 24, 36, 8, 3)
	_crop_field(ctx, 28, 29, 34, 34, "crops_mid")
	_prop(ctx, "tombstone", 8.0, 30.0)
	_prop(ctx, "tombstone", 10.5, 31.5)
	_prop(ctx, "tombstone", 8.5, 33.0)
	_o(ctx, 6, 29, "tree_bare")
	_scatter(ctx, ["blood_a", "blood_b", "blood_c"], 6, 8, 15, 30, 25)

	_slot(ctx, "slot_spawn", 16.5, 26.5)
	_slot(ctx, "slot_vehicle", 33.5, 31.5)
	_slot(ctx, "slot_vehicle", 5.5, 4.5)
	_slot(ctx, "slot_resource", 16.5, 14.5)
	_slot(ctx, "slot_resource", 6.5, 6.5)
	_slot(ctx, "slot_resource", 30.5, 10.5)
	_slot(ctx, "slot_bandage", 24.5, 26.5)
	_slot(ctx, "slot_bandage", 12.5, 7.5)
	_save_module(ctx, "module_town", "街区", "town")


## 林间墓园：林区公路贯穿（重度磨损），支径通墓园与花甸，玉米迷丛开西口
func _module_grove() -> void:
	var ctx: Dictionary = _new_ctx("module_grove")
	_fill_base(ctx, "grass")
	_road_h_worn(ctx, 18, 12)

	# 支径：南接墓园北入口，北接花甸南缘
	_path_v(ctx, 8, 23, 26)
	_path_v(ctx, 28, 13, 17)
	# 公路弃车
	_prop(ctx, "wreck_white_top", 29.5, 19.5, true)
	_prop(ctx, "traffic_cone", 32.0, 21.5)
	_d(ctx, 27, 21, "blood_a")

	# 西北密林（树干障碍岛状，密度可穿行）
	_grove(ctx, 3, 3, 16, 14, 16, 5)
	# 东北花甸（花簇成团 + 两棵樱树障碍岛）
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_d"], 27, 6, 3, 9)
	_cluster(ctx, ["flowers_a", "flowers_b", "bush_a"], 33, 10, 3, 8)
	_o(ctx, 30, 8, "tree_blossom")
	_o(ctx, 25, 4, "tree_blossom")
	_prop(ctx, "scarecrow", 22.5, 6.0)
	# 西南墓园：北缘两截残栏留宽口，墓碑纯装饰
	_rail_run_h(ctx, 4, 6, 27)
	_rail_run_h(ctx, 11, 13, 27)
	_prop(ctx, "tombstone", 6.0, 29.0)
	_prop(ctx, "tombstone", 9.0, 29.5)
	_prop(ctx, "tombstone", 11.5, 29.0)
	_prop(ctx, "tombstone", 6.5, 32.0)
	_prop(ctx, "tombstone", 9.5, 32.5)
	_prop(ctx, "tombstone", 11.0, 34.0)
	_o(ctx, 4, 30, "tree_bare")
	_o(ctx, 13, 33, "tree_bare")
	_d(ctx, 8, 31, "corpse_a")
	_d(ctx, 10, 30, "blood_b")
	# 东南熟麦田：中央空腔藏资源点（原玉米墙 tile 视觉误读为茅草屋，弃用）
	_crop_field(ctx, 26, 25, 36, 35, "crops_tall_a")
	for y in range(28, 33):
		for x in range(26, 34):
			_g(ctx, x, y, _ground_tile(ctx["rng"], "grass"))
	_d(ctx, 31, 30, "straw_mid")
	_cluster(ctx, ["bush_c", "tree_stump", "tree_shrub_a"], 20, 33, 3, 5)

	_slot(ctx, "slot_spawn", 19.5, 34.5)
	_slot(ctx, "slot_vehicle", 34.5, 5.5)
	_slot(ctx, "slot_vehicle", 5.5, 20.5)
	_slot(ctx, "slot_resource", 8.5, 30.5)
	_slot(ctx, "slot_resource", 30.5, 30.5)
	_slot(ctx, "slot_resource", 12.5, 6.5)
	_slot(ctx, "slot_bandage", 22.5, 12.5)
	_slot(ctx, "slot_bandage", 27.5, 33.5)
	_save_module(ctx, "module_grove", "林间墓园", "grove")
