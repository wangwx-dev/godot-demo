class_name HeatDirector
extends Node
## 压力总监（pressure-design v1.3）：Heat 曲线 + 持续流 + 涌潮 + 死线崩溃。
## 图内生命周期——挂在战斗关卡下，换图即弃（tech-design §2 明确非 autoload）。
## 所有数字为 pressure-design 初版，试玩校准。

signal surge_incoming(direction: Vector2)  ## 3s 预警（UI 红光/低吼接这里）
signal deadline_warning  ## 最后 60s
signal collapsed

const HEAT_PER_SECOND: float = 1.0 / 20.0
const ELITE_HEAT_PER_SECOND: float = 1.0 / 16.0
const DEADLINE: float = 300.0  ## 5:00
const WARNING_TIME: float = 60.0

## 持续流表：[Heat 下限, 刷入间隔, 同屏上限, 特殊尸占比]
const FLOW_TABLE: Array = [
	[0, 3.0, 12, 0.0],
	[2, 2.2, 20, 0.10],
	[4, 1.6, 30, 0.20],
	[6, 1.1, 40, 0.25],
	[8, 0.8, 50, 0.30],
	[10, 0.6, 50, 0.35],
]

const SURGE_WARNING_DURATION: float = 3.0
const SURGE_HEAT_STEP: float = 2.0

const COLLAPSE_START_INTERVAL: float = 0.3
const COLLAPSE_INTERVAL_HALVING: float = 10.0
const COLLAPSE_SCREEN_CAP: int = 120
const COLLAPSE_BURST: int = 2  ## 崩溃期每次刷入只数
const COLLAPSE_STACK_TIME: float = 15.0
const COLLAPSE_HP_PER_STACK: float = 1.0
const COLLAPSE_SPEED_PER_STACK: float = 0.2
const COLLAPSE_SPEED_CAP: float = 200.0
const COLLAPSE_SPECIAL_RATIO: float = 0.35

const SPAWN_RING_MIN: float = 400.0
const SPAWN_RING_MAX: float = 600.0

const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_base.tscn")
const BLOATER_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_bloater.tscn")
const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")
const RUNNER_DATA: EnemyData = preload("res://resources/enemies/enemy_runner.tres")
const BLOATER_DATA: EnemyData = preload("res://resources/enemies/enemy_bloater.tres")

@export var map_rect: Rect2 = Rect2(0, 0, 2560, 2560)
@export var is_elite_map: bool = false

var heat: float = 0.0
var map_time: float = 0.0
var collapse: bool = false
## 行为压力开关：资源点驻留时置 true，刷入间隔减半（M4 接线）
var loot_pressure: bool = false

var _spawn_timer: float = 0.0
var _spawn_pause_timer: float = 0.0  ## 精英击杀 10s 安全窗接口（M6 接线）
var _next_surge_heat: float = SURGE_HEAT_STEP
var _surge_warning_timer: float = -1.0
var _surge_direction: Vector2 = Vector2.ZERO
var _collapse_interval: float = COLLAPSE_START_INTERVAL
var _collapse_time: float = 0.0
var _warned: bool = false
var _player: Player


func _ready() -> void:
	var base: int = mini(floori((RunState.day - 1) / 2.0), 4)
	if is_elite_map:
		base += 1
	heat = float(base)
	_next_surge_heat = heat + SURGE_HEAT_STEP
	_player = get_tree().get_first_node_in_group("player") as Player
	EventBus.heat_changed.emit(heat)


func time_left() -> float:
	return maxf(DEADLINE - map_time, 0.0)


func _physics_process(delta: float) -> void:
	map_time += delta
	if not collapse:
		var rate: float = ELITE_HEAT_PER_SECOND if is_elite_map else HEAT_PER_SECOND
		var old_heat: float = heat
		heat += rate * delta
		if floori(heat) != floori(old_heat):
			EventBus.heat_changed.emit(heat)
		_update_surge(delta)
		if not _warned and time_left() <= WARNING_TIME:
			_warned = true
			deadline_warning.emit()
		if map_time >= DEADLINE:
			_enter_collapse()
	else:
		_collapse_time += delta
	_update_flow(delta)
	Debug.heat = heat
	Debug.spawn_interval = _current_interval()


func _current_interval() -> float:
	if collapse:
		# 每 15s 减半：0.5 → 0.25 → 0.125 → …
		return COLLAPSE_START_INTERVAL / pow(2.0, floorf(_collapse_time / COLLAPSE_INTERVAL_HALVING))
	var row: Array = FLOW_TABLE[0]
	for candidate in FLOW_TABLE:
		if heat >= candidate[0]:
			row = candidate
	var interval: float = row[1]
	if loot_pressure:
		interval /= 2.0  # 开箱驻留：怪闻声而来
	return interval


