extends Node2D
## 总攻图（M8 占位版，game-design 总攻规则）：固定小图（接应点+尸巢，无迷雾），
## 三词缀超级精英"尸巢督军"守东侧尸巢 + 崩溃级持续涌潮（间隔递减、速度硬顶 200）。
## 杀死督军 = 撤离成功（带出金币）；死亡照旧全部丢失。正式 Boss 战设计归第二版。

const MAP_SIZE: float = 1280.0

const ARENA_SCENE: PackedScene = preload("res://scenes/levels/assault_map/assault_arena.tscn")
const ELITE_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_elite.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_base.tscn")
const BLOATER_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_bloater.tscn")
const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")
const RUNNER_DATA: EnemyData = preload("res://resources/enemies/enemy_runner.tres")
const BLOATER_DATA: EnemyData = preload("res://resources/enemies/enemy_bloater.tres")
const BAT_DATA: WeaponData = preload("res://resources/weapons/weapon_bat.tres")
const PISTOL_DATA: WeaponData = preload("res://resources/weapons/weapon_pistol.tres")
const MOLOTOV_DATA: WeaponData = preload("res://resources/weapons/weapon_molotov.tres")
const PICKUP_SCENE: PackedScene = preload("res://scenes/entities/pickups/pickup.tscn")

const BOSS_HP_BASE_MULT: float = 3.0  ## 精英 ×6 之上的底板加成：walker 30 → 540
const BOSS_SPAWN: Vector2 = Vector2(1000, 640)
const PLAYER_SPAWN: Vector2 = Vector2(220, 640)
const SPEED_CAP: float = 200.0  ## 崩溃级涌潮沿用死线速度硬顶（赶你走不是处刑）
const WAVE_START_INTERVAL: float = 2.6
const WAVE_MIN_INTERVAL: float = 1.2
const WAVE_RAMP: float = 0.97  ## 每波间隔乘数——总攻没有安全期
const ENEMY_CAP: int = 70

var _boss: EnemyElite
var _boss_spawned: bool = false
var _ended: bool = false
var _wave_timer: float = 2.0
var _wave_interval: float = WAVE_START_INTERVAL
var _summary: RunSummary

@onready var player: Player = $Player


func _ready() -> void:
	var arena: Node2D = ARENA_SCENE.instantiate()
	add_child(arena)
	move_child(arena, 0)  # 整图铺 tile 压底，防盖住 Player
	_build_walls()
	player.position = PLAYER_SPAWN
	player.set_camera_limits(Rect2(0, 0, MAP_SIZE, MAP_SIZE))
	player.get_node("Camera2D").reset_smoothing.call_deferred()
	var pool: ObjectPool = ObjectPool.new()
	pool.scene = PICKUP_SCENE
	pool.add_to_group("pickup_pool")
	add_child(pool)
	# 武器同战斗图起手（信使：手枪 + 燃烧瓶副武器）
	var pistol: WeaponLine = WeaponLine.new()
	pistol.data = PISTOL_DATA
	player.add_child(pistol)
	var molotov: WeaponArea = WeaponArea.new()
	molotov.data = MOLOTOV_DATA
	player.add_child(molotov)
	add_child(LevelUpMenu.new())
	add_child(BackpackSwapMenu.new())
	_spawn_boss()
	var hud: GameHud = GameHud.new()
	hud.battle_mode = true
	hud.boss = _boss  # 警戒条位置换 Boss 血条（ui-design 总攻 HUD）
	add_child(hud)
	EventBus.player_died.connect(_on_player_died)
	Sfx.bgm("assault")


## 尸巢督军：三词缀超级精英（狂暴+召唤+坚韧），底板再放大。
func _spawn_boss() -> void:
	var boss_data: EnemyData = WALKER_DATA.duplicate()
	boss_data.display_name = "尸巢督军"
	boss_data.max_hp = roundi(WALKER_DATA.max_hp * BOSS_HP_BASE_MULT)
	boss_data.contact_damage = 15
	boss_data.sprite_scale = 1.4  # 精英 ×1.5 后 ≈2.1，Boss 的块头
	_boss = ELITE_SCENE.instantiate()
	_boss.data = boss_data
	_boss.affixes = [EnemyElite.Affix.FRENZY, EnemyElite.Affix.SUMMON, EnemyElite.Affix.TOUGH] as Array[int]
	add_child(_boss)
	_boss.global_position = BOSS_SPAWN
	_boss._aggroed = true  # 总攻没有"绕开"选项，落地即入战
	_boss_spawned = true


func _physics_process(delta: float) -> void:
	if _ended:
		return
	# 胜利判定：督军死亡即撤离成功（占位版规则）
	if _boss_spawned and not is_instance_valid(_boss):
		_win()
		return
	# 崩溃级持续涌潮：间隔递减，无死线无安全期
	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = _wave_interval
		_wave_interval = maxf(_wave_interval * WAVE_RAMP, WAVE_MIN_INTERVAL)
		_spawn_wave()


func _spawn_wave() -> void:
	if get_tree().get_nodes_in_group("enemies").size() >= ENEMY_CAP:
		return
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	for i in rng.randi_range(2, 4):
		var roll: float = rng.randf()
		var spawned: EnemyBase
		if roll < 0.15:
			spawned = BLOATER_SCENE.instantiate()
			spawned.data = BLOATER_DATA
		else:
			spawned = ENEMY_SCENE.instantiate()
			spawned.data = RUNNER_DATA if roll < 0.40 else WALKER_DATA
		spawned.speed_cap = SPEED_CAP
		add_child(spawned)
		# 图边环形刷入（朝玩家方向偏置，压迫感优先）
		var angle: float = rng.randf_range(0.0, TAU)
		var pos: Vector2 = player.global_position + Vector2.from_angle(angle) * rng.randf_range(430.0, 620.0)
		spawned.global_position = pos.clamp(Vector2(40, 40), Vector2(MAP_SIZE - 40, MAP_SIZE - 40))


func _win() -> void:
	_ended = true
	EventBus.run_ended.emit(true)
	_summary = RunSummary.show_extraction(self)


func _on_player_died() -> void:
	_ended = true
	_summary = RunSummary.show_death(self)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_R and _summary != null:
		MapFlow.restart_run(get_tree())


func _build_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var specs: Array = [
		[Vector2(MAP_SIZE / 2.0, -30), Vector2(MAP_SIZE + 120, 60)],
		[Vector2(MAP_SIZE / 2.0, MAP_SIZE + 30), Vector2(MAP_SIZE + 120, 60)],
		[Vector2(-30, MAP_SIZE / 2.0), Vector2(60, MAP_SIZE + 120)],
		[Vector2(MAP_SIZE + 30, MAP_SIZE / 2.0), Vector2(60, MAP_SIZE + 120)],
	]
	for spec in specs:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = spec[1]
		shape_node.shape = shape
		shape_node.position = spec[0]
		walls.add_child(shape_node)
	add_child(walls)
