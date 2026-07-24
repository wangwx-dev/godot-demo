class_name RunSummary
extends CanvasLayer
## 死亡/撤离结算画面（M7，ui-design/economy-design）：
## 死亡=本局收益全部丢失的明账；撤离=带出货币的成绩单。R 重开由关卡侧处理。

var _lines: Array = []
var _title: String = ""
var _title_color: Color = Color.WHITE


## 死亡结算：损失摆在眼前（"是自己贪了"的复盘瞬间）。
static func show_death(parent: Node) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary._title = "信使倒下了"
	summary._title_color = Color(0.9, 0.28, 0.22)
	summary._lines = [
		["撑到了第 %d/%d 天" % [mini(RunState.day, RunState.TOTAL_DAYS), RunState.TOTAL_DAYS], Color(0.85, 0.85, 0.8)],
		["击杀 %d 只丧尸" % RunState.kills, Color(0.85, 0.85, 0.8)],
		["%d 金币与 %d 件物资……全部丢失" % [RunState.gold, RunState.backpack.size()], Color(0.8, 0.5, 0.3)],
		["本局解救 %d 位幸存者（永久解锁保留）" % RunState.rescued_this_run.size(), Color(0.45, 0.75, 0.85)],
		["", Color.WHITE],
		["按 R 再来一局 · M 回主菜单", Color(0.6, 0.75, 0.6)],
	]
	parent.add_child(summary)
	return summary


## 撤离结算：带出的货币是唯一成绩（economy-design 结算规则）。
static func show_extraction(parent: Node) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary._title = "撤离成功！"
	summary._title_color = Color(0.95, 0.8, 0.25)
	summary._lines = [
		["第 %d 天登上救援载具" % mini(RunState.day, RunState.TOTAL_DAYS), Color(0.85, 0.85, 0.8)],
		["击杀 %d 只丧尸" % RunState.kills, Color(0.85, 0.85, 0.8)],
		["带出 %d 金币" % RunState.gold, Color(0.95, 0.8, 0.25)],
		["解救 %d 位幸存者（累计 %d/%d）" % [RunState.rescued_this_run.size(), MetaProgress.unlocked_count(), MetaProgress.ALL_NPCS.size()], Color(0.45, 0.75, 0.85)],
		["（元进度商店在路上——先记在功劳簿上）", Color(0.6, 0.6, 0.6)],
		["", Color.WHITE],
		["按 R 开始新的一局 · M 回主菜单", Color(0.6, 0.75, 0.6)],
	]
	parent.add_child(summary)
	return summary


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("run_summary")  # 无头流转测试的完成探针
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.04, 0.02, 0.02, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var title: Label = Label.new()
	title.text = _title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", _title_color)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 6)
	box.add_child(title)
	for line in _lines:
		var label: Label = Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", line[1])
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		box.add_child(label)
	var btn_row: HBoxContainer = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	box.add_child(btn_row)
	btn_row.add_child(_make_action_button("再来一局", func() -> void: MapFlow.restart_run(get_tree())))
	btn_row.add_child(_make_action_button("回主菜单", func() -> void: MapFlow.to_main_menu(get_tree())))


func _make_action_button(text: String, handler: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(180, 44)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func() -> void:
			Sfx.play("ui_confirm", -5.0)
			handler.call())
	return btn
