class_name WeaponBase
extends Node2D
## 自动武器基类：冷却计时 + 索敌，子类实现攻击几何（weapon-design 自动索敌规则）。
## 挂在 Player 下。实效数值 = WeaponData 基础值 + 武器等级效果 + 通用强化聚合，
## 每次攻击时现算——强化叠层/等级提升即时生效。

@export var data: WeaponData

var _cooldown: float = 0.0
var _owner_dead: bool = false


func _ready() -> void:
	add_to_group("weapons")  # 三选一"持有才入池"判定读这个组
	EventBus.player_died.connect(func() -> void: _owner_dead = true)


func _physics_process(delta: float) -> void:
	if _owner_dead:
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if _try_attack():
		_cooldown = effective_interval()


## 子类实现。返回 false 表示没有可打目标，不进冷却。
func _try_attack() -> bool:
	return false


## ---- 实效数值（基础 + 等级效果加算，再套通用强化） ----

## 武器等级效果合计：level_effects[0..level-2] 的指定键累加（Lv2 起生效）。
func _level_sum(key: String) -> float:
	var total: float = 0.0
	var unlocked: int = RunState.weapon_level(data) - 1
	for i in mini(unlocked, data.level_effects.size()):
		total += data.level_effects[i].get(key, 0.0)
	return total


func effective_damage() -> int:
	var base: float = data.damage + _level_sum("damage_add")
	return roundi(base * (1.0 + RunState.stat_sum(UpgradeData.Effect.DAMAGE_MULT)))


func effective_interval() -> float:
	var base: float = data.interval + _level_sum("interval_add")
	return maxf(base * RunState.interval_multiplier(), 0.05)


func effective_range() -> float:
	var base: float = data.attack_range + _level_sum("range_add")
	return base * (1.0 + RunState.stat_sum(UpgradeData.Effect.RANGE_MULT))


func effective_knockback() -> float:
	return data.knockback + _level_sum("knockback_add")


## 冷却剩余占比（HUD 武器格冷却罩用）：1=刚打完，0=可用。
func cd_fraction() -> float:
	return clampf(_cooldown / maxf(effective_interval(), 0.01), 0.0, 1.0)


## ---- 索敌 ----

## 索敌半径内最近的活敌人。
func _nearest_enemy() -> EnemyBase:
	var nearest: EnemyBase = null
	var best: float = effective_range()
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
	var radius: float = effective_range()
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: EnemyBase = node as EnemyBase
		if enemy.state == EnemyBase.State.DIE:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			result.append(enemy)
	return result
