extends SceneTree
## 视觉 QA：把 6 个模块与一次 2×2 拼接结果渲染成 PNG（tools/previews/）。
## 需要 GPU，运行（会闪一个小窗口）：
##   godot --path . --script res://tools/render_map_previews.gd

const MODULE_NAMES: Array = [
	"module_gas_station", "module_crossroad", "module_farm",
	"module_barnyard", "module_town", "module_grove",
]
const OUT_DIR: String = "res://tools/previews/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_run()


func _run() -> void:
	await process_frame
	# 单模块：1280 → 640
	for module_name in MODULE_NAMES:
		var scene: PackedScene = load("res://scenes/levels/modules/tiled/%s.tscn" % module_name)
		var node: Node2D = scene.instantiate()
		node.scale = Vector2(0.5, 0.5)
		await _shoot(node, Vector2i(640, 640), OUT_DIR + module_name + ".png")
	# 2×2 拼接示例（正式素材模块不旋转，见 MapAssembler；--script 模式无 autoload，用本地固定种子流）
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("mapgen:42")
	var indices: Array = range(MODULE_NAMES.size())
	for i in range(indices.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var assembled: Node2D = Node2D.new()
	for slot_index in range(4):
		var scene: PackedScene = load("res://scenes/levels/modules/tiled/%s.tscn" % MODULE_NAMES[indices[slot_index]])
		var module: Node2D = scene.instantiate()
		var gx: int = slot_index % 2
		@warning_ignore("integer_division")
		var gy: int = slot_index / 2
		module.position = Vector2(gx * 1280.0, gy * 1280.0)
		assembled.add_child(module)
	assembled.scale = Vector2(0.25, 0.25)
	await _shoot(assembled, Vector2i(640, 640), OUT_DIR + "assembled_2x2.png")
	print("[render_map_previews] 完成 -> tools/previews/")
	quit(0)


func _shoot(node: Node2D, size: Vector2i, out_path: String) -> void:
	var vp: SubViewport = SubViewport.new()
	vp.size = size
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	root.add_child(vp)
	vp.add_child(node)
	await process_frame
	await process_frame
	var img: Image = vp.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(out_path))
	print("[render_map_previews] ", out_path)
	vp.queue_free()
