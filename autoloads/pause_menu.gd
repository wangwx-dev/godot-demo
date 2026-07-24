extends CanvasLayer
## 全局暂停菜单（autoload）：监听 pause 动作，在任意关卡弹出。
## 继续/设置/回主菜单/退出。用 modal_pause 令牌暂停，避免和三选一等模态打架
## （三选一开着时不响应暂停键——正在做决策不该被打断）。
## 主菜单场景本身不算关卡：靠场景根节点是否在 "levels" 组判断是否允许暂停。

const MODAL_PAUSE: Script = preload("res://scripts/modal_pause.gd")
const SETTINGS_PANEL: Script = preload("res://scenes/ui/settings_panel.gd")
const MAIN_MENU: String = "res://scenes/ui/main_menu.tscn"

var _root: Control
var _menu_box: VBoxContainer
var _open: bool = false


func _ready() -> void:
	layer = 98
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	# 已有其它模态菜单（三选一/换包/起始武器）时不抢暂停
	if not _open and not get_tree().get_nodes_in_group("_modal_pause_owner").is_empty():
		return
	# 只在关卡里允许暂停（主菜单不需要）
	var current: Node = get_tree().current_scene
	if current == null or not current.is_in_group("levels"):
		return
	get_viewport().set_input_as_handled()
	if _open:
		_resume()
	else:
		_show_menu()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.03, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_menu_box = VBoxContainer.new()
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_menu_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu_box.add_theme_constant_override("separation", 14)
	_root.add_child(_menu_box)
	var title: Label = Label.new()
	title.text = "已暂停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
	_menu_box.add_child(title)
	_menu_box.add_child(_make_button("继续", _resume))
	_menu_box.add_child(_make_button("设置", _on_settings))
	_menu_box.add_child(_make_button("回主菜单", _on_main_menu))
	_menu_box.add_child(_make_button("退出游戏", func() -> void: get_tree().quit()))


func _make_button(text: String, handler: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(240, 44)
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(func() -> void:
			Sfx.play("ui_confirm", -5.0)
			handler.call())
	return btn


func _show_menu() -> void:
	_open = true
	visible = true
	MODAL_PAUSE.acquire(self)


func _resume() -> void:
	_open = false
	visible = false
	MODAL_PAUSE.release(self)


func _on_settings() -> void:
	var panel: SettingsPanel = SETTINGS_PANEL.new()
	_root.add_child(panel)


func _on_main_menu() -> void:
	_resume()
	Sfx.bgm("")
	get_tree().change_scene_to_file.call_deferred(MAIN_MENU)
