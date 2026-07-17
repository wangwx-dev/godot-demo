extends Node2D
## M1 战斗实测图：2560×2560 + 简易刷怪器 + 武器装配 + 拾取物池。
## 正式刷怪节奏归 M2 HeatDirector，这里只用固定间隔喂验收问题：
## 奔跑者紧张吗？臃肿者改打法吗？球棒/手枪是两种游戏吗？（Tab 切换武器）

const MAP_SIZE: float = 2560.0
const MODULE_SIZE: float = 1280.0

const WALKER_INTERVAL: float = 1.2
const RUNNER_INTERVAL: float = 9.0
const BLOATER_INTERVAL: float = 14.0
const SPAWN_DISTANCE_MIN: float = 700.0
const SPAWN_DISTANCE_MAX: float = 900.0

const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_base.tscn")
const BLOATER_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_bloater.tscn")
const PICKUP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup.tscn")

const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")
const RUNNER_DATA: EnemyData = preload("res://resources/enemies/enemy_runner.tres")
const BLOATER_DATA: EnemyData = preload("res://resources/enemies/enemy_bloater.tres")

const BAT_DATA: WeaponData = preload("res://resources/weapons/weapon_bat.tres")
const PISTOL_DATA: WeaponData = preload("res://resources/weapons/weapon_pistol.tres")

var _walker_timer: float = 0.0
var _runner_timer: float = 4.0
var _bloater_timer: float = 8.0
var _current_weapon: WeaponBase

@onready var player: Player = $Player


func _ready() -> void:
	player.set_camera_limits(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.add_to_group("pickup_pool")
	add_child(pool)
	_equip(PISTOL_DATA)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	# Tab 切换球棒/手枪——M1 验收"两种游戏"专用，正式版起始二选一
	if key_event.physical_keycode == KEY_TAB:
		_equip(BAT_DATA if _current_weapon.data == PISTOL_DATA else PISTOL_DATA)


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


func _physics_process(delta: float) -> void:
	_walker_timer -= delta
	_runner_timer -= delta
	_bloater_timer -= delta
	if _walker_timer <= 0.0:
		_walker_timer = WALKER_INTERVAL
		_spawn(ENEMY_SCENE, WALKER_DATA)
	if _runner_timer <= 0.0:
		_runner_timer = RUNNER_INTERVAL
		_spawn(ENEMY_SCENE, RUNNER_DATA)
	if _bloater_timer <= 0.0:
		_bloater_timer = BLOATER_INTERVAL
		_spawn(BLOATER_SCENE, BLOATER_DATA)


func _spawn(scene: PackedScene, data: EnemyData) -> void:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(SPAWN_DISTANCE_MIN, SPAWN_DISTANCE_MAX)
	var pos: Vector2 = player.global_position + Vector2.from_angle(angle) * distance
	pos.x = clampf(pos.x, 40.0, MAP_SIZE - 40.0)
	pos.y = clampf(pos.y, 40.0, MAP_SIZE - 40.0)
	var enemy: EnemyBase = scene.instantiate()
	enemy.data = data
	add_child(enemy)
	enemy.global_position = pos


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
