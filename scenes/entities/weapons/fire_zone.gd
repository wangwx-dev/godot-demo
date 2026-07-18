class_name FireZone
extends Node2D
## 燃烧瓶火焰区域：持续期内区域中的敌人每秒扣伤（weapon-design 踩入 12/秒）。

var radius: float = 100.0
var duration: float = 4.0
var damage_per_second: int = 12

var _age: float = 0.0
var _tick_timer: float = 0.0


func setup(fire_radius: float, fire_duration: float, dps: int) -> void:
	radius = fire_radius
	duration = fire_duration
	damage_per_second = dps
	# 区域内撒火苗动画（错帧循环），随区域一起销毁
	var count: int = clampi(roundi(radius / 18.0), 4, 9)
	for i in count:
		var angle: float = TAU * i / count + randf() * 0.7
		var dist: float = radius * (0.25 + randf() * 0.55)
		var flame: AnimatedSprite2D = Fx.looping(self, "weapons/fire_small", 10,
				Vector2.from_angle(angle) * dist + Vector2(0, -18), 12.0, 0.8 + randf() * 0.4)
		flame.z_index = 1
	Fx.looping(self, "weapons/fire_small_alt", 10, Vector2(0, -20), 12.0, 1.2).z_index = 1


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	# 尾段整体淡出（火苗子节点跟着一起熄）
	modulate.a = clampf((duration - _age) / 0.6, 0.0, 1.0)
	# 0.25s 一跳，每跳 1/4 秒伤
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = 0.25
		var tick_damage: int = maxi(roundi(damage_per_second * 0.25), 1)
		for node in get_tree().get_nodes_in_group("enemies"):
			var enemy: EnemyBase = node as EnemyBase
			if enemy.state == EnemyBase.State.DIE:
				continue
			if global_position.distance_to(enemy.global_position) <= radius:
				enemy.take_damage(tick_damage)
	queue_redraw()


func _draw() -> void:
	var flicker: float = 0.8 + 0.2 * sin(_age * 20.0)
	var fade: float = clampf((duration - _age) / 0.6, 0.0, 1.0)
	# 火苗贴图当主视觉，底圈只留淡淡的灼烧范围提示
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.45, 0.1, 0.14 * flicker * fade))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.7, 0.2, 0.12 * flicker * fade))
