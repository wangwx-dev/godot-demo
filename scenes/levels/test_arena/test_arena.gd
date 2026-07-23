extends Node2D
## 战斗图（M6 起兼精英图）：模块拼装 + 迷雾 + 资源点 + 载具出口 + 词缀精英。
## 验收（mvp-plan M6）：两辆载具目的地不同时会纠结吗？会在"还剩几天"层面做规划吗？
## Tab 切主武器、F4 快进死线（Debug）、死亡后 R 开新局（新种子）。

const MAP_SIZE: float = 2560.0
const MODULE_SIZE: float = 1280.0

const BAT_DATA: WeaponData = preload("res://resources/weapons/weapon_bat.tres")
const PISTOL_DATA: WeaponData = preload("res://resources/weapons/weapon_pistol.tres")
const MOLOTOV_DATA: WeaponData = preload("res://resources/weapons/weapon_molotov.tres")
const PICKUP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_elite.tscn")
const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")
const RUNNER_DATA: EnemyData = preload("res://resources/enemies/enemy_runner.tres")

const VEHICLE_MIN_SPAWN_DIST: float = 1200.0  ## 载具距投放点（不能落地就看见出口）
const VEHICLE_MIN_GAP: float = 1000.0  ## 载具两两间距（找到一辆≠找到全部）
const ROAM_ELITE_CHANCE: float = 0.15  ## 普通图游荡精英概率（enemy-design 待定）
const REINFORCE_TIME: float = 150.0  ## 精英图死线过半增援（2:30）

var _current_weapon: WeaponBase
var _current_sub_weapon: WeaponBase
var _director: HeatDirector
var _death_layer: CanvasLayer
var _assembler: MapAssembler
var _fog: FogOverlay
var _is_elite_map: bool = false
var _reinforced: bool = false

@onready var player: Player = $Player


