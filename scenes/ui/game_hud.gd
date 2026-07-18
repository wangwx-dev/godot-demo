class_name GameHud
extends CanvasLayer
## 正式 HUD 四簇（M7，ui-design 布局）：
## 左上生存簇=血条(带数字)+细经验条+武器格(副武器 CD 扇罩)；右上威胁簇=警戒条（迷你图由 Minimap 承接）；
## 左下=翻滚技能 CD 大图标；右下资源簇=天数/金币/背包。
## 数字极简：只有血量给精确数字；警戒条 填充=死线进度、颜色=Heat 四态、末 10s 大字报数。

const BAR_W: float = 240.0
const ALERT_W: float = 170.0  # 与迷你图同宽对齐（Minimap.MAP_SIZE_PX）
const LOW_HP_RATIO: float = 0.3

## 武器图标：按攻击几何映射（正式 24×24 图标未产，先用素材包内代用图，asset-list 已注）
const GEOMETRY_ICONS: Dictionary = {
	WeaponData.Geometry.ARC: "res://assets/sprites/pickups/icon_knife.png",
	WeaponData.Geometry.LINE: "res://assets/sprites/pickups/icon_pistol.png",
	WeaponData.Geometry.AREA: "res://assets/sprites/pickups/bottle.png",
}

var battle_mode: bool = true  ## 休整/商店 false：隐藏警戒条与武器格（安全感做足）
var director: HeatDirector  ## 战斗图注入（警戒条数据源）
var boss: EnemyBase  ## 总攻图注入：警戒条位置换 Boss 血条（总攻的时钟是 Boss 的命）

var _root: Control
var _countdown_label: Label
var _player: Player
var _xp_flash: float = 0.0
var _icon_cache: Dictionary = {}


func _ready() -> void:
	layer = 85
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.draw.connect(_draw_hud)
	add_child(_root)
	_countdown_label = Label.new()
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color(0.95, 0.2, 0.15))
	_countdown_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_countdown_label.add_theme_constant_override("outline_size", 8)
	_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_countdown_label.position = Vector2(-40, 140)
	_countdown_label.visible = false
	add_child(_countdown_label)
	_player = get_tree().get_first_node_in_group("player") as Player
	EventBus.player_leveled_up.connect(func(_lv: int) -> void: _xp_flash = 0.5)


func _process(delta: float) -> void:
	_xp_flash = maxf(_xp_flash - delta, 0.0)
	_root.queue_redraw()
	# 末 10s 大字报数（执行精度需要的第二处数字，ui-design）
	if battle_mode and director != null and is_instance_valid(director) 			and not director.collapse and director.time_left() <= 10.0:
		_countdown_label.visible = true
		_countdown_label.text = str(ceili(director.time_left()))
	else:
		_countdown_label.visible = false


func _draw_hud() -> void:
	var size: Vector2 = _root.size
	var font: Font = ThemeDB.fallback_font
	_draw_survival_cluster(font)
	_draw_skill_cd(size, font)
	_draw_resource_cluster(size, font)
	if battle_mode:
		if boss != null:
			_draw_boss_bar(size, font)
		else:
			_draw_alert_bar(size)


## ---- 左上：生存簇 ----

