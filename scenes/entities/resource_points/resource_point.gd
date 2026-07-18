class_name ResourcePoint
extends Node2D
## 资源点（economy-design 资源点数值表）：物资箱 3s / 货币箱 2.5s / 经验矿 2s / 武器箱 4s。
## 驻留 = 玩家站进交互半径自动读条（操作只有移动，不加按键）；离开保留进度（MVP 案）。
## 驻留期间 HeatDirector 刷入间隔减半（loot_pressure，导演每帧扫 "resource_points" 组）。
## "快手"强化（LOOT_TIME_MULT）作用于全部驻留时长。

signal looted_weapon(weapon: WeaponData)

enum Kind { SUPPLY, GOLD, XP_MINE, WEAPON }

const DWELL_TIMES: Array[float] = [3.0, 2.5, 2.0, 4.0]
const INTERACT_RADIUS: float = 60.0
const XP_MINE_AMOUNT: int = 30
const GOLD_MIN: int = 15
const GOLD_MAX: int = 25
## 价值物三档权重（economy-design：白60/蓝30/紫10）
const LOOT_TABLE: Array = [
	[preload("res://resources/loot/loot_canned_food.tres"), 0.60],
	[preload("res://resources/loot/loot_medicine.tres"), 0.30],
	[preload("res://resources/loot/loot_gold_bar.tres"), 0.10],
]
const WEAPON_POOL: Array = [
	preload("res://resources/weapons/weapon_bat.tres"),
	preload("res://resources/weapons/weapon_pistol.tres"),
	preload("res://resources/weapons/weapon_molotov.tres"),
]
const KIND_NAMES: Array[String] = ["物资箱", "货币箱", "经验矿", "武器箱"]
const KIND_COLORS: Array[Color] = [
	Color(0.75, 0.6, 0.35),
	Color(0.95, 0.8, 0.2),
	Color(0.4, 0.85, 0.95),
	Color(0.6, 0.45, 0.8),
]

@export var kind: Kind = Kind.SUPPLY

var progress: float = 0.0
var done: bool = false
var discovered: bool = false  ## 迷雾光圈扫到后置位（FogOverlay），迷你图渲染依据

var _dwelling: bool = false
var _player: Player
var _box: Sprite2D


func _ready() -> void:
	add_to_group("resource_points")
	_player = get_tree().get_first_node_in_group("player") as Player
	# 箱体贴图（按类型染色区分），开完换破损箱
	_box = Sprite2D.new()
	_box.texture = load("res://assets/sprites/pickups/itembox.png")
	_box.modulate = Color.WHITE.lerp(KIND_COLORS[kind], 0.45)
	add_child(_box)


func is_dwelling() -> bool:
	return _dwelling and not done


## 快手强化后的实效驻留时长。
func effective_dwell_time() -> float:
	var reduction: float = RunState.stat_sum(UpgradeData.Effect.LOOT_TIME_MULT)
	return DWELL_TIMES[kind] * maxf(1.0 - reduction, 0.25)


func _physics_process(delta: float) -> void:
	if done:
		return
	var was_dwelling: bool = _dwelling
	_dwelling = (
		_player != null and is_instance_valid(_player)
		and global_position.distance_to(_player.global_position) <= INTERACT_RADIUS
	)
	if _dwelling:
		progress += delta
		Sfx.play("chest_loop", -12.0, 380)
		if progress >= effective_dwell_time():
			_produce()
	if _dwelling != was_dwelling or _dwelling:
		queue_redraw()


func _produce() -> void:
	done = true
	_dwelling = false
	_box.texture = load("res://assets/sprites/pickups/itembox_broken.png")
	Sfx.play("chest_open", -6.0)
	var rng: RandomNumberGenerator = RunRng.stream("loot")
	match kind:
		Kind.SUPPLY:
			# 1~2 件按权重表随机（economy-design）
			for i in rng.randi_range(1, 2):
				var roll: float = rng.randf()
				var acc: float = 0.0
				var item: LootData = LOOT_TABLE[0][0]
				for entry in LOOT_TABLE:
					acc += entry[1]
					if roll < acc:
						item = entry[0]
						break
				if not RunState.try_add_loot(item):
					# 满包：交给替换界面做微决策（economy-design）
					var menu: BackpackSwapMenu = get_tree().get_first_node_in_group("backpack_swap_menu")
					if menu != null:
						menu.request(item)
		Kind.GOLD:
			RunState.add_gold(rng.randi_range(GOLD_MIN, GOLD_MAX))
		Kind.XP_MINE:
			RunState.add_xp(XP_MINE_AMOUNT)
		Kind.WEAPON:
			looted_weapon.emit(WEAPON_POOL[rng.randi_range(0, WEAPON_POOL.size() - 1)])
	# 挖完消失（经验矿设定，其余箱开完同样移除——占位表现）
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)


func _draw() -> void:
	var color: Color = KIND_COLORS[kind]
	# 交互半径（淡圈，驻留中变亮）
	var ring: Color = color
	ring.a = 0.5 if _dwelling else 0.15
	draw_arc(Vector2.ZERO, INTERACT_RADIUS, 0.0, TAU, 40, ring, 2.0)
	# 读条弧（保留进度可见）
	if progress > 0.0 and not done:
		var ratio: float = clampf(progress / effective_dwell_time(), 0.0, 1.0)
		draw_arc(Vector2.ZERO, 20.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 24, Color(1, 1, 1, 0.9), 4.0)
	# 名字（占位字，正式素材归 asset-list）
	draw_string(ThemeDB.fallback_font, Vector2(-24, -24), KIND_NAMES[kind],
			HORIZONTAL_ALIGNMENT_CENTER, 48.0, 12, Color(0.9, 0.9, 0.85))
