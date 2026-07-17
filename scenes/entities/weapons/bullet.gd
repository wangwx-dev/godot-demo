class_name Bullet
extends Node2D
## 手枪子弹：直线飞行，命中敌人扣血，贯穿数耗尽或超射程销毁。
## 敌人是圆形碰撞体，用距离判定不走物理层（同屏子弹量小，够用）。

const HIT_RADIUS: float = 16.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 600.0
var _damage: int = 0
var _pierce: int = 0
var _range_left: float = 500.0
var _hit_enemies: Array[EnemyBase] = []


func launch(direction: Vector2, speed: float, damage: int, pierce: int, max_range: float) -> void:
	_direction = direction
	_speed = speed
	_damage = damage
	_pierce = pierce
	_range_left = max_range
	rotation = direction.angle()


func _physics_process(delta: float) -> void:
	var step: float = _speed * delta
	global_position += _direction * step
	_range_left -= step
	if _range_left <= 0.0:
		queue_free()
		return
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE or enemy in _hit_enemies:
			continue
		var hit_range: float = HIT_RADIUS * enemy.data.sprite_scale
		if global_position.distance_to(enemy.global_position) <= hit_range:
			enemy.take_damage(_damage)
			_hit_enemies.append(enemy)
			if _hit_enemies.size() > _pierce:
				queue_free()
				return


func _draw() -> void:
	draw_rect(Rect2(-6, -2, 12, 4), Color(0.95, 0.9, 0.6))
