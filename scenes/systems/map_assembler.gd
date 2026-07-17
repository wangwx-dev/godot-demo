class_name MapAssembler
extends Node2D
## 战斗图拼接器（mapgen-design：2×2 模块网格、同图不重复、随机旋转变体）。
## 连通性由模块规格保证（四边开放），不做运行时检查。
## 旋转为 90° 步进绕模块中心（4 变体/模块）；镜像弃用——负缩放会破坏物理体，
## 4 旋转 × 6 模块 × 选 4 的组合量对防背板已够用。
## 拼好后汇总全局插槽坐标供关卡取用；随机全走 RunRng "mapgen" 流。

const MODULE_POOL: Array = [
	preload("res://resources/modules/module_supermarket.tres"),
	preload("res://resources/modules/module_gas_station.tres"),
	preload("res://resources/modules/module_parking.tres"),
	preload("res://resources/modules/module_street.tres"),
	preload("res://resources/modules/module_park.tres"),
	preload("res://resources/modules/module_construction.tres"),
]

var supply_slots: Array[Vector2] = []
var vehicle_slots: Array[Vector2] = []
var bandage_slots: Array[Vector2] = []
var spawn_slots: Array[Vector2] = []

var _modules: Array[MapModule] = []


## 拼 2×2 并收集插槽（调用后即可读四个插槽数组）。
func assemble() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("mapgen")
	var pool: Array = MODULE_POOL.duplicate()
	for cell in 4:
		var data: MapModuleData = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var module: MapModule = data.scene.instantiate()
		var cell_origin: Vector2 = Vector2(
				(cell % 2) * MapModule.SIZE, float(cell / 2) * MapModule.SIZE)
		var center: Vector2 = Vector2(MapModule.SIZE / 2.0, MapModule.SIZE / 2.0)
		module.rotation = rng.randi_range(0, 3) * PI / 2.0
		# 绕模块中心旋转且仍占满本格：position = 格原点 + center - R·center
		module.position = cell_origin + center - center.rotated(module.rotation)
		add_child(module)
		_modules.append(module)
	for module in _modules:
		_collect(module)


func _collect(module: MapModule) -> void:
	supply_slots.append_array(module.world_slots(module.supply_slots))
	vehicle_slots.append_array(module.world_slots(module.vehicle_slots))
	bandage_slots.append_array(module.world_slots(module.bandage_slots))
	spawn_slots.append_array(module.world_slots(module.spawn_slots))
