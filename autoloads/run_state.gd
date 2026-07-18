extends Node
## 局状态唯一容器（tech-design §2/§4）：跨图保留的状态只在这里。
## 图内状态（Heat/死线/迷雾）归关卡场景，换图即弃。局结束整体 reset()。
## HP/XP 也在此：血量跨图持续（治疗花钱是经济链），等级贯穿一局。
## M3 起：强化层数与武器等级记账 + 派生属性聚合（stat_sum 等），
## 玩家/武器每帧读聚合值——.tres 改数、强化叠层都即时生效。

const BACKPACK_SIZE: int = 8
const TOTAL_DAYS: int = 8  ## MVP 预算 8 天，正式版 10（game-design）

## 图型（M6 路线用；ELITE/BATTLE 共用战斗图场景，差异走 is_elite）
enum MapType { BATTLE, ELITE, REST, SHOP, ASSAULT }

const CANDIDATE_COUNT: int = 2  ## 每天候选数，MVP 固定 2（mapgen-design 待定 3）
const SHOP_MIN_OFFERS: int = 2  ## 商店候选每局保底（物资唯一变现渠道）
const ELITE_MIN_OFFERS: int = 1  ## 精英候选每局保底（高风险高收益选项每局至少见 1 次）
const SAFE_DROUGHT_LIMIT: int = 3  ## 连续 3 天无休整/商店候选 → 第 4 天必出（合并计算，MVP）

var day: int = 1
var current_map_type: int = MapType.BATTLE
var next_candidates: Array[int] = []  ## 本图各载具目的地（=下一天候选）
var shop_offers: int = 0
var elite_offers: int = 0
var safe_drought: int = 0
var rest_reroll_count: int = 0  ## 休整图重随全局累计计价（economy-design，与弹窗内重随分开）
var backpack_cap: int = BACKPACK_SIZE
var backpack_expanded: bool = false  ## 扩容每局限 1（休整/商店共享，economy-design）
var gold: int = 0
var backpack: Array[LootData] = []
var upgrades: Dictionary = {}  ## UpgradeData → 已拿层数
var weapon_levels: Dictionary = {}  ## WeaponData → 等级（起始 1，专属卡 +1）
var assault_triggered: bool = false
var kills: int = 0  ## 本局击杀数（结算画面用）

var max_hp: int = 100
var hp: int = 100
var level: int = 1
var xp: int = 0


func reset() -> void:
	day = 1
	current_map_type = MapType.BATTLE
	next_candidates = []
	shop_offers = 0
	elite_offers = 0
	safe_drought = 0
	rest_reroll_count = 0
	backpack_cap = BACKPACK_SIZE
	backpack_expanded = false
	gold = 0
	backpack.clear()
	upgrades.clear()
	weapon_levels.clear()
	assault_triggered = false
	kills = 0
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
	if backpack.size() >= backpack_cap:
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


## ---- 路线（M6，mapgen-design 线性日历式） ----

## 生成下一天候选并缓存（进图时调用一次，载具按此挂目的地牌）。
## 权重 55/15/15/15、精英第 3 天入池、同天去重、安全图保底、
## 商店每局 ≥2、精英每局 ≥1（原 mapgen-design 待定 4，2026-07-18 拍板 1 次）。
func roll_candidates() -> Array[int]:
	if not next_candidates.is_empty():
		return next_candidates
	var next_day: int = day + 1
	if next_day > TOTAL_DAYS:
		# 天数耗尽：所有出口都开往总攻（game-design：第 8 天结束强制总攻）
		next_candidates = [MapType.ASSAULT, MapType.ASSAULT]
		return next_candidates
	var rng: RandomNumberGenerator = RunRng.stream("route")
	var picks: Array[int] = []
	for i in CANDIDATE_COUNT:
		picks.append(_roll_type(rng, next_day))
	# 同天去重优先：全同类型强制替换一个（全是战斗图的"选择"不是选择）
	if picks[0] == picks[1]:
		var replacement: int = picks[0]
		for attempt in 8:
			replacement = _roll_type(rng, next_day)
			if replacement != picks[0]:
				break
		if replacement == picks[0]:
			# 8 次没抽出异类型（≈0.7⁸）：硬替换成休整/商店二选一
			replacement = MapType.REST if rng.randf() < 0.5 else MapType.SHOP
		picks[1] = replacement
	var rounds_left: int = TOTAL_DAYS - day  # 含本轮
	# 精英保底：剩余轮次不够补足 → 强插（写 picks[0]；商店/安全保底写 picks[1]，互不覆盖）
	if next_day >= 3 and MapType.ELITE not in picks and elite_offers < ELITE_MIN_OFFERS 			and rounds_left <= ELITE_MIN_OFFERS - elite_offers:
		picks[0] = MapType.ELITE
	# 商店保底：剩余生成轮次不够补足 2 次 → 强制塞一个商店候选
	if MapType.SHOP not in picks and shop_offers < SHOP_MIN_OFFERS 			and rounds_left <= SHOP_MIN_OFFERS - shop_offers:
		picks[1] = MapType.SHOP
	# 安全图保底：干旱 3 天必出 1 个（休整/商店合并计）
	if safe_drought >= SAFE_DROUGHT_LIMIT 			and MapType.REST not in picks and MapType.SHOP not in picks:
		picks[1] = MapType.REST if rng.randf() < 0.5 else MapType.SHOP
	# 记账
	if MapType.SHOP in picks:
		shop_offers += 1
	if MapType.ELITE in picks:
		elite_offers += 1
	if MapType.REST in picks or MapType.SHOP in picks:
		safe_drought = 0
	else:
		safe_drought += 1
	next_candidates = picks
	return next_candidates


## 单个候选类型：战斗 55/休整 15/商店 15/精英 15（精英第 3 天起入池，此前权重并回战斗）。
func _roll_type(rng: RandomNumberGenerator, next_day: int) -> int:
	var roll: float = rng.randf()
	var elite_open: bool = next_day >= 3
	if roll < 0.15:
		return MapType.REST
	if roll < 0.30:
		return MapType.SHOP
	if roll < 0.45 and elite_open:
		return MapType.ELITE
	return MapType.BATTLE


## 上车出发：定型下一图、清候选、天数 +1（进任何一张图消耗 1 天，总攻不计天）。
func depart(destination: int) -> void:
	current_map_type = destination
	next_candidates = []
	if destination != MapType.ASSAULT:
		advance_day()
