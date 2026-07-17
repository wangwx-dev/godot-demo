class_name EnemyBase
extends CharacterBody2D
## 丧尸状态机基类：Spawn → Chase →（接触攻击）→ Die（enemy-design 行为 AI 框架）。
## 数值全部来自 EnemyData（.tres 改数不动代码）；特殊尸继承本类重载 _on_death 等钩子。
## 群体移动 = 直线追踪 + boids 分离力 + 物理挤压，不用 NavMesh。

enum State { SPAWN, CHASE, DIE }

const BODY_RADIUS: float = 14.0
const SPAWN_DURATION: float = 0.4
const SEPARATION_RADIUS: float = 30.0
const SEPARATION_STRENGTH: float = 70.0
const KNOCKBACK_FRICTION: float = 800.0

@export var data: EnemyData

## 崩溃期叠层接口（pressure-design 死线）：刷入前由 HeatDirector 设置。
var hp_multiplier: float = 1.0
var speed_multiplier: float = 1.0
## 全体移速硬顶（崩溃期 200 < 玩家 220，"赶你走不是处刑"）。INF = 无顶。
var speed_cap: float = INF

var state: State = State.SPAWN
var hp: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO

var _spawn_timer: float = 0.0
var _damage_timer: float = 0.0
var _flash_timer: float = 0.0
var _player: Player

@onready var body_polygon: Polygon2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	hp = roundi(data.max_hp * hp_multiplier)
	body_polygon.color = data.outline_color
	body_polygon.scale = Vector2.ONE * data.sprite_scale
	# 缩放碰撞半径而非物理体节点（缩放物理体是 Godot 反模式）
	var shape: CircleShape2D = collision_shape.shape.duplicate()
	shape.radius = BODY_RADIUS * data.sprite_scale
	collision_shape.shape = shape
	modulate.a = 0.0
	_player = get_tree().get_first_node_in_group("player") as Player
	Debug.enemy_count += 1


func _exit_tree() -> void:
	Debug.enemy_count -= 1


func _process(delta: float) -> void:
	if state == State.DIE:
		return
	_flash_timer -= delta
	body_polygon.color = Color.WHITE if _flash_timer > 0.0 else data.outline_color


func _physics_process(delta: float) -> void:
	match state:
		State.SPAWN:
			_spawn_timer += delta
			modulate.a = minf(_spawn_timer / SPAWN_DURATION, 1.0)
			if _spawn_timer >= SPAWN_DURATION:
				state = State.CHASE
		State.CHASE:
			_chase(delta)
		State.DIE:
			pass


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var to_player: Vector2 = _player.global_position - global_position
	var effective_speed: float = minf(data.speed * speed_multiplier, speed_cap)
	var desired: Vector2 = to_player.normalized() * effective_speed + _separation()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	velocity = desired.limit_length(effective_speed) + knockback_velocity
	move_and_slide()
	# 接触攻击：贴身 + 自身攻击间隔到点（玩家侧另有 0.5s 受击无敌封顶）
	_damage_timer -= delta
	var reach: float = BODY_RADIUS * data.sprite_scale + 14.0 + 6.0
	if _damage_timer <= 0.0 and to_player.length() <= reach:
		_player.take_damage(data.contact_damage)
		_damage_timer = data.damage_interval


## 分离力：邻居越近推得越狠（enemy-design：互相推挤形成的包围就是威胁）。
func _separation() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self:
			continue
		var other: EnemyBase = node as EnemyBase
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		if distance > 0.01 and distance < SEPARATION_RADIUS:
			push += offset / distance * (1.0 - distance / SEPARATION_RADIUS)
	return push * SEPARATION_STRENGTH


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if state == State.DIE:
		return
	hp -= amount
	_flash_timer = 0.1
	knockback_velocity += knockback
	if hp <= 0:
		state = State.DIE
		collision_shape.set_deferred("disabled", true)
		_on_death()


## 死亡钩子，特殊尸重载（如臃肿者延迟爆炸）。
func _on_death() -> void:
	_spawn_drops()
	queue_free()


func _spawn_drops() -> void:
	var pool: ObjectPool = get_tree().get_first_node_in_group("pickup_pool") as ObjectPool
	if pool == null:
		return
	var rng: RandomNumberGenerator = RunRng.stream("loot")
	for i in data.xp_drop:
		var orb: Pickup = pool.acquire() as Pickup
		var offset: Vector2 = Vector2(rng.randf_range(-10.0, 10.0), rng.randf_range(-10.0, 10.0))
		orb.activate(Pickup.Kind.XP, 1, global_position + offset)
	if rng.randf() < data.gold_chance:
		var coin: Pickup = pool.acquire() as Pickup
		coin.activate(Pickup.Kind.GOLD, 1, global_position + Vector2(0, 12))
