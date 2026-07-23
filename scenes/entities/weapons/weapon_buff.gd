class_name WeaponBuff
extends WeaponBase
## 肾上腺素（自身增益）：残血时打一针，短时间大幅提速（weapon-design 功能类）。
## 生命值是"胆量资源"（economy-design）——这把副武器把"血少想撤"的直觉反过来，
## 给一次逃生或反打的窗口，不判定目标、不索敌。

func _try_attack() -> bool:
	var threshold: float = data.geometry_params.get("hp_threshold", 0.5)
	if float(RunState.hp) > float(RunState.max_hp) * threshold:
		return false
	var wielder: Player = get_parent() as Player
	if wielder == null:
		return false
	var duration: float = data.geometry_params.get("buff_duration", 3.5) + _level_sum("duration_add")
	var speed_mult: float = 1.0 + data.geometry_params.get("speed_bonus", 0.6)
	wielder.set_speed_modifier("adrenaline", speed_mult)
	Sfx.play("dodge_roll", -4.0)
	get_tree().create_timer(duration).timeout.connect(func() -> void:
			if is_instance_valid(wielder):
				wielder.set_speed_modifier("adrenaline", 1.0))
	return true
