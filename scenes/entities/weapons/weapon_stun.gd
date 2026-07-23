class_name WeaponStun
extends WeaponBase
## 闪光弹（眩晕）：冷却好且有密集敌群时扔向簇心，范围内敌人瞬间定身、无伤害
## （weapon-design 控场类）。冷却比手雷短很多——纯控场工具，用得更勤。

func effective_stun_radius() -> float:
	return data.geometry_params.get("stun_radius", 130.0) + _level_sum("radius_add")


func effective_stun_duration() -> float:
	return data.geometry_params.get("stun_duration", 2.0) + _level_sum("duration_add")


func _try_attack() -> bool:
	var candidates: Array[EnemyBase] = _enemies_in_range()
	var cluster_min: int = int(data.geometry_params.get("cluster_min", 3))
	if candidates.size() < cluster_min:
		return false
	var cluster_radius: float = data.geometry_params.get("cluster_radius", 140.0)
	var best_center: EnemyBase = null
	var best_count: int = 0
	for center in candidates:
		var count: int = 0
		for other in candidates:
			if center.global_position.distance_to(other.global_position) <= cluster_radius:
				count += 1
		if count > best_count:
			best_count = count
			best_center = center
	if best_count < cluster_min:
		return false
	var pos: Vector2 = best_center.global_position
	var radius: float = effective_stun_radius()
	var duration: float = effective_stun_duration()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		if pos.distance_to(enemy.global_position) <= radius:
			enemy.apply_control(duration, 0.0)
	var pulse: FlashPulse = FlashPulse.new()
	get_tree().current_scene.add_child(pulse)
	pulse.global_position = pos
	pulse.setup(radius)
	Sfx.play("bloater_explode", -12.0, 200)
	return true
