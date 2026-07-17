class_name LevelUpMenu
extends CanvasLayer
## 升级三选一弹窗（upgrade-design：暂停游戏、白70/蓝25 权重、去重、满层不入池、
## 重随 10×2ⁿ⁻¹ 金单次弹窗内翻倍、下次三选一重置回 10、跳过补偿 15 金）。紫卡 MVP 暂缓（mvp-plan M3）。
## 抽卡走 RunRng "upgrade" 流——同种子同选择序列可复现。

const REROLL_BASE: int = 10
const SKIP_REWARD: int = 15
const WHITE_WEIGHT: float = 0.70

const POOL: Array = [
	preload("res://resources/upgrades/upgrade_damage.tres"),
	preload("res://resources/upgrades/upgrade_atk_speed.tres"),
	preload("res://resources/upgrades/upgrade_range.tres"),
	preload("res://resources/upgrades/upgrade_move_speed.tres"),
	preload("res://resources/upgrades/upgrade_max_hp.tres"),
	preload("res://resources/upgrades/upgrade_pickup.tres"),
	preload("res://resources/upgrades/upgrade_skill_cd.tres"),
	preload("res://resources/upgrades/upgrade_loot_speed.tres"),
	preload("res://resources/upgrades/upgrade_bat_mastery.tres"),
	preload("res://resources/upgrades/upgrade_pistol_mastery.tres"),
	preload("res://resources/upgrades/upgrade_molotov_mastery.tres"),
]

const RARITY_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.82),
	Color(0.35, 0.6, 0.95),
	Color(0.7, 0.4, 0.9),
]

var _pending_levels: int = 0
var _offer: Array[UpgradeData] = []
var _reroll_count: int = 0  ## 本次三选一内的重随次数，每次弹窗重置（试玩校准：原设计每局累计）

var _panel: PanelContainer
var _title: Label
var _card_box: HBoxContainer
var _reroll_button: Button
var _skip_button: Button


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停时仍可交互
	visible = false
	_build_ui()
	EventBus.player_leveled_up.connect(_on_leveled_up)


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-430, -220)
	add_child(_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(860, 0)
	_panel.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 30)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_card_box = HBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 16)
	_card_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_card_box)
	var button_box: HBoxContainer = HBoxContainer.new()
	button_box.add_theme_constant_override("separation", 16)
	button_box.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(button_box)
	_reroll_button = Button.new()
	_reroll_button.pressed.connect(_on_reroll)
	button_box.add_child(_reroll_button)
	_skip_button = Button.new()
	_skip_button.text = "跳过（+%d 金）" % SKIP_REWARD
	_skip_button.pressed.connect(_on_skip)
	button_box.add_child(_skip_button)


func _on_leveled_up(_level: int) -> void:
	_pending_levels += 1
	if not visible:
		_open()


func _open() -> void:
	get_tree().paused = true
	visible = true
	_reroll_count = 0
	_roll_offer()
	_refresh()


func _close() -> void:
	_pending_levels -= 1
	if _pending_levels > 0:
		_reroll_count = 0
		_roll_offer()
		_refresh()
		return
	visible = false
	get_tree().paused = false


## 入池条件：未满层；武器专属还要求持有该武器（weapon-design：持有才入池）。
func _eligible_pool() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	var held: Array = get_tree().get_nodes_in_group("weapons").map(
			func(w: WeaponBase) -> WeaponData: return w.data)
	for upgrade: UpgradeData in POOL:
		if RunState.upgrade_stacks(upgrade) >= upgrade.max_stacks:
			continue
		if upgrade.effect == UpgradeData.Effect.WEAPON_LEVEL and upgrade.weapon_ref not in held:
			continue
		result.append(upgrade)
	return result


## 白 70/蓝 25 权重抽 3 张，同次去重；池薄时有多少发多少。
func _roll_offer() -> void:
	var rng: RandomNumberGenerator = RunRng.stream("upgrade")
	var pool: Array[UpgradeData] = _eligible_pool()
	_offer.clear()
	while _offer.size() < 3 and not pool.is_empty():
		var whites: Array[UpgradeData] = pool.filter(
				func(u: UpgradeData) -> bool: return u.rarity == UpgradeData.Rarity.WHITE)
		var blues: Array[UpgradeData] = pool.filter(
				func(u: UpgradeData) -> bool: return u.rarity == UpgradeData.Rarity.BLUE)
		var bucket: Array[UpgradeData]
		if blues.is_empty() or (not whites.is_empty() and rng.randf() < WHITE_WEIGHT):
			bucket = whites
		else:
			bucket = blues
		var pick: UpgradeData = bucket[rng.randi_range(0, bucket.size() - 1)]
		_offer.append(pick)
		pool.erase(pick)


func _refresh() -> void:
	_title.text = "升级！ Lv %d" % RunState.level
	for child in _card_box.get_children():
		child.queue_free()
	for upgrade in _offer:
		_card_box.add_child(_make_card(upgrade))
	var cost: int = reroll_cost()
	_reroll_button.text = "重随（%d 金）" % cost
	_reroll_button.disabled = RunState.gold < cost


func reroll_cost() -> int:
	return REROLL_BASE * int(pow(2.0, _reroll_count))


func _make_card(upgrade: UpgradeData) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(260, 190)
	card.add_theme_color_override("font_color", RARITY_COLORS[upgrade.rarity])
	var name_text: String = upgrade.display_name
	var desc_text: String = upgrade.description
	var stacks: int = RunState.upgrade_stacks(upgrade)
	if upgrade.effect == UpgradeData.Effect.WEAPON_LEVEL:
		# 武器专属卡显示下一级的名称与描述
		name_text = "%s：%s" % [upgrade.weapon_ref.display_name, upgrade.level_names[stacks]]
		desc_text = upgrade.level_descs[stacks]
	# 层数点（ui-design：卡面层数标记）
	var dots: String = ""
	if upgrade.max_stacks > 1:
		dots = "\n" + "●".repeat(stacks) + "○".repeat(upgrade.max_stacks - stacks)
	card.text = "%s\n\n%s%s" % [name_text, desc_text, dots]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.pressed.connect(_on_card_picked.bind(upgrade))
	return card


func _on_card_picked(upgrade: UpgradeData) -> void:
	RunState.apply_upgrade(upgrade)
	_close()


func _on_reroll() -> void:
	var cost: int = reroll_cost()
	if RunState.gold < cost:
		return
	RunState.add_gold(-cost)
	_reroll_count += 1
	_roll_offer()
	_refresh()


func _on_skip() -> void:
	RunState.add_gold(SKIP_REWARD)
	_close()
