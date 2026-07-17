extends Node
## 局状态唯一容器（tech-design §2/§4）：跨图保留的状态只在这里。
## 图内状态（Heat/死线/迷雾）归关卡场景，换图即弃。局结束整体 reset()。

const BACKPACK_SIZE: int = 8
const TOTAL_DAYS: int = 8  ## MVP 预算 8 天，正式版 10（game-design）

var day: int = 1
var gold: int = 0
var backpack: Array[LootData] = []
var upgrades: Dictionary = {}  ## UpgradeData → 已拿层数
var reroll_count: int = 0  ## 重随全局累计计价 10×2ⁿ⁻¹（upgrade-design）
var assault_triggered: bool = false


func reset() -> void:
	day = 1
	gold = 0
	backpack.clear()
	upgrades.clear()
	reroll_count = 0
	assault_triggered = false


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)


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
