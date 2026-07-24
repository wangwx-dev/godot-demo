class_name MapFlow
## 图型 → 场景/名称/配色 的静态映射（M6 场景流转）。
## 战斗与精英共用战斗图场景，进图后读 RunState.current_map_type 定差异。

const TYPE_NAMES: Array[String] = ["战斗", "精英", "休整", "商店", "总攻"]

const TYPE_COLORS: Array[Color] = [
	Color(0.75, 0.55, 0.3),   # 战斗：土黄
	Color(0.85, 0.3, 0.3),    # 精英：红
	Color(0.35, 0.75, 0.45),  # 休整：绿
	Color(0.4, 0.65, 0.9),    # 商店：蓝
	Color(0.8, 0.35, 0.8),    # 总攻：紫
]

const SCENE_PATHS: Dictionary = {
	RunState.MapType.BATTLE: "res://scenes/levels/test_arena/test_arena.tscn",
	RunState.MapType.ELITE: "res://scenes/levels/test_arena/test_arena.tscn",
	RunState.MapType.REST: "res://scenes/levels/rest_map/rest_map.tscn",
	RunState.MapType.SHOP: "res://scenes/levels/shop_map/shop_map.tscn",
	RunState.MapType.ASSAULT: "res://scenes/levels/assault_map/assault_map.tscn",
}


static func type_name(map_type: int) -> String:
	return TYPE_NAMES[map_type]


static func type_color(map_type: int) -> Color:
	return TYPE_COLORS[map_type]


## 出发去下一图（载具/信号弹共用入口）。
static func travel(tree: SceneTree, destination: int) -> void:
	RunState.depart(destination)
	tree.change_scene_to_file.call_deferred(SCENE_PATHS[destination])


## 死亡/撤离后重开一局：新种子 + 状态清零 + 回第 1 天战斗图。
static func restart_run(tree: SceneTree) -> void:
	RunRng.new_run()
	RunState.reset()
	tree.paused = false
	tree.change_scene_to_file.call_deferred(SCENE_PATHS[RunState.MapType.BATTLE])


## 结算后回主菜单：停 BGM，状态清零留给下次开始局时做。
static func to_main_menu(tree: SceneTree) -> void:
	tree.paused = false
	Sfx.bgm("")
	tree.change_scene_to_file.call_deferred("res://scenes/ui/main_menu.tscn")
