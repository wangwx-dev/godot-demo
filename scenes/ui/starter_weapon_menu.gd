class_name StarterWeaponMenu
extends CanvasLayer
## 起始主武器二选一（weapon-design：选角色后从 2 把起始主武器选 1）。
## 新局第一张战斗图进场时弹出，暂停游戏；选定写入 RunState.main_weapon 并装备。
## 副武器起始空槽——进图搜刮/商店获取（此处只定主武器）。

const MODAL_PAUSE: Script = preload("res://scripts/modal_pause.gd")

signal chosen(weapon: WeaponData)

var _options: Array = []


func _ready() -> void:
	layer = 97
	process_mode = Node.PROCESS_MODE_ALWAYS
	_options = [
		[preload("res://resources/weapons/weapon_bat.tres"), "近战起步：高伤害弧形挥砍，附带击退天然控距。适合冲进尸群贴脸打。"],
		[preload("res://resources/weapons/weapon_pistol.tres"), "远程起步：直线单发，平衡无短板。安全点杀，但捡经验要多跑。"],
	]
	_build_ui()
	MODAL_PAUSE.acquire(self)


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 20)
	add_child(box)
	var title: Label = Label.new()
	title.text = "选择起始武器"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8))
	box.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	for opt in _options:
		row.add_child(_make_card(opt[0], opt[1]))


func _make_card(weapon: WeaponData, blurb: String) -> Button:
	var card: Button = Button.new()
	card.custom_minimum_size = Vector2(320, 240)
	card.add_theme_font_size_override("font_size", 17)
	card.text = "%s

%s

伤害 %d · 间隔 %.2fs" % [
			weapon.display_name, blurb, weapon.damage, weapon.interval]
	card.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if weapon.icon != null:
		card.icon = weapon.icon
		card.expand_icon = true
		card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.pressed.connect(_on_pick.bind(weapon))
	return card


func _on_pick(weapon: WeaponData) -> void:
	Sfx.play("ui_confirm", -5.0)
	RunState.main_weapon = weapon
	MODAL_PAUSE.release(self)
	chosen.emit(weapon)
	queue_free()


func _exit_tree() -> void:
	MODAL_PAUSE.release(self)
