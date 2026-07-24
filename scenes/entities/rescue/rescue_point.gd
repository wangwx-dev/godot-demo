class_name RescuePoint
extends Node2D
## 救援点（npc-design）：被困 NPC + 预置守卫尸群编队。清光守卫即解救——
## NPC 跨局永久解锁对应据点服务（MetaProgress），并掉即时奖励后离场。
## 只认自己 spawn 的守卫（rescue_guard_id），不认游荡尸，保证一定清得完。

signal rescued(npc_id: String)

const ENEMY_SCENE: PackedScene = preload("res://scenes/entities/enemies/enemy_base.tscn")
const WALKER_DATA: EnemyData = preload("res://resources/enemies/enemy_walker.tres")
const RUNNER_DATA: EnemyData = preload("res://resources/enemies/enemy_runner.tres")

const GUARD_RADIUS: float = 190.0
const DISCOVER_TAG_COLOR: Color = Color(0.35, 0.85, 0.95)

static var _next_guard_id: int = 0

@export var npc_id: String = "medic"
@export var guard_count: int = 7

var discovered: bool = false
var rescued_done: bool = false

var _guard_id: int = -1
var _guards: Array = []
var _player: Player
var _npc_label: String = ""


func _ready() -> void:
	add_to_group("rescue_points")
	z_index = 4
	_player = get_tree().get_first_node_in_group("player") as Player
	_npc_label = _label_for(npc_id)
	_guard_id = _next_guard_id
	_next_guard_id += 1
	_spawn_guards()


func _spawn_guards() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("enemy")
	for i in guard_count:
		var enemy: EnemyBase = ENEMY_SCENE.instantiate()
		enemy.data = WALKER_DATA if rng.randf() < 0.7 else RUNNER_DATA
		enemy.rescue_guard_id = _guard_id
		get_parent().add_child(enemy)
		var angle: float = TAU * i / guard_count + rng.randf_range(-0.3, 0.3)
		var dist: float = rng.randf_range(60.0, GUARD_RADIUS - 20.0)
		enemy.global_position = global_position + Vector2.from_angle(angle) * dist
		_guards.append(enemy)


func _physics_process(_delta: float) -> void:
	if rescued_done:
		return
	var alive: int = 0
	for g in _guards:
		if is_instance_valid(g) and (g as EnemyBase).state != EnemyBase.State.DIE:
			alive += 1
	if alive == 0:
		_do_rescue()
	queue_redraw()


func _do_rescue() -> void:
	rescued_done = true
	var rng: RandomNumberGenerator = RunRng.stream("loot")
	var pool: ObjectPool = get_tree().get_first_node_in_group("pickup_pool") as ObjectPool
	if pool != null:
		var coin: Pickup = pool.acquire() as Pickup
		coin.activate(Pickup.Kind.GOLD, rng.randi_range(30, 50), global_position + Vector2(0, 10))
		var token: Pickup = pool.acquire() as Pickup
		token.activate(Pickup.Kind.UPGRADE, 1, global_position + Vector2(0, -12))
	RunState.rescued_this_run.append(npc_id)
	var first: bool = MetaProgress.unlock(npc_id)
	Sfx.play("ui_confirm", -3.0)
	print("[RescuePoint] 解救 %s（%s）" % [_npc_label, "首次解锁" if first else "重复救援"])
	rescued.emit(npc_id)
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var body_color: Color = Color(0.9, 0.85, 0.55)
	draw_circle(Vector2(0, -6), 9.0, body_color)
	draw_rect(Rect2(-7, 0, 14, 16), body_color)
	draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, DISCOVER_TAG_COLOR, 2.0)
	if not rescued_done:
		draw_string(ThemeDB.fallback_font, Vector2(-60, -30),
				"！待解救：%s" % _npc_label, HORIZONTAL_ALIGNMENT_CENTER, 120, 13,
				Color(0.95, 0.85, 0.4))
		draw_string(ThemeDB.fallback_font, Vector2(-70, 40),
				"清除周围尸群", HORIZONTAL_ALIGNMENT_CENTER, 140, 11, Color(0.8, 0.8, 0.75))


static func _label_for(id: String) -> String:
	match id:
		MetaProgress.VETERAN:
			return "老兵"
		MetaProgress.MEDIC:
			return "医师"
		MetaProgress.ARMORER:
			return "军械师"
	return id
