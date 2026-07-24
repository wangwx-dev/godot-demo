extends Control
## 主菜单（发布入口）：开始新局 / 设置 / 退出。项目 main_scene 指向这里。
## 开始 = 新种子 + 状态清零 + 进第 1 天战斗图（起始武器选择在图内弹）。

const BATTLE_SCENE: String = "res://scenes/levels/test_arena/test_arena.tscn"
const SETTINGS_PANEL: Script = preload("res://scenes/ui/settings_panel.gd")
const VERSION: String = "v0.9 抢先体验"

var _settings_panel: Control


func _ready() -> void:
	Sfx.bgm("safe")
	_build_ui()


func _build_ui() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center: VBoxContainer = VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.grow_horizontal = Control.GROW_DIRECTION_BOTH
	center.grow_vertical = Control.GROW_DIRECTION_BOTH
	center.add_theme_constant_override("separation", 14)
	add_child(center)

	var title: Label = Label.new()
	title.text = "末日搜打撤"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.3, 0.25))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 8)
	center.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "8 天求生 · 搜刮 · 突围"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	center.add_child(subtitle)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	center.add_child(spacer)

	center.add_child(_make_button("开始逃亡", _on_start))
	center.add_child(_make_button("设置", _on_settings))
	center.add_child(_make_button("退出", _on_quit))

	var version: Label = Label.new()
	version.text = VERSION
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN
	version.position = Vector2(-140, -32)
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	add_child(version)


func _make_button(text: String, handler: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 48)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void:
			Sfx.play("ui_confirm", -5.0)
			handler.call())
	return btn


func _on_start() -> void:
	RunRng.new_run()
	RunState.reset()
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(BATTLE_SCENE)


func _on_settings() -> void:
	if _settings_panel != null and is_instance_valid(_settings_panel):
		return
	_settings_panel = SETTINGS_PANEL.new()
	add_child(_settings_panel)


func _on_quit() -> void:
	get_tree().quit()
