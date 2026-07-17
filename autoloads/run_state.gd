extends Node
## 局状态唯一容器（tech-design §2/§4）：跨图保留的状态只在这里。
## 图内状态（Heat/死线/迷雾）归关卡场景，换图即弃。局结束整体 reset()。
## HP/XP 也在此：血量跨图持续（治疗花钱是经济链），等级贯穿一局。
## M3 起：强化层数与武器等级记账 + 派生属性聚合（stat_sum 等），
## 玩家/武器每帧读聚合值——.tres 改数、强化叠层都即时生效。

const BACKPACK_SIZE: int = 8
const TOTAL_DAYS: int = 8  ## MVP 预算 8 天，正式版 10（game-design）

var day: int = 1
var gold: int = 0
var backpack: Array[LootData] = []
var upgrades: Dictionary = {}  ## UpgradeData → 已拿层数
var weapon_levels: Dictionary = {}  ## WeaponData → 等级（起始 1，专属卡 +1）
var assault_triggered: bool = false

var max_hp: int = 100
var hp: int = 100
var level: int = 1
var xp: int = 0


func reset() -> void:
	day = 1
	gold = 0
	backpack.clear()
	upgrades.clear()
	weapon_levels.clear()
	assault_triggered = false
	max_hp = 100
	hp = max_hp
	level = 1
	xp = 0


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)


## 返回是否致死。无敌帧判定在 Player 侧，这里只记账。
func apply_damage(amount: int) -> bool:
	hp = maxi(hp - amount, 0)
	EventBus.player_health_changed.emit(hp, max_hp)
	return hp == 0


func heal(amount: int) -> void:
	hp = mini(hp + amount, max_hp)
	EventBus.player_health_changed.emit(hp, max_hp)


## XP(L) = round(8 × 1.3^(L-1))（upgrade-design 经验曲线）。
func xp_needed(for_level: int) -> int:
	return roundi(8.0 * pow(1.3, for_level - 1))


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed(level):
		xp -= xp_needed(level)
		level += 1
		EventBus.player_leveled_up.emit(level)
	EventBus.player_xp_changed.emit(xp, xp_needed(level))


## ---- 强化记账（M3） ----

func upgrade_stacks(upgrade: UpgradeData) -> int:
	return upgrades.get(upgrade, 0)


func weapon_level(weapon: WeaponData) -> int:
	return weapon_levels.get(weapon, 1)


func apply_upgrade(upgrade: UpgradeData) -> void:
	upgrades[upgrade] = upgrade_stacks(upgrade) + 1
	match upgrade.effect:
		UpgradeData.Effect.MAX_HP_ADD:
			# 强壮：新增部分立即回满（upgrade-design）
			max_hp += int(upgrade.effect_value)
			hp += int(upgrade.effect_value)
			EventBus.player_health_changed.emit(hp, max_hp)
		UpgradeData.Effect.WEAPON_LEVEL:
			weapon_levels[upgrade.weapon_ref] = weapon_level(upgrade.weapon_ref) + 1


## 同类效果的 effect_value × 层数 合计（加算类百分比/数值的分子）。
func stat_sum(effect: UpgradeData.Effect) -> float:
	var total: float = 0.0
	for upgrade in upgrades:
		if upgrade.effect == effect:
			total += upgrade.effect_value * upgrades[upgrade]
	return total


## 敏捷专用：攻击间隔乘算递减 (1-v)^层数，不会归零（upgrade-design）。
func interval_multiplier() -> float:
	var mult: float = 1.0
	for upgrade in upgrades:
		if upgrade.effect == UpgradeData.Effect.ATTACK_INTERVAL_MULT:
			mult *= pow(1.0 - upgrade.effect_value, upgrades[upgrade])
	return mult


## ---- 背包（M4 主场） ----

## 满包返回 false，由上层弹替换界面（economy-design 满包微决策）。
func try_add_loot(item: LootData) -> bool:
	if backpack.size() >= BACKPACK_SIZE:
		return false
	backpack.append(item)
	EventBus.backpack_changed.emit()
	return true


## 商店图进图自动兑换：背包清空、按价值折算货币，返回兑换清单（economy-design v2）。
func redeem_backpack() -> Array[LootData]:
	var redeemed: Array[LootData] = backpack.duplicate()
	var total: int = 0
	for item in redeemed:
		total += item.value
	backpack.clear()
	if total > 0:
		add_gold(total)
	EventBus.backpack_changed.emit()
	return redeemed


func advance_day() -> void:
	day += 1
	EventBus.day_advanced.emit(day)
