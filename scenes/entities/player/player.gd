class_name Player
extends CharacterBody2D
## 俯视角八方向移动的玩家控制器 + M1 战斗侧：受击/无敌/翻滚/死亡。
## 基础数值为 upgrade-design 锚点（220 移速/40 拾取/0.5s 受击无敌/翻滚 3s 冷却 120px 0.3s 无敌）。
## 血量记账在 RunState（跨图持续），本类只管判定与表现。

@export var max_speed: float = 220.0
## 加速度和减速度（像素/秒²），值越大手感越"跟手"
@export var acceleration: float = 1600.0
@export var friction: float = 2000.0
@export var pickup_radius: float = 40.0

@export var dodge_cooldown: float = 3.0
@export var dodge_distance: float = 120.0
@export var dodge_invuln: float = 0.3
const DODGE_DURATION: float = 0.15

var _hit_invuln_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_velocity: Vector2 = Vector2.ZERO
var _dead: bool = false
var _facing: String = "down"

@onready var body: AnimatedSprite2D = $Body


func _ready() -> void:
	add_to_group("player")
	# LPC 幸存者（tools/build_lpc_characters.py 合成）：四方向走路 + 站立
	body.sprite_frames = Fx.dir_frames("characters/lpc_survivor_walk.png", 11.0)
	body.offset = Vector2(0, -18)  # 脚底贴近碰撞中心（俯视 3/4 视角）
	body.play("idle_down")


## 强化聚合后的实效属性（每帧读，叠层即时生效）。
func effective_speed() -> float:
	return max_speed * (1.0 + RunState.stat_sum(UpgradeData.Effect.MOVE_SPEED_MULT))


func effective_pickup_radius() -> float:
	return pickup_radius * (1.0 + RunState.stat_sum(UpgradeData.Effect.PICKUP_RADIUS_MULT))


func effective_dodge_cooldown() -> float:
	return maxf(dodge_cooldown + RunState.stat_sum(UpgradeData.Effect.SKILL_COOLDOWN_ADD), 0.5)


## 翻滚冷却剩余占比（HUD 技能图标用）：1=刚用完，0=可用。
func dodge_cd_fraction() -> float:
	return clampf(_dodge_cooldown_timer / effective_dodge_cooldown(), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_invuln_timer -= delta
	_dodge_cooldown_timer -= delta
	body.modulate.a = 0.5 if is_invulnerable() else 1.0

	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_update_walk_anim(input_dir)

	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		velocity = _dodge_velocity
		move_and_slide()
		return

	if Input.is_action_just_pressed("dodge") and _dodge_cooldown_timer <= 0.0 and input_dir != Vector2.ZERO:
		_dodge_cooldown_timer = effective_dodge_cooldown()
		_dodge_timer = DODGE_DURATION
		_hit_invuln_timer = maxf(_hit_invuln_timer, dodge_invuln)
		_dodge_velocity = input_dir.normalized() * (dodge_distance / DODGE_DURATION)
		velocity = _dodge_velocity
		Sfx.play("dodge_roll", -8.0)
		move_and_slide()
		return

	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * effective_speed(), acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	move_and_slide()


## 四方向走路动画：主导轴定朝向，停下切站立帧，移速联动帧率。
func _update_walk_anim(input_dir: Vector2) -> void:
	if input_dir != Vector2.ZERO:
		_facing = Fx.dir_name(input_dir)
	var moving: bool = input_dir != Vector2.ZERO or _dodge_timer > 0.0
	body.speed_scale = maxf(effective_speed() / max_speed, 1.0)
	var anim: String = ("walk_" if moving else "idle_") + _facing
	if body.animation != anim:
		body.play(anim)


func is_invulnerable() -> bool:
	return _hit_invuln_timer > 0.0


## 敌人接触/爆炸调用。无敌帧内免疫；命中后开 0.5s 受击无敌（upgrade-design 锚点）。
func take_damage(amount: int) -> void:
	if _dead or is_invulnerable():
		return
	_hit_invuln_timer = 0.5
	_shake_camera()
	Sfx.play("player_hurt", -4.0)
	if RunState.apply_damage(amount):
		_die()


## 受击短震屏（ui-design 战斗反馈；红晕由 PressureHud 出）。
func _shake_camera() -> void:
	var camera: Camera2D = $Camera2D
	var tween: Tween = create_tween()
	for i in 3:
		tween.tween_property(camera, "offset",
				Vector2(randf_range(-7.0, 7.0), randf_range(-5.0, 5.0)), 0.04)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.06)


func _die() -> void:
	_dead = true
	body.pause()
	body.modulate = Color(0.55, 0.25, 0.25)
	Fx.blood_decal(get_parent(), global_position, 1.4)
	EventBus.player_died.emit()


## 相机限制到图边界（关卡进场时调用，tech-design §1）。
func set_camera_limits(rect: Rect2) -> void:
	var camera: Camera2D = $Camera2D
	camera.limit_left = int(rect.position.x)
	camera.limit_top = int(rect.position.y)
	camera.limit_right = int(rect.end.x)
	camera.limit_bottom = int(rect.end.y)
