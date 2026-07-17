class_name EconomyHud
extends CanvasLayer
## 临时经济 HUD（M4）：HP / 金币 / 背包 8 格。正式 HUD 四簇归 M7（ui-design）。

var _day_label: Label
var _hp_label: Label
var _gold_label: Label
var _backpack_label: Label


func _ready() -> void:
	layer = 80
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.position = Vector2(16, 16)
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)
	_day_label = _make_label(vbox, 17)
	_hp_label = _make_label(vbox, 22)
	_gold_label = _make_label(vbox, 18)
	_backpack_label = _make_label(vbox, 15)
	EventBus.player_health_changed.connect(func(_c: int, _m: int) -> void: _refresh())
	EventBus.gold_changed.connect(func(_t: int) -> void: _refresh())
	EventBus.backpack_changed.connect(_refresh)
	_refresh()


func _make_label(parent: Node, size: int) -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label


func _refresh() -> void:
	_day_label.text = "第 %d/%d 天 · %s图" % [
			mini(RunState.day, RunState.TOTAL_DAYS), RunState.TOTAL_DAYS,
			MapFlow.type_name(RunState.current_map_type)]
	_day_label.add_theme_color_override("font_color", MapFlow.type_color(RunState.current_map_type))
	_hp_label.text = "HP %d / %d" % [RunState.hp, RunState.max_hp]
	_hp_label.add_theme_color_override("font_color",
			Color(0.4, 0.9, 0.4) if RunState.hp > RunState.max_hp / 3 else Color(0.95, 0.3, 0.25))
	_gold_label.text = "金币 %d" % RunState.gold
	_gold_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.2))
	var names: Array[String] = []
	for item in RunState.backpack:
		names.append(item.display_name)
	_backpack_label.text = "背包 %d/%d  %s" % [
			RunState.backpack.size(), RunState.backpack_cap, " ".join(names)]
	_backpack_label.add_theme_color_override("font_color",
			Color(0.95, 0.6, 0.3) if RunState.backpack.size() >= RunState.backpack_cap
			else Color(0.85, 0.85, 0.8))
