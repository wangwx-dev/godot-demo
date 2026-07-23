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

## 控场接口（weapon-design 副武器：捕兽夹定身/闪光弹眩晕）。
var _control_timer: float = 0.0
var _control_mult: float = 1.0
## 诱饵接口（诱饵收音机）：拉扯期间追逐目标改为诱饵位置，衰减制——诱饵每帧续期，
## 离开引怪半径或诱饵消失后自然到期，不需要额外的"退出引怪"通知。
var _lure_pos: Vector2 = Vector2.ZERO
var _lure_timer: float = 0.0

var state: State = State.SPAWN
var hp: int = 0
var knockback_velocity: Vector2 = Vector2.ZERO

var _spawn_timer: float = 0.0
var _damage_timer: float = 0.0
var _flash_timer: float = 0.0
var _player: Player

@onready var body: AnimatedSprite2D = $Body
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	hp = roundi(data.max_hp * hp_multiplier)
	body.sprite_frames = Fx.dir_frames("enemies/" + data.sprite_set + ".png", 7.0)
	body.play("walk_down")
	body.frame = randi() % 8  # 错帧起播，尸群不齐步走
	body.offset = Vector2(0, -18)
	body.scale = Vector2.ONE * data.sprite_scale
	# 染色保留"轮廓即身份"的颜色语言（同底板丧尸靠体型+色相区分）
	body.modulate = Color.WHITE.lerp(data.outline_color, 0.35)
	body.material = Fx.flash_material()
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
	(body.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if _flash_timer > 0.0 else 0.0)


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


## 定身/眩晕：duration 内移速乘 speed_mult（0.0=完全定住），取最长剩余时长续期。
func apply_control(duration: float, speed_mult: float) -> void:
	_control_timer = maxf(_control_timer, duration)
	_control_mult = speed_mult


## 诱饵拉扯：追逐目标暂改为 pos，refresh_duration 内有效——诱饵每帧对范围内敌人续期，
## 敌人离开引怪半径后不再续期，几帧内自然到期回头追玩家。
func apply_lure(pos: Vector2, refresh_duration: float) -> void:
	_lure_pos = pos
	_lure_timer = refresh_duration


func _chase(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	if _control_timer > 0.0:
		_control_timer -= delta
		if _control_timer <= 0.0:
			_control_mult = 1.0
	if _lure_timer > 0.0:
		_lure_timer -= delta
	var chase_target: Vector2 = _lure_pos if _lure_timer > 0.0 else _player.global_position
	var to_player: Vector2 = chase_target - global_position
	var effective_speed: float = minf(data.speed * speed_multiplier * _control_mult, speed_cap)
	var desired: Vector2 = to_player.normalized() * effective_speed + _separation()
	knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
	velocity = desired.limit_length(effective_speed) + knockback_velocity
	move_and_slide()
	if velocity.length() > 4.0:
		var anim: String = "walk_" + Fx.dir_name(velocity)
		if body.animation != anim:
			body.play(anim)
	body.speed_scale = clampf(effective_speed / 120.0, 0.6, 2.2)
	# 接触攻击：贴身 + 自身攻击间隔到点（判定始终对真玩家，被诱饵拉走时天然打不到）
	_damage_timer -= delta
	var reach: float = BODY_RADIUS * data.sprite_scale + 14.0 + 6.0
	if _damage_timer <= 0.0 and _player.global_position.distance_to(global_position) <= reach:
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
	Sfx.play("hit_flesh", -10.0, 60)
	if hp <= 0:
		state = State.DIE
		RunState.kills += 1
		Sfx.play("kill_dissolve", -10.0, 90)
		collision_shape.set_deferred("disabled", true)
		_on_death()


## 死亡钩子，特殊尸重载（如臃肿者延迟爆炸）。
func _on_death() -> void:
	Fx.blood_decal(get_parent(), global_position, data.sprite_scale)
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
