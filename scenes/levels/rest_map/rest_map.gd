extends Node2D
## 休整图（M6，固定小图 1280×720）：无迷雾无刷怪的安全屋（game-design 图型表）。
## 服务（economy-design 消费端）：治疗 20 金回 30 血（可重复）、
## 重整构筑 10×2ⁿ⁻¹ 金开一次三选一（全局累计计价，MVP 对"三选一重随"服务的落地解释）、
## 背包扩容 +2 格 25 金（每局限 1，与商店共享）、信号弹免费提前发起总攻（按住 1.5s 防误触）。

const MAP_W: float = 1280.0
const MAP_H: float = 720.0
const STATION_RADIUS: float = 60.0
const HEAL_COST: int = 20
const HEAL_AMOUNT: int = 30
const EXPAND_COST: int = 25
const FLARE_HOLD: float = 1.5
const SERVICE_HOLD: float = 0.6

var _menu: LevelUpMenu
var _hold: float = 0.0
var _active_station: int = -1

@onready var player: Player = $Player


func _ready() -> void:
	add_to_group("levels")  # 暂停菜单据此判断当前是否在关卡内
	player.set_camera_limits(Rect2(0, 0, MAP_W, MAP_H))
	player.position = Vector2(180, MAP_H / 2.0)
	_build_walls()
	_menu = LevelUpMenu.new()
	add_child(_menu)
	var hud: GameHud = GameHud.new()
	hud.battle_mode = false
	add_child(hud)
	Sfx.bgm("safe")
	_place_vehicles()
	queue_redraw()


## 站点表：[位置, 名称, 说明, 按住时长, 动作]
func _stations() -> Array:
	var medic: bool = MetaProgress.is_unlocked(MetaProgress.MEDIC)
	var heal_desc: String = "20 金回 40 血（医师）" if medic else "20 金回 30 血"
	var result: Array = [
		[Vector2(480, 220), "医疗站" if medic else "治疗", heal_desc, SERVICE_HOLD, _buy_heal],
		[Vector2(700, 220), "重整构筑", "%d 金开一次三选一" % _reroll_cost(), SERVICE_HOLD, _buy_reroll],
		[Vector2(480, 500), "背包扩容", "已购" if RunState.backpack_expanded else "25 金 +2 格（限 1 次）", SERVICE_HOLD, _buy_expand],
		[Vector2(700, 500), "信号弹", "免费·提前发起总攻！", FLARE_HOLD, _fire_flare],
	]
	# 军械师解锁：休整图多一个武器补给站（30 金随机换一把主/副武器）
	if MetaProgress.is_unlocked(MetaProgress.ARMORER):
		result.append([Vector2(590, 360), "军械补给", "30 金·随机武器", SERVICE_HOLD, _buy_weapon])
	return result


func _reroll_cost() -> int:
	return 10 * int(pow(2.0, RunState.rest_reroll_count))


func _physics_process(delta: float) -> void:
	var stations: Array = _stations()
	var near: int = -1
	for i in stations.size():
		if player.position.distance_to(stations[i][0]) <= STATION_RADIUS:
			near = i
			break
	if near != -1 and Input.is_action_pressed("interact"):
		if near != _active_station:
			_hold = 0.0
			_active_station = near
		_hold += delta
		if _hold >= stations[near][3]:
			_hold = 0.0
			(stations[near][4] as Callable).call()
	else:
		_hold = 0.0
		_active_station = -1
	queue_redraw()


func _buy_heal() -> void:
	if RunState.gold < HEAL_COST or RunState.hp >= RunState.max_hp:
		return
	RunState.add_gold(-HEAL_COST)
	var amount: int = HEAL_AMOUNT + 10 if MetaProgress.is_unlocked(MetaProgress.MEDIC) else HEAL_AMOUNT
	RunState.heal(amount)


func _buy_reroll() -> void:
	var cost: int = _reroll_cost()
	if RunState.gold < cost:
		return
	RunState.add_gold(-cost)
	RunState.rest_reroll_count += 1
	_menu.open_bonus(LevelUpMenu.Session.BONUS)


