class_name WeaponScatter
extends WeaponBase
## 扇形散射（霰弹枪）：多枚弹丸同时射向最近敌人方向的扇形范围内（weapon-design）。
## 近距离多目标全弹命中爆发极高；单体远距离只挨一两发，DPS 明显低于手枪——
## "近战流的远程版"：逼近清场，拉开就疲。

const BULLET_SCENE_PATH: String = "res://scenes/entities/weapons/bullet.tscn"

var _bullet_scene: PackedScene = preload(BULLET_SCENE_PATH)


func effective_pellet_count() -> int:
	return int(data.geometry_params.get("pellet_count", 5) + _level_sum("pellet_add"))


func _try_attack() -> bool:
	var target: EnemyBase = _nearest_enemy()
	if target == null:
		return false
	var base_direction: Vector2 = (target.global_position - global_position).normalized()
	var spread: float = deg_to_rad(data.geometry_params.get("spread_degrees", 40.0))
	var count: int = effective_pellet_count()
	var damage: int = effective_damage()
	var knockback: float = effective_knockback()
	var speed: float = data.geometry_params.get("bullet_speed", 500.0)
	var max_range: float = effective_range()
	for i in count:
		var t: float = (float(i) / float(count - 1) - 0.5) if count > 1 else 0.0
		var direction: Vector2 = Vector2.from_angle(base_direction.angle() + t * spread)
		var bullet: Bullet = _bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = global_position
		bullet.launch(direction, speed, damage, 0, max_range,
				"res://assets/sprites/weapons/bullet_tracer_01.png", knockback)
	Fx.one_shot(get_tree().current_scene, "weapons/shotgun_blast", 6,
			global_position + base_direction * 20.0, 20.0, 1.6, base_direction.angle())
	Sfx.play("pistol_shot", -3.0, 150)
	return true
