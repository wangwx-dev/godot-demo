class_name DecoyRadio
extends Node2D
## 诱饵收音机道具（WeaponDecoy 放置）：持续 duration 秒，每帧对 radius 内的敌人
## 续期"追我不追玩家"，到期或敌人离开范围后不再续期，几帧内自然回头——不需要
## 显式的"解除引怪"通知（诱饵消失=停止续期=自然到期，衰减制设计）。

var radius: float = 260.0
var duration: float = 10.0

var _age: float = 0.0


func setup(pull_radius: float, pull_duration: float) -> void:
	radius = pull_radius
	duration = pull_duration


func _ready() -> void:
	var body: AnimatedSprite2D = AnimatedSprite2D.new()
	body.sprite_frames = Fx.frames("pickups/radio", 2, 3.0, true)
	add_child(body)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.apply_lure(global_position, 0.35)
	queue_redraw()


func _draw() -> void:
	var fade: float = clampf((duration - _age) / 0.6, 0.0, 1.0)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, Color(0.3, 0.75, 0.9, 0.10 * fade), 2.0)
