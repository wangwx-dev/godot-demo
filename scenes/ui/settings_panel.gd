class_name SettingsPanel
extends Control
## 设置面板（音量三滑条，主菜单/暂停菜单共用）：Master/BGM/SFX 走 GameSettings 持久化。
## 铺满父容器，半透明遮罩挡住背景交互；关闭回调可选（暂停菜单里嵌用）。

const BUSES: Array = [["Master", "总音量"], ["BGM", "音乐"], ["SFX", "音效"]]

var on_closed: Callable = Callable()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # 暂停菜单里打开时树是暂停的
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var title: Label = Label.new()
	title.text = "设置"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	box.add_child(title)

	for entry in BUSES:
		box.add_child(_make_slider_row(entry[0], entry[1]))

	box.add_child(_make_fullscreen_row())

	var close_btn: Button = Button.new()
	close_btn.text = "返回"
	close_btn.custom_minimum_size = Vector2(0, 40)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.pressed.connect(_on_close)
	box.add_child(close_btn)


func _make_slider_row(bus_name: String, label_text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var slider: HSlider = HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameSettings.volume(bus_name)
	slider.custom_minimum_size = Vector2(240, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pct: Label = Label.new()
	pct.custom_minimum_size = Vector2(48, 0)
	pct.add_theme_font_size_override("font_size", 16)
	pct.text = "%d%%" % roundi(slider.value * 100.0)
	slider.value_changed.connect(func(v: float) -> void:
			GameSettings.preview_volume(bus_name, v)
			pct.text = "%d%%" % roundi(v * 100.0))
	slider.drag_ended.connect(func(_changed: bool) -> void:
			GameSettings.set_volume(bus_name, slider.value))
	row.add_child(slider)
	row.add_child(pct)
	return row


func _make_fullscreen_row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label: Label = Label.new()
	label.text = "全屏"
	label.custom_minimum_size = Vector2(80, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)
	var toggle: CheckButton = CheckButton.new()
	toggle.button_pressed = GameSettings.fullscreen()
	toggle.toggled.connect(func(on: bool) -> void:
			Sfx.play("ui_confirm", -8.0)
			GameSettings.set_fullscreen(on))
	row.add_child(toggle)
	return row


func _on_close() -> void:
	Sfx.play("ui_confirm", -6.0)
	if on_closed.is_valid():
		on_closed.call()
	queue_free()