func _ready() -> void:
	player.set_camera_limits(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	_build_boundary_walls()
	_assembler = MapAssembler.new()
	add_child(_assembler)
	# 拼装器压到最底层：正式素材模块整图铺 tile，不压底会盖住先入树的 Player
	move_child(_assembler, 0)
	_assembler.assemble()
	# 玩家投放：随机投放槽（叙事：从上一辆载具下车，mapgen-design）
	var spawn_rng: RandomNumberGenerator = RunRng.stream("mapgen")
	player.position = _assembler.spawn_slots[spawn_rng.randi_range(0, _assembler.spawn_slots.size() - 1)]
	player.get_node("Camera2D").reset_smoothing.call_deferred()
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.add_to_group("pickup_pool")
	add_child(pool)
	_is_elite_map = RunState.current_map_type == RunState.MapType.ELITE
	_director = HeatDirector.new()
	_director.map_rect = Rect2(0, 0, MAP_SIZE, MAP_SIZE)
	_director.is_elite_map = _is_elite_map
	add_child(_director)
	var hud: PressureHud = PressureHud.new()
	add_child(hud)
	hud.setup(_director)
	var game_hud: GameHud = GameHud.new()
	game_hud.battle_mode = true
	game_hud.director = _director
	add_child(game_hud)
	_equip(PISTOL_DATA)
	# 副武器起始：燃烧瓶直接挂上（正式版空槽进图搜，此处保留 MVP 起始便利）
	_equip_sub(MOLOTOV_DATA)
	add_child(LevelUpMenu.new())
	add_child(BackpackSwapMenu.new())
	_place_resource_points()
	# 迷雾+迷你图（图内生命周期，tech-design §2）
	_fog = FogOverlay.new()
	add_child(_fog)
	_fog.setup(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	var minimap: Minimap = Minimap.new()
	add_child(minimap)
	minimap.setup(_fog)
	_place_vehicles()
	_place_elites()
	EventBus.player_died.connect(_on_player_died)
	Sfx.bgm("battle")
	queue_redraw()


## 精英图死线过半（2:30）增援 1 只 1 词缀精英（enemy-design 精英配置）。
func _physics_process(_delta: float) -> void:
	if _is_elite_map and not _reinforced and _director.map_time >= REINFORCE_TIME:
		_reinforced = true
		var rng: RandomNumberGenerator = RunRng.stream("enemy")
		var angle: float = rng.randf_range(0.0, TAU)
		var pos: Vector2 = player.global_position + Vector2.from_angle(angle) * 700.0
		pos.x = clampf(pos.x, 100.0, MAP_SIZE - 100.0)
		pos.y = clampf(pos.y, 100.0, MAP_SIZE - 100.0)
		var elite: EnemyElite = _make_elite(1, rng)
		add_child(elite)
		elite.global_position = pos
		print("[TestArena] 精英增援抵达")


## 载具出口：从模块载具槽取位，距投放点 ≥1200、两两 ≥1000（mapgen-design 摆放约束）；
## 槽位不满足时逐档放宽——约束是体验目标不是硬校验。
func _place_vehicles() -> void:
	var candidates: Array[int] = RunState.roll_candidates()
	var rng: RandomNumberGenerator = RunRng.stream("mapgen")
	var slots: Array[Vector2] = _assembler.vehicle_slots.duplicate()
	for i in range(slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	var picked: Array[Vector2] = []
	for relax in [1.0, 0.75, 0.5, 0.0]:
		picked.clear()
		for slot in slots:
			if slot.distance_to(player.position) < VEHICLE_MIN_SPAWN_DIST * relax:
				continue
			var too_close: bool = false
			for other in picked:
				if slot.distance_to(other) < VEHICLE_MIN_GAP * relax:
					too_close = true
					break
			if not too_close:
				picked.append(slot)
			if picked.size() >= candidates.size():
				break
		if picked.size() >= candidates.size():
			break
	for i in candidates.size():
		var vehicle: Vehicle = Vehicle.new()
		vehicle.destination = candidates[i]
		vehicle.position = picked[i] if i < picked.size() else Vector2(MAP_SIZE - 200, MAP_SIZE - 200)
		add_child(vehicle)


## 精英配置（enemy-design）：精英图 1 只 2 词缀守离出生最远的资源点（高价值把守占位），
## 旁边多刷 1 个货币箱放大收益；普通图 15% 游荡 1 只 1 词缀（可绕开，打了有赏）。
func _place_elites() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	if _is_elite_map:
		var guard_target: ResourcePoint = null
		var best: float = -1.0
		for node in get_tree().get_nodes_in_group("resource_points"):
			var point: ResourcePoint = node as ResourcePoint
			var distance: float = point.position.distance_to(player.position)
			if distance > best:
				best = distance
				guard_target = point
		if guard_target == null:
			return
		var elite: EnemyElite = _make_elite(2, rng)
		add_child(elite)
		elite.global_position = guard_target.position + Vector2(60, 0)
		var bonus: ResourcePoint = ResourcePoint.new()
		bonus.kind = ResourcePoint.Kind.GOLD
		bonus.position = guard_target.position + Vector2(-70, 40)
		add_child(bonus)
	elif rng.randf() < ROAM_ELITE_CHANCE:
		var slots: Array[Vector2] = _assembler.supply_slots
		if slots.is_empty():
			return
		var pos: Vector2 = slots[rng.randi_range(0, slots.size() - 1)]
		if pos.distance_to(player.position) < 600.0:
			return  # 太近出生点就不放——游荡精英该是"路上撞见"
		var elite: EnemyElite = _make_elite(1, rng)
		add_child(elite)
		elite.global_position = pos
		print("[TestArena] 本图有游荡精英")


func _make_elite(affix_count: int, rng: RandomNumberGenerator) -> EnemyElite:
	var elite: EnemyElite = ELITE_SCENE.instantiate()
	elite.data = WALKER_DATA if rng.randf() < 0.6 else RUNNER_DATA
	var pool: Array[int] = [EnemyElite.Affix.FRENZY, EnemyElite.Affix.SUMMON, EnemyElite.Affix.TOUGH]
	for i in affix_count:
		elite.affixes.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return elite


## 按战斗图分布表从模块插槽取位（economy-design 分布 × mapgen-design 插槽承接）。
## 插槽随机取不放回；出生点 300px 内的槽跳过（开局脚下就是箱子没有"去搜"的感觉）。
func _place_resource_points() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("mapgen")
	var supply_pool: Array[Vector2] = _shuffled_slots(_assembler.supply_slots, rng)
	var bandage_pool: Array[Vector2] = _shuffled_slots(_assembler.bandage_slots, rng)
	var counts: Array = [
		[ResourcePoint.Kind.SUPPLY, rng.randi_range(1, 2)],
		[ResourcePoint.Kind.GOLD, rng.randi_range(0, 1)],
		[ResourcePoint.Kind.XP_MINE, 1],
		[ResourcePoint.Kind.WEAPON, 1 if rng.randf() < 0.33 else 0],
	]
	for spec in counts:
		for i in spec[1]:
			if supply_pool.is_empty():
				return
			var point: ResourcePoint = ResourcePoint.new()
			point.kind = spec[0]
			point.position = supply_pool.pop_back()
			if spec[0] == ResourcePoint.Kind.WEAPON:
				point.looted_weapon.connect(_on_weapon_looted)
			add_child(point)
	for i in rng.randi_range(1, 2):
		if bandage_pool.is_empty():
			return
		var bandage: Bandage = Bandage.new()
		bandage.position = bandage_pool.pop_back()
		add_child(bandage)


func _shuffled_slots(slots: Array[Vector2], rng: RandomNumberGenerator) -> Array[Vector2]:
	var pool: Array[Vector2] = []
	for slot in slots:
		if slot.distance_to(player.position) > 300.0:
			pool.append(slot)
	# Fisher-Yates（走 mapgen 流保持种子复现）
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2 = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool


## 武器箱产出：捡新的必须丢旧的，按槽位分发（weapon-design：换装决策 + 换武器清等级）。
func _on_weapon_looted(weapon: WeaponData) -> void:
	print("[TestArena] 武器箱开出: %s" % weapon.display_name)
	if weapon.slot == WeaponData.Slot.MAIN:
		_equip(weapon)
	else:
		_equip_sub(weapon)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_TAB:
			# 切换球棒/手枪——验收对照用，正式版起始二选一
			if OS.is_debug_build():
				_equip(BAT_DATA if _current_weapon.data == PISTOL_DATA else PISTOL_DATA)
		KEY_F4:
			# 快进到死线前 70s，验证最后 60s 警告 + 崩溃（Debug 门控）
			if OS.is_debug_build():
				_director.map_time = HeatDirector.DEADLINE - 70.0
		KEY_R:
			# 死亡后开新局：新种子+状态清零（临时试玩循环，正式死亡结算归 M7）
			if _death_layer != null:
				MapFlow.restart_run(get_tree())


## 主武器几何 → 实现类。新几何加武器时只需在这张表挂一行（weapon-design 主武器清单）。
## GDScript 限制：class_name 引用不是常量表达式，这两张表不能声明为 const。
var MAIN_WEAPON_CLASSES: Dictionary = {
	WeaponData.Geometry.ARC: WeaponArc,
	WeaponData.Geometry.LINE: WeaponLine,
	WeaponData.Geometry.SCATTER: WeaponScatter,
	WeaponData.Geometry.CONE: WeaponCone,
}

## 副武器几何 → 实现类（weapon-design 副武器清单：爆发/控场/功能三类）。
var SUB_WEAPON_CLASSES: Dictionary = {
	WeaponData.Geometry.AREA: WeaponArea,
	WeaponData.Geometry.BURST: WeaponBurst,
	WeaponData.Geometry.TRAP: WeaponTrap,
	WeaponData.Geometry.STUN: WeaponStun,
	WeaponData.Geometry.DECOY: WeaponDecoy,
	WeaponData.Geometry.BUFF: WeaponBuff,
}


func _equip(weapon_data: WeaponData) -> void:
	if _current_weapon != null:
		RunState.clear_weapon_level(_current_weapon.data)  # 换主武器清专属等级（通用强化保留）
		_current_weapon.queue_free()
	var weapon_class: Script = MAIN_WEAPON_CLASSES.get(weapon_data.geometry, WeaponLine)
	_current_weapon = weapon_class.new()
	_current_weapon.data = weapon_data
	player.add_child(_current_weapon)
	print("[TestArena] 武器: %s" % weapon_data.display_name)


func _equip_sub(weapon_data: WeaponData) -> void:
	if _current_sub_weapon != null:
		RunState.clear_weapon_level(_current_sub_weapon.data)
		_current_sub_weapon.queue_free()
	var weapon_class: Script = SUB_WEAPON_CLASSES.get(weapon_data.geometry, WeaponArea)
	_current_sub_weapon = weapon_class.new()
	_current_sub_weapon.data = weapon_data
	player.add_child(_current_sub_weapon)
	print("[TestArena] 副武器: %s" % weapon_data.display_name)


## 死亡结算（M7 正式版）：损失明账 + R 重开。
func _on_player_died() -> void:
	_death_layer = RunSummary.show_death(self)


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
	# 模块分界线（淡，模块本身有障碍与水印做识别）
	for i in range(1, int(MAP_SIZE / MODULE_SIZE)):
		var offset: float = i * MODULE_SIZE
		draw_line(Vector2(offset, 0), Vector2(offset, MAP_SIZE), Color(0.22, 0.22, 0.21), 2.0)
		draw_line(Vector2(0, offset), Vector2(MAP_SIZE, offset), Color(0.22, 0.22, 0.21), 2.0)
	# 图边界
	draw_rect(Rect2(0, 0, MAP_SIZE, MAP_SIZE), Color(0.6, 0.3, 0.25), false, 8.0)
