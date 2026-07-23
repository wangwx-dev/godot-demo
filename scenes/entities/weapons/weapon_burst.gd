class_name WeaponBurst
extends WeaponBase
## 瞬时范围爆炸（土制手雷）：冷却好且有密集敌群时扔向簇心，范围内瞬间伤害+大击退
## （weapon-design 爆发类）。和燃烧瓶（持续灼烧封锁）互补——手雷清场，燃烧瓶控地。

func effective_blast_radius() -> float:
	return data.geometry_params.get("blast_radius", 110.0) + _level_sum("radius_add")


func _try_attack() -> bool:
	var candidates: Array[EnemyBase] = _enemies_in_range()
	var cluster_min: int = int(data.geometry_params.get("cluster_min", 3))
	if candidates.size() < cluster_min:
		return false
	var cluster_radius: float = data.geometry_params.get("cluster_radius", 130.0)
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
	var blast_pos: Vector2 = best_center.global_position
	var radius: float = effective_blast_radius()
	var damage: int = effective_damage()
	var knockback: float = effective_knockback()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		var offset: Vector2 = enemy.global_position - blast_pos
		if offset.length() <= radius:
			var push: Vector2 = offset.normalized() * knockback if offset.length() > 0.01 else Vector2.ZERO
			enemy.take_damage(damage, push)
	Fx.one_shot(get_tree().current_scene, "weapons/explosion", 6, blast_pos, 15.0, 3.2)
	Fx.one_shot(get_tree().current_scene, "weapons/smoke", 6, blast_pos + Vector2(0, -16), 9.0, 2.6)
	Sfx.play("bloater_explode", -2.0)
	return true