func _draw_survival_cluster(font: Font) -> void:
	# 血条（红，带数字——HP 是胆量资源要能算账）
	var hp_ratio: float = float(RunState.hp) / RunState.max_hp
	var low: bool = hp_ratio <= LOW_HP_RATIO
	var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 130.0) if low else 1.0
	_root.draw_rect(Rect2(16, 14, BAR_W, 24), Color(0.08, 0.05, 0.05, 0.85))
	_root.draw_rect(Rect2(16, 14, BAR_W * clampf(hp_ratio, 0.0, 1.0), 24),
			Color(0.85, 0.2, 0.18) * Color(1, 1, 1, pulse))
	_root.draw_rect(Rect2(16, 14, BAR_W, 24), Color(0.75, 0.7, 0.65, 0.9), false, 2.0)
	_root.draw_string(font, Vector2(24, 32), "%d / %d" % [RunState.hp, RunState.max_hp],
			HORIZONTAL_ALIGNMENT_LEFT, BAR_W, 16, Color(1, 1, 1, 0.95))
	# 细经验条（无数字，升级闪光）
	var xp_ratio: float = float(RunState.xp) / maxf(RunState.xp_needed(RunState.level), 1.0)
	_root.draw_rect(Rect2(16, 42, BAR_W, 6), Color(0.06, 0.08, 0.1, 0.85))
	_root.draw_rect(Rect2(16, 42, BAR_W * clampf(xp_ratio, 0.0, 1.0), 6), Color(0.35, 0.8, 0.9))
	if _xp_flash > 0.0:
		_root.draw_rect(Rect2(16, 42, BAR_W, 6), Color(1, 1, 1, _xp_flash * 1.6))
	_root.draw_string(font, Vector2(16 + BAR_W + 8, 50), "Lv %d" % RunState.level,
			HORIZONTAL_ALIGNMENT_LEFT, 80, 12, Color(0.8, 0.85, 0.85))
	# 武器格（主/副，副武器画冷却罩）
	if not battle_mode:
		return
	var slot_x: float = 16.0
	for node in get_tree().get_nodes_in_group("weapons"):
		var weapon: WeaponBase = node as WeaponBase
		if weapon == null or weapon.data == null:
			continue
		var rect: Rect2 = Rect2(slot_x, 56, 34, 34)
		_root.draw_rect(rect, Color(0.1, 0.1, 0.12, 0.85))
		var icon: Texture2D = _icon_for(weapon.data)
		if icon != null:
			var icon_size: Vector2 = icon.get_size()
			var fit: float = minf(26.0 / icon_size.x, 26.0 / icon_size.y)
			_root.draw_texture_rect(icon, Rect2(rect.position + (rect.size - icon_size * fit) / 2.0,
					icon_size * fit), false)
		var cd: float = weapon.cd_fraction()
		if cd > 0.0:
			_root.draw_rect(Rect2(rect.position.x, rect.position.y + rect.size.y * (1.0 - cd),
					rect.size.x, rect.size.y * cd), Color(0.05, 0.05, 0.06, 0.72))
		_root.draw_rect(rect, Color(0.6, 0.58, 0.5, 0.9), false, 2.0)
		slot_x += 40.0


func _icon_for(data: WeaponData) -> Texture2D:
	if not _icon_cache.has(data.geometry):
		_icon_cache[data.geometry] = load(GEOMETRY_ICONS.get(data.geometry, GEOMETRY_ICONS[WeaponData.Geometry.ARC]))
	return _icon_cache[data.geometry]


## ---- 左下：技能 CD（保命键可用性要余光可读） ----

func _draw_skill_cd(size: Vector2, font: Font) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
		return
	var center: Vector2 = Vector2(52, size.y - 64)
	var cd: float = _player.dodge_cd_fraction()
	var ready_now: bool = cd <= 0.0
	_root.draw_circle(center, 26.0, Color(0.08, 0.08, 0.1, 0.85))
	if ready_now:
		_root.draw_circle(center, 22.0, Color(0.4, 0.75, 0.5, 0.95))
	else:
		# 冷却扇形：从满到空顺时针消退
		_root.draw_circle(center, 22.0, Color(0.25, 0.3, 0.28, 0.7))
		var sweep: float = TAU * (1.0 - cd)
		var points: PackedVector2Array = [center]
		for i in 25:
			points.append(center + Vector2.from_angle(-PI / 2.0 + sweep * i / 24.0) * 22.0)
		_root.draw_colored_polygon(points, Color(0.4, 0.75, 0.5, 0.85))
	_root.draw_arc(center, 26.0, 0.0, TAU, 32, Color(0.75, 0.7, 0.65, 0.9), 2.0)
	_root.draw_string(font, center + Vector2(-24, 44), "翻滚·空格",
			HORIZONTAL_ALIGNMENT_CENTER, 48, 11, Color(0.75, 0.78, 0.75))


