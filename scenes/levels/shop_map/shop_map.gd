extends Node2D
## 商店图（M7 正式版，economy-design 商店节 / ui-design 商店图 UI）：
## 进图自动兑换（逐行播报折算——变现的爽感要给足仪式）+ 2 格货架（绷带 10 金 / 扩容 25 金共享限购）。
## 无迷雾无刷怪；出口载具即选路。

const MAP_W: float = 1280.0
const MAP_H: float = 720.0
const STATION_RADIUS: float = 60.0
const SERVICE_HOLD: float = 0.6
const BANDAGE_COST: int = 10
const BANDAGE_HEAL: int = 15
const EXPAND_COST: int = 25
const BROADCAST_INTERVAL: float = 0.45

var _hold: float = 0.0
var _active_station: int = -1
var _broadcast_lines: Array[Array] = []  # [文本, 颜色]
var _broadcast_shown: int = 0
var _broadcast_timer: float = 0.0
var _broadcast_box: VBoxContainer

@onready var player: Player = $Player


func _ready() -> void:
	add_to_group("levels")  # 暂停菜单据此判断当前是否在关卡内
	player.set_camera_limits(Rect2(0, 0, MAP_W, MAP_H))
	player.position = Vector2(180, MAP_H / 2.0)
	_build_walls()
	var hud: GameHud = GameHud.new()
	hud.battle_mode = false
	add_child(hud)
	Sfx.bgm("safe")
	_setup_broadcast()
	_place_vehicles()
	queue_redraw()


## ---- 兑换播报（逐行滚动折算） ----

func _setup_broadcast() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 82
	_broadcast_box = VBoxContainer.new()
	_broadcast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_broadcast_box.position = Vector2(-220, 90)
	_broadcast_box.custom_minimum_size = Vector2(440, 0)
	_broadcast_box.add_theme_constant_override("separation", 4)
	layer.add_child(_broadcast_box)
	add_child(layer)
	var redeemed: Array[LootData] = RunState.redeem_backpack()
	if redeemed.is_empty():
		_broadcast_lines.append(["背包是空的——柜台后的人耸了耸肩", Color(0.7, 0.7, 0.7)])
		return
	# 同名合并计数（罐头 ×3 → 30 金）
	var tally: Dictionary = {}
	for item in redeemed:
		if not tally.has(item.display_name):
			tally[item.display_name] = [0, 0]
		tally[item.display_name][0] += 1
		tally[item.display_name][1] += item.value
	var total: int = 0
	for item_name in tally:
		var count: int = tally[item_name][0]
		var value: int = tally[item_name][1]
		total += value
		_broadcast_lines.append(["%s ×%d → +%d 金" % [item_name, count, value], Color(0.85, 0.85, 0.8)])
	_broadcast_lines.append(["—— 合计 +%d 金 ——" % total, Color(0.95, 0.8, 0.2)])


func _advance_broadcast(delta: float) -> void:
	if _broadcast_shown >= _broadcast_lines.size():
		return
	_broadcast_timer -= delta
	if _broadcast_timer > 0.0:
		return
	_broadcast_timer = BROADCAST_INTERVAL
	var line: Array = _broadcast_lines[_broadcast_shown]
	_broadcast_shown += 1
	var label: Label = Label.new()
	label.text = line[0]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20 if _broadcast_shown == _broadcast_lines.size() else 17)
	label.add_theme_color_override("font_color", line[1])
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.modulate.a = 0.0
	_broadcast_box.add_child(label)
	create_tween().tween_property(label, "modulate:a", 1.0, 0.25)
	Sfx.play("shop_exchange_tick", -8.0, 100)


## ---- 货架（休整图站点同款交互：站进圈按住 E） ----

## 货架表：[位置, 名称, 说明文案, 动作]
func _stations() -> Array:
	return [
		[Vector2(520, 300), "绷带",
				"%d 金回 %d 血" % [BANDAGE_COST, BANDAGE_HEAL], _buy_bandage],
		[Vector2(760, 300), "背包扩容",
				"已购" if RunState.backpack_expanded else "%d 金 +2 格（限 1 次）" % EXPAND_COST, _buy_expand],
	]


func _physics_process(delta: float) -> void:
	_advance_broadcast(delta)
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
		if _hold >= SERVICE_HOLD:
			_hold = 0.0
			(stations[near][3] as Callable).call()
	else:
		_hold = 0.0
		_active_station = -1
	queue_redraw()


func _buy_bandage() -> void:
	if RunState.gold < BANDAGE_COST or RunState.hp >= RunState.max_hp:
		return
	RunState.add_gold(-BANDAGE_COST)
	RunState.heal(BANDAGE_HEAL)


func _buy_expand() -> void:
	if RunState.backpack_expanded or RunState.gold < EXPAND_COST:
		return
	RunState.add_gold(-EXPAND_COST)
	RunState.backpack_cap += 2
	RunState.backpack_expanded = true
	EventBus.backpack_changed.emit()


func _place_vehicles() -> void:
	var candidates: Array[int] = RunState.roll_candidates()
	var spots: Array = [Vector2(1120, 240), Vector2(1120, 480)]
	for i in candidates.size():
		var vehicle: Vehicle = Vehicle.new()
		vehicle.destination = candidates[i]
		vehicle.discovered = true
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
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.15, 0.17, 0.2))
	draw_rect(Rect2(0, 0, MAP_W, MAP_H), Color(0.4, 0.6, 0.85), false, 6.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(MAP_W / 2.0 - 100, MAP_H - 28),
			"以物易物点（商店）", HORIZONTAL_ALIGNMENT_CENTER, 200, 26, Color(0.6, 0.75, 0.95))
	# 货架站点（同休整图服务空间化）
	var stations: Array = _stations()
	for i in stations.size():
		var pos: Vector2 = stations[i][0]
		var active: bool = i == _active_station and _hold > 0.0
		draw_circle(pos, STATION_RADIUS, Color(0.4, 0.6, 0.85, 0.2 if active else 0.1))
		draw_arc(pos, STATION_RADIUS, 0.0, TAU, 40, Color(0.4, 0.65, 0.9, 0.65), 2.0)
		if active:
			draw_arc(pos, STATION_RADIUS - 6.0, -PI / 2.0,
					-PI / 2.0 + TAU * (_hold / SERVICE_HOLD), 32, Color(0.95, 0.9, 0.6), 4.0)
		draw_rect(Rect2(pos + Vector2(-14, -16), Vector2(28, 22)), Color(0.5, 0.4, 0.3))
		draw_rect(Rect2(pos + Vector2(-14, -16), Vector2(28, 22)), Color(0.3, 0.22, 0.15), false, 2.0)
		draw_string(font, pos + Vector2(-60, 34), stations[i][1],
				HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(0.95, 0.9, 0.75))
		draw_string(font, pos + Vector2(-90, 52), stations[i][2],
				HORIZONTAL_ALIGNMENT_CENTER, 180, 12, Color(0.75, 0.78, 0.8))
		draw_string(font, pos + Vector2(-60, 68), "按住 E 购买",
				HORIZONTAL_ALIGNMENT_CENTER, 120, 11, Color(0.55, 0.6, 0.65))