func _screen_cap() -> int:
	if collapse:
		return COLLAPSE_SCREEN_CAP
	var row: Array = FLOW_TABLE[0]
	for candidate in FLOW_TABLE:
		if heat >= candidate[0]:
			row = candidate
	return row[2]


func _special_ratio() -> float:
	if collapse:
		return COLLAPSE_SPECIAL_RATIO
	var row: Array = FLOW_TABLE[0]
	for candidate in FLOW_TABLE:
		if heat >= candidate[0]:
			row = candidate
	return row[3]


func _update_flow(delta: float) -> void:
	_spawn_pause_timer -= delta
	if _spawn_pause_timer > 0.0:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = _current_interval()
	if Debug.enemy_count >= _screen_cap():
		return  # 达上限暂停刷入，不销毁远处敌人（待定 2）
	var burst: int = COLLAPSE_BURST if collapse else 1
	for i in burst:
		_spawn_one(_random_ring_position())


func _update_surge(delta: float) -> void:
	if _surge_warning_timer >= 0.0:
		_surge_warning_timer -= delta
		if _surge_warning_timer <= 0.0:
			_surge_warning_timer = -1.0
			_fire_surge()
		return
	if heat >= _next_surge_heat:
		_next_surge_heat += SURGE_HEAT_STEP
		var rng: RandomNumberGenerator = RunRng.stream("enemy")
		_surge_direction = Vector2.from_angle(rng.randf_range(0.0, TAU))
		_surge_warning_timer = SURGE_WARNING_DURATION
		surge_incoming.emit(_surge_direction)


func _fire_surge() -> void:
	var count: int = 6 + 2 * floori(heat)
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	for i in count:
		# 单侧集中刷入：方向 ±30° 扇形
		var angle: float = _surge_direction.angle() + rng.randf_range(-PI / 6.0, PI / 6.0)
		var distance: float = _ring_distance(angle) + rng.randf_range(0.0, 200.0)
		var pos: Vector2 = _player.global_position + Vector2.from_angle(angle) * distance
		_spawn_one(_clamp_to_map(pos), 0.10)


## 屏幕外 400~600px 环形随机点。
func _random_ring_position() -> Vector2:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	var angle: float = rng.randf_range(0.0, TAU)
	return _clamp_to_map(_player.global_position + Vector2.from_angle(angle) * _ring_distance(angle))


## 沿指定角度到屏幕边缘的距离 + 400~600 余量。
func _ring_distance(angle: float) -> float:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	var direction: Vector2 = Vector2.from_angle(angle)
	var half: Vector2 = get_viewport().get_visible_rect().size / 2.0
	var edge: float = minf(
		half.x / maxf(absf(direction.x), 0.001),
		half.y / maxf(absf(direction.y), 0.001)
	)
	return edge + rng.randf_range(SPAWN_RING_MIN, SPAWN_RING_MAX)


func _clamp_to_map(pos: Vector2) -> Vector2:
	pos.x = clampf(pos.x, map_rect.position.x + 40.0, map_rect.end.x - 40.0)
	pos.y = clampf(pos.y, map_rect.position.y + 40.0, map_rect.end.y - 40.0)
	return pos


func _spawn_one(pos: Vector2, extra_special: float = 0.0) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	var data: EnemyData = WALKER_DATA
	var scene: PackedScene = ENEMY_SCENE
	if rng.randf() < _special_ratio() + extra_special:
		# 特殊尸池按 Heat 解锁：2+ 奔跑者、4+ 臃肿者（各占一半）
		if heat >= 4.0 and rng.randf() < 0.5:
			data = BLOATER_DATA
			scene = BLOATER_SCENE
		elif heat >= 2.0:
			data = RUNNER_DATA
	var enemy: EnemyBase = scene.instantiate()
	enemy.data = data
	if collapse:
		var stacks: float = 1.0 + floorf(_collapse_time / COLLAPSE_STACK_TIME)
		enemy.hp_multiplier = 1.0 + COLLAPSE_HP_PER_STACK * stacks
		enemy.speed_multiplier = 1.0 + COLLAPSE_SPEED_PER_STACK * stacks
		enemy.speed_cap = COLLAPSE_SPEED_CAP
	get_parent().add_child(enemy)
	enemy.global_position = pos


func _enter_collapse() -> void:
	collapse = true
	_collapse_time = 0.0
	_surge_warning_timer = -1.0  # 涌潮停止
	# 已在场敌人也压硬顶——"全体敌人"含存量（pressure-design v1.3）
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		enemy.speed_cap = COLLAPSE_SPEED_CAP
	EventBus.deadline_collapsed.emit()
	collapsed.emit()


## 精英击杀 10s 安全窗（pressure-design 行为压力；M6 精英实装时调用）。
func pause_spawning(duration: float) -> void:
	_spawn_pause_timer = duration