## ---- 右下：资源簇（三个决策资源一行视线） ----

func _draw_resource_cluster(size: Vector2, font: Font) -> void:
	var right: float = size.x - 16.0
	var y: float = size.y - 64.0
	var day_text: String = "第 %d/%d 天 · %s图" % [
			mini(RunState.day, RunState.TOTAL_DAYS), RunState.TOTAL_DAYS,
			MapFlow.type_name(RunState.current_map_type)]
	_root.draw_string(font, Vector2(right - 320, y), day_text,
			HORIZONTAL_ALIGNMENT_RIGHT, 320, 16, MapFlow.type_color(RunState.current_map_type))
	_root.draw_string(font, Vector2(right - 320, y + 22), "金币 %d" % RunState.gold,
			HORIZONTAL_ALIGNMENT_RIGHT, 320, 16, Color(0.95, 0.8, 0.2))
	var full: bool = RunState.backpack.size() >= RunState.backpack_cap
	_root.draw_string(font, Vector2(right - 320, y + 44),
			"背包 %d/%d%s" % [RunState.backpack.size(), RunState.backpack_cap, "（满）" if full else ""],
			HORIZONTAL_ALIGNMENT_RIGHT, 320, 16,
			Color(0.95, 0.55, 0.25) if full else Color(0.85, 0.85, 0.8))


## ---- 右上：警戒条（填充=死线进度，颜色=Heat 四态，不挂说明文字） ----

func _draw_alert_bar(size: Vector2) -> void:
	if director == null or not is_instance_valid(director):
		return
	var rect: Rect2 = Rect2(size.x - ALERT_W - 16.0, 14.0, ALERT_W, 18.0)
	var progress: float = clampf(director.map_time / HeatDirector.DEADLINE, 0.0, 1.0)
	var heat: float = director.heat
	var msec: float = Time.get_ticks_msec() / 1000.0
	var fill_color: Color
	if director.collapse:
		progress = 1.0
		fill_color = Color(0.55, 0.06, 0.06)
	elif heat < 4.0:
		fill_color = Color(0.35, 0.7, 0.35)
	elif heat < 8.0:
		fill_color = Color(0.85, 0.75, 0.25) * Color(1, 1, 1, 0.8 + 0.2 * sin(msec * 3.0))
	else:
		fill_color = Color(0.9, 0.3, 0.2) * Color(1, 1, 1, 0.7 + 0.3 * sin(msec * 9.0))
	# 末 60s：条身闪烁（心跳音由 PressureHud 出）
	if not director.collapse and director.time_left() <= 60.0:
		fill_color.a *= 0.6 + 0.4 * sin(msec * 12.0)
	_root.draw_rect(rect, Color(0.07, 0.06, 0.06, 0.85))
	_root.draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), fill_color)
	var border: Color = Color(0.75, 0.7, 0.65, 0.9)
	if director.collapse:
		# 崩溃：满条溢出感——边框深红快闪
		border = Color(0.9, 0.12, 0.1, 0.55 + 0.45 * sin(msec * 10.0))
	_root.draw_rect(rect, border, false, 2.0)


## ---- 总攻：Boss 血条（顶部居中，ui-design 总攻 HUD） ----

func _draw_boss_bar(size: Vector2, font: Font) -> void:
	if not is_instance_valid(boss):
		return
	var rect: Rect2 = Rect2(size.x / 2.0 - 210.0, 14.0, 420.0, 20.0)
	var ratio: float = clampf(float(boss.hp) / maxf(boss.data.max_hp, 1), 0.0, 1.0)
	_root.draw_rect(rect, Color(0.07, 0.05, 0.05, 0.88))
	_root.draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)),
			Color(0.72, 0.14, 0.32))
	_root.draw_rect(rect, Color(0.8, 0.6, 0.65, 0.95), false, 2.0)
	_root.draw_string(font, Vector2(rect.position.x, rect.position.y + 15.0),
			boss.data.display_name, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 13, Color(1, 1, 1, 0.92))
