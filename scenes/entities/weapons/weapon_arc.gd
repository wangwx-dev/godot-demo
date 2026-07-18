class_name WeaponArc
extends WeaponBase
## 弧形挥砍（球棒）：朝敌人最密集的方向挥，命中扇形内全体并击退（weapon-design）。
## 站位即瞄准——方向由范围内敌人位置的合向量决定，可预测。

var _swing_direction: Vector2 = Vector2.RIGHT
var _swing_age: float = 1.0
var _swing_arc: float = 150.0
var _swing_range: float = 80.0


func effective_arc() -> float:
	return data.geometry_params.get("arc_degrees", 150.0) + _level_sum("arc_add")


func _process(delta: float) -> void:
	_swing_age += delta
	if _swing_age < 0.18:
		queue_redraw()
	elif _swing_age - delta < 0.18:
		queue_redraw()  # 最后一帧清掉残影


func _try_attack() -> bool:
	var targets: Array[EnemyBase] = _enemies_in_range()
	if targets.is_empty():
		return false
	# 最密方向 = 范围内敌人相对方位的合向量
	var direction_sum: Vector2 = Vector2.ZERO
	for enemy in targets:
		direction_sum += (enemy.global_position - global_position).normalized()
	_swing_direction = direction_sum.normalized() if direction_sum.length() > 0.01 \
			else (targets[0].global_position - global_position).normalized()
	_swing_arc = effective_arc()
	_swing_range = effective_range()
	var half_arc: float = deg_to_rad(_swing_arc) / 2.0
	var damage: int = effective_damage()
	var knockback: float = effective_knockback()
	for enemy in targets:
		var to_enemy: Vector2 = enemy.global_position - global_position
		if absf(_swing_direction.angle_to(to_enemy)) <= half_arc:
			enemy.take_damage(damage, to_enemy.normalized() * knockback * 6.0)
	_swing_age = 0.0
	Sfx.play("bat_swing", -6.0)
	# 挥砍拖影帧：甩向挥击方向（弧形淡影仍保留作命中范围提示）
	Fx.one_shot(get_tree().current_scene, "weapons/slash", 4,
			global_position + _swing_direction * _swing_range * 0.55,
			22.0, _swing_range / 26.0, _swing_direction.angle())
	queue_redraw()
	return true


func _draw() -> void:
	if _swing_age >= 0.18:
		return
	var alpha: float = 1.0 - _swing_age / 0.18
	var base_angle: float = _swing_direction.angle()
	var half_arc: float = deg_to_rad(_swing_arc) / 2.0
	var points: PackedVector2Array = [Vector2.ZERO]
	for i in 13:
		var angle: float = base_angle - half_arc + deg_to_rad(_swing_arc) * i / 12.0
		points.append(Vector2.from_angle(angle) * _swing_range)
	draw_colored_polygon(points, Color(0.9, 0.9, 0.8, 0.22 * alpha))
