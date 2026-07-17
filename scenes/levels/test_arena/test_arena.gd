extends Node2D
## M3 升级三选一实测图：HeatDirector 刷怪 + 主武器（Tab 切）+ 燃烧瓶副武器 + 三选一弹窗。
## 验收（mvp-plan M3）：白卡 1 层"有感觉"、3 层"明显变强"？
## F4 快进死线（Debug）。

const MAP_SIZE: float = 2560.0
const MODULE_SIZE: float = 1280.0

const BAT_DATA: WeaponData = preload("res://resources/weapons/weapon_bat.tres")
const PISTOL_DATA: WeaponData = preload("res://resources/weapons/weapon_pistol.tres")
const MOLOTOV_DATA: WeaponData = preload("res://resources/weapons/weapon_molotov.tres")
const PICKUP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup.tscn")

var _current_weapon: WeaponBase
var _director: HeatDirector
var _death_layer: CanvasLayer

@onready var player: Player = $Player


func _ready() -> void:
	player.set_camera_limits(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	_build_boundary_walls()
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.add_to_group("pickup_pool")
	add_child(pool)
	_director = HeatDirector.new()
	_director.map_rect = Rect2(0, 0, MAP_SIZE, MAP_SIZE)
	add_child(_director)
	var hud: PressureHud = PressureHud.new()
	add_child(hud)
	hud.setup(_director)
	_equip(PISTOL_DATA)
	# 副武器：燃烧瓶直接挂上（正式版进图搜/商店买，M4+；M3 先验证自动释放与强化）
	var molotov: WeaponArea = WeaponArea.new()
	molotov.data = MOLOTOV_DATA
	player.add_child(molotov)
	add_child(LevelUpMenu.new())
	EventBus.player_died.connect(_on_player_died)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_TAB:
			# 切换球棒/手枪——验收对照用，正式版起始二选一
			_equip(BAT_DATA if _current_weapon.data == PISTOL_DATA else PISTOL_DATA)
		KEY_F4:
			# 快进到死线前 70s，验证最后 60s 警告 + 崩溃（Debug 门控）
			if OS.is_debug_build():
				_director.map_time = HeatDirector.DEADLINE - 70.0
		KEY_R:
			# 死亡后重开一局（临时试玩循环，正式死亡结算归 M7）
			if _death_layer != null:
				RunState.reset()
				get_tree().reload_current_scene()


func _equip(weapon_data: WeaponData) -> void:
	if _current_weapon != null:
		_current_weapon.queue_free()
	if weapon_data.geometry == WeaponData.Geometry.ARC:
		_current_weapon = WeaponArc.new()
	else:
		_current_weapon = WeaponLine.new()
	_current_weapon.data = weapon_data
	player.add_child(_current_weapon)
	print("[TestArena] 武器: %s" % weapon_data.display_name)


## 死亡提示（临时版）：变暗红+不能动=死了，挂个字免得看不懂；正式结算画面归 M7。
func _on_player_died() -> void:
	_death_layer = CanvasLayer.new()
	_death_layer.layer = 99
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.1, 0.0, 0.0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_layer.add_child(dim)
	var label: Label = Label.new()
	label.text = "你死了
本局收益全丢（设计如此）

按 R 重开"
	label.add_theme_font_size_override("font_size", 40)
	label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.25))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_death_layer.add_child(label)
	add_child(_death_layer)


## 图边界物理墙（层 1）：玩家和敌人都撞得住，红框只是它的可视化。
func _build_boundary_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var half: float = MAP_SIZE / 2.0
	var thickness: float = 60.0
	var specs: Array = [
		[Vector2(half, -thickness / 2.0), Vector2(MAP_SIZE + thickness * 2.0, thickness)],
		[Vector2(half, MAP_SIZE + thickness / 2.0), Vector2(MAP_SIZE + thickness * 2.0, thickness)],
		[Vector2(-thickness / 2.0, half), Vector2(thickness, MAP_SIZE + thickness * 2.0)],
		[Vector2(MAP_SIZE + thickness / 2.0, half), Vector2(thickness, MAP_SIZE + thickness * 2.0)],
	]
	for spec in specs:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = spec[1]
		shape_node.shape = shape
		shape_node.position = spec[0]
		walls.add_child(shape_node)
	add_child(walls)


func _draw() -> void:
	# 地面底色
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.13, 0.14, 0.12))
	# 模块网格（1280 间隔）——判断"一屏 1.5 个模块"体感的参照线
	for i in range(1, int(MAP_SIZE / MODULE_SIZE)):
		var offset: float = i * MODULE_SIZE
		draw_line(Vector2(offset, 0), Vector2(offset, MAP_SIZE), Color(0.3, 0.3, 0.28), 4.0)
		draw_line(Vector2(0, offset), Vector2(MAP_SIZE, offset), Color(0.3, 0.3, 0.28), 4.0)
	# 图边界
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.6, 0.3, 0.25), false, 8.0)
	# 100px 刻度点（距离体感参照：奔跑者钻出距离/翻滚 120px 等都以它读）
	for x in range(0, int(MAP_SIZE) + 1, 100):
		for y in range(0, int(MAP_SIZE) + 1, 100):
			draw_circle(Vector2(x, y), 2.0, Color(0.22, 0.23, 0.21))
