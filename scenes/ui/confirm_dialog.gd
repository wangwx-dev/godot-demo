class_name ConfirmDialog
extends Control
## 通用确认框（发布层：退出等不可逆操作前确认）。process 常驻（暂停时可用）。

var prompt: String = "确定吗？"
var on_confirm: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var label: Label = Label.new()
	label.text = prompt
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	box.add_child(label)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	row.add_child(_btn("确定", func() -> void:
			if on_confirm.is_valid():
				on_confirm.call()))
	row.add_child(_btn("取消", func() -> void: queue_free()))


func _btn(text: String, handler: Callable) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 42)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func() -> void:
			Sfx.play("ui_confirm", -6.0)
			handler.call())
	return b
