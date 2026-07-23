class_name WeaponLine
extends WeaponBase
## 直线弹道（手枪）：自动瞄准最近敌人发射子弹（weapon-design）。

const BULLET_SCENE_PATH: String = "res://scenes/entities/weapons/bullet.tscn"

var _bullet_scene: PackedScene = preload(BULLET_SCENE_PATH)


func _try_attack() -> bool:
	var target: EnemyBase = _nearest_enemy()
	if target == null:
		return false
	var direction: Vector2 = (target.global_position - global_position).normalized()
	var bullet: Bullet = _bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position
	bullet.launch(
		direction,
		data.geometry_params.get("bullet_speed", 600.0),
		effective_damage(),
		int(data.geometry_params.get("pierce", 0) + _level_sum("pierce_add")),
		effective_range(),
		data.geometry_params.get("bullet_texture", "res://assets/sprites/weapons/bullet_tracer_00.png")
	)
	# 枪口焰：单帧短闪，贴在出膛方向
	Fx.single(get_tree().current_scene, "weapons/muzzle_flash.png",
			global_position + direction * 18.0, 0.07, 1.4, direction.angle())
	Sfx.play("pistol_shot", -8.0, 90)
	return true
