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


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
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
	draw_circle(Vector2.ZERO, radius, Color(0.95, 0.45, 0.1, 0.30 * flicker * fade))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1.0, 0.7, 0.2, 0.30 * flicker * fade))