func _buy_expand() -> void:
	if RunState.backpack_expanded or RunState.gold < EXPAND_COST:
		return
	RunState.add_gold(-EXPAND_COST)
	RunState.backpack_cap += 2
	RunState.backpack_expanded = true
	EventBus.backpack_changed.emit()


## 军械补给（军械师解锁）：30 金随机换一把武器（走 loot 流）。
func _buy_weapon() -> void:
	const COST: int = 30
	if RunState.gold < COST:
		return
	RunState.add_gold(-COST)
	var rng: RandomNumberGenerator = RunRng.stream("loot")
	var pool: Array = ResourcePoint.WEAPON_POOL
	var weapon: WeaponData = pool[rng.randi_range(0, pool.size() - 1)]
	# 直接写入 RunState 装备槽（下一张战斗图复装时生效）
	if weapon.slot == WeaponData.Slot.MAIN:
		RunState.main_weapon = weapon
	else:
		RunState.sub_weapon = weapon
	print("[RestMap] 军械补给换得: %s" % weapon.display_name)


func _fire_flare() -> void:
	set_physics_process(false)
	MapFlow.travel(get_tree(), RunState.MapType.ASSAULT)


func _place_vehicles() -> void:
	var candidates: Array[int] = RunState.roll_candidates()
	var spots: Array = [Vector2(1120, 240), Vector2(1120, 480)]
	for i in candidates.size():
		var vehicle: Vehicle = Vehicle.new()
		vehicle.destination = candidates[i]
		vehicle.discovered = true  # 无迷雾图直接可见
		vehicle.position = spots[i % spots.size()]
		add_child(vehicle)


func _build_walls() -> void:
	var walls: StaticBody2D = StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var specs: Array = [
		[Vector2(MAP_W / 2.0, -30), Vector2(MAP_W + 120, 60)],
		[Vector2(MAP_W / 2.0, MAP_H + 30), Vector2(MAP_W + 120, 60)],
		[Vector2(-30, MAP_H / 2.0), Vector2(60, MAP_H + 120)],
		[Vector2(MAP_W + 30, MAP_H / 2.0), Vector2(60, MAP_H + 120)],
	]
	for spec in specs:
		var shape_node: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = spec[1]
		shape_node.shape = shape
		shape_node.position = spec[0]
		walls.add_child(shape_node)
	add_child(walls)


func _draw() -> void:
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.16, 0.19, 0.16))
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.35, 0.6, 0.4), false, 6.0)
	draw_string(ThemeDB.fallback_font, Vector2(MAP_W / 2.0 - 100, 60),
			"安全屋（休整）", HORIZONTAL_ALIGNMENT_CENTER, 200, 26, Color(0.6, 0.85, 0.65))
	var stations: Array = _stations()
	for i in stations.size():
		var pos: Vector2 = stations[i][0]
		draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 56)), Color(0.22, 0.28, 0.24))
		draw_rect(Rect2(pos - Vector2(28, 28), Vector2(56, 56)), Color(0.5, 0.75, 0.55), false, 2.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-70, -40),
				stations[i][1], HORIZONTAL_ALIGNMENT_CENTER, 140, 16, Color(0.9, 0.95, 0.9))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-90, 52),
				stations[i][2], HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color(0.75, 0.8, 0.75))
		if player != null and player.position.distance_to(pos) <= STATION_RADIUS:
			draw_string(ThemeDB.fallback_font, pos + Vector2(-70, 72),
					"按住 E", HORIZONTAL_ALIGNMENT_CENTER, 140, 12, Color(0.95, 0.9, 0.6))
			if _active_station == i and _hold > 0.0:
				draw_arc(pos, 40.0, -PI / 2.0,
						-PI / 2.0 + TAU * (_hold / (stations[i][3] as float)), 20, Color(0.95, 0.95, 0.9), 3.0)
