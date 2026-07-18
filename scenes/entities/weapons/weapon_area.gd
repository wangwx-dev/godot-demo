class_name WeaponArea
extends WeaponBase
## 区域副武器（燃烧瓶）：冷却好 且 任一密集簇达标时，自动扔向簇中心（weapon-design）。
## 触发条件 = attack_range 内存在 cluster_radius 半径内 ≥cluster_min 只的敌群。

const FIRE_ZONE_SCENE_PATH: String = "res://scenes/entities/weapons/fire_zone.tscn"

var _fire_zone_scene: PackedScene = preload(FIRE_ZONE_SCENE_PATH)


func effective_fire_radius() -> float:
	return data.geometry_params.get("fire_radius", 100.0) + _level_sum("radius_add")


func effective_fire_duration() -> float:
	return data.geometry_params.get("fire_duration", 4.0) + _level_sum("duration_add")


func _try_attack() -> bool:
	var candidates: Array[EnemyBase] = _enemies_in_range()
	if candidates.size() < int(data.geometry_params.get("cluster_min", 4)):
		return false
	# 找最密簇：以每只敌人为中心数邻居，取邻居最多者
	var cluster_radius: float = data.geometry_params.get("cluster_radius", 120.0)
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
	if best_count < int(data.geometry_params.get("cluster_min", 4)):
		return false
	var zone: FireZone = _fire_zone_scene.instantiate()
	get_tree().current_scene.add_child(zone)
	zone.global_position = best_center.global_position
	zone.setup(effective_fire_radius(), effective_fire_duration(), effective_damage())
	# 落地爆燃 + 烟：燃烧瓶砸中的瞬间反馈
	Fx.one_shot(get_tree().current_scene, "weapons/explosion", 6, zone.global_position, 15.0, 2.5)
	Fx.one_shot(get_tree().current_scene, "weapons/smoke", 6, zone.global_position + Vector2(0, -14), 9.0, 2.0)
	return true
