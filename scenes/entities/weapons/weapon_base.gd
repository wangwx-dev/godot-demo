class_name WeaponBase
extends Node2D
## 自动武器基类：冷却计时 + 索敌，子类实现攻击几何（weapon-design 自动索敌规则）。
## 挂在 Player 下；数值全走 WeaponData。

@export var data: WeaponData

var _cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if _try_attack():
		_cooldown = data.interval


## 子类实现。返回 false 表示没有可打目标，不进冷却。
func _try_attack() -> bool:
	return false


## 索敌半径内最近的活敌人。
func _nearest_enemy() -> EnemyBase:
	var nearest: EnemyBase = null
	var best: float = data.attack_range
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance <= best:
			best = distance
			nearest = enemy
	return nearest


## 索敌半径内的全部活敌人。
func _enemies_in_range() -> Array[EnemyBase]:
	var result: Array[EnemyBase] = []
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		if global_position.distance_to(enemy.global_position) <= data.attack_range:
			result.append(enemy)
	return result
