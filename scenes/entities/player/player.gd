class_name Player
extends CharacterBody2D
## 俯视角八方向移动的玩家控制器 + M1 战斗侧：受击/无敌/翻滚/死亡。
## 基础数值为 upgrade-design 锚点（220 移速/40 拾取/0.5s 受击无敌/翻滚 3s 冷却 160px 0.3s 无敌）。
## 血量记账在 RunState（跨图持续），本类只管判定与表现。

@export var max_speed: float = 220.0
## 加速度和减速度（像素/秒²），值越大手感越"跟手"
@export var acceleration: float = 1600.0
@export var friction: float = 2000.0
@export var pickup_radius: float = 40.0

@export var dodge_cooldown: float = 3.0
@export var dodge_distance: float = 160.0
@export var dodge_invuln: float = 0.3
const DODGE_DURATION: float = 0.15

var _hit_invuln_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO
var _dead: bool = false

@onready var body_polygon: Polygon2D = $Body


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_invuln_timer -= delta
	_dodge_cooldown_timer -= delta
	body_polygon.color = Color(0.9, 0.85, 0.6, 0.5 if is_invulnerable() else 1.0)

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity = _dodge_velocity
		move_and_slide()
		return

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0 and input_dir != Vector2.ZERO:
		_dodge_cooldown_timer = dodge_cooldown
		_dodge_timer = DODGE_DURATION
		_hit_invuln_timer = maxf(_hit_invuln_timer, dodge_invuln)
		_dodge_velocity = input_dir.normalized() * (dodge_distance / DODGE_DURATION)
		velocity = _dodge_velocity
		move_and_slide()
		return

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * max_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()


func is_invulnerable() -> bool:
	return _hit_invuln_timer > 0.0


## 敌人接触/爆炸调用。无敌帧内免疫；命中后开 0.5s 受击无敌（upgrade-design 锚点）。
func take_damage(amount: int) -> void:
	if _dead or is_invulnerable():
		return
	_hit_invuln_timer = 0.5
	if RunState.apply_damage(amount):
		_die()


func _die() -> void:
	_dead = true
	body_polygon.color = Color(0.4, 0.15, 0.15)
	EventBus.player_died.emit()


## 相机限制到图边界（关卡进场时调用，tech-design §1）。
func set_camera_limits(rect: Rect2) -> void:
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
