class_name WeaponTrap
extends WeaponBase
## 捕兽夹（定身）：冷却好且有敌人逼近时，在玩家与敌人之间的路径上布设陷阱，
## 首个踩中的敌人被定住数秒（weapon-design 控场类）。精通解锁后一次布 2 个。

func _try_attack() -> bool:
	var target: EnemyBase = _nearest_enemy()
	if target == null:
		return false
	var direction: Vector2 = (target.global_position - global_position).normalized()
	var place_offset: float = data.geometry_params.get("place_offset", 90.0)
	var count: int = int(1 + _level_sum("trap_add"))
	var root_duration: float = data.geometry_params.get("root_duration", 3.0) + _level_sum("duration_add")
	var trigger_damage: int = int(data.geometry_params.get("trigger_damage", 8) + _level_sum("damage_add"))
	var lifetime: float = data.geometry_params.get("trap_lifetime", 12.0)
	for i in count:
		var spread_angle: float = deg_to_rad(20.0) * (float(i) - float(count - 1) / 2.0)
		var trap: BearTrap = BearTrap.new()
		get_tree().current_scene.add_child(trap)
		trap.global_position = global_position + direction.rotated(spread_angle) * place_offset
		trap.setup(root_duration, trigger_damage, lifetime)
	Sfx.play("chest_open", -6.0, 300)
	return true
