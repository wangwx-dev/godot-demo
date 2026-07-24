class_name WeaponCone
extends WeaponBase
## 锥形持续跳伤（链锯）：朝最密方向的扇形内敌人每次冷却到点就跳一次伤（weapon-design）。
## 冷却设得很短当"跳伤间隔"用，营造持续绞杀的观感；没有目标时不消耗冷却（原地怠速），
## 有目标时才真正在打。开动期间（范围内有目标）玩家被迫减速——贴身流的代价。

var _engaged: bool = false
var _cone_direction: Vector2 = Vector2.RIGHT


func effective_cone_degrees() -> float:
	return data.geometry_params.get("cone_degrees", 70.0) + _level_sum("arc_add")


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	var wielder: Player = get_parent() as Player
	if wielder != null:
		wielder.set_speed_modifier("chainsaw",
				data.geometry_params.get("move_mult", 0.65) if _engaged else 1.0)
	queue_redraw()


func _exit_tree() -> void:
	var wielder: Player = get_parent() as Player
	if wielder != null:
		wielder.set_speed_modifier("chainsaw", 1.0)


func _try_attack() -> bool:
	var targets: Array[EnemyBase] = _enemies_in_range()
	_engaged = not targets.is_empty()
	if not _engaged:
		return false
	var direction_sum: Vector2 = Vector2.ZERO
	for enemy in targets:
		direction_sum += (enemy.global_position - global_position).normalized()
	_cone_direction = direction_sum.normalized() if direction_sum.length() > 0.01 			else (targets[0].global_position - global_position).normalized()
	_play_wielder_action(_cone_direction)
	var half_angle: float = deg_to_rad(effective_cone_degrees()) / 2.0
	var damage: int = effective_damage()
	var knockback: float = effective_knockback()
	var hit_any: bool = false
	for enemy in targets:
		var to_enemy: Vector2 = enemy.global_position - global_position
		if absf(_cone_direction.angle_to(to_enemy)) <= half_angle:
			enemy.take_damage(damage, to_enemy.normalized() * knockback)
			hit_any = true
	return hit_any


func _draw() -> void:
	if not _engaged:
		return
	var degrees: float = effective_cone_degrees()
	var half_angle: float = deg_to_rad(degrees) / 2.0
	var base_angle: float = _cone_direction.angle()
	var cone_range: float = effective_range()
	var points: PackedVector2Array = [Vector2.ZERO]
	for i in 9:
		var angle: float = base_angle - half_angle + deg_to_rad(degrees) * i / 8.0
		points.append(Vector2.from_angle(angle) * cone_range)
	draw_colored_polygon(points, Color(0.85, 0.75, 0.2, 0.16))
