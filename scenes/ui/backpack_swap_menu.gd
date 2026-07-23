class_name BackpackSwapMenu
extends CanvasLayer
## 满包替换界面（economy-design：满包开箱弹对比列表，丢一件换新或放弃）。
## 简版列表：新物 + 背包 8 件各一行按钮，点背包件=丢它换新，放弃=新物不要。
## 暂停游戏——满包微决策不该在丧尸围里做。

const MODAL_PAUSE: Script = preload("res://scripts/modal_pause.gd")

var _pending: Array[LootData] = []  ## 物资箱可能连出 2 件都满包
var _current: LootData

var _panel: PanelContainer
var _title: Label
var _list_box: VBoxContainer


func _ready() -> void:
	layer = 96
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("backpack_swap_menu")
	_build_ui()


func _exit_tree() -> void:
	MODAL_PAUSE.release(self)


func request(item: LootData) -> void:
	_pending.append(item)
	if not visible:
		_open()


func _open() -> void:
	visible = true
	MODAL_PAUSE.acquire(self)
	_current = _pending.pop_front()
	_refresh()


func _close() -> void:
	if not _pending.is_empty():
		_current = _pending.pop_front()
		_refresh()
		return
	visible = false
	MODAL_PAUSE.release(self)


func _build_ui() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.position = Vector2(-220, -260)
	add_child(_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(440, 0)
	_panel.add_child(vbox)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_title)
	_list_box = VBoxContainer.new()
	_list_box.add_theme_constant_override("separation", 6)
	vbox.add_child(_list_box)


const TIER_COLORS: Array[Color] = [
	Color(0.85, 0.85, 0.82),
	Color(0.35, 0.6, 0.95),
	Color(0.7, 0.4, 0.9),
]


func _refresh() -> void:
	_title.text = "背包满了！\n新物品：%s（%d 金）" % [_current.display_name, _current.value]
	for child in _list_box.get_children():
		child.queue_free()
	for i in RunState.backpack.size():
		var item: LootData = RunState.backpack[i]
		var swap_button: Button = Button.new()
		swap_button.text = "丢弃 %s（%d 金）换入" % [item.display_name, item.value]
		swap_button.add_theme_color_override("font_color", TIER_COLORS[item.tier])
		swap_button.pressed.connect(_on_swap.bind(i))
		_list_box.add_child(swap_button)
	var give_up: Button = Button.new()
	give_up.text = "放弃 %s" % _current.display_name
	give_up.pressed.connect(_close)
	_list_box.add_child(give_up)


func _on_swap(index: int) -> void:
	RunState.backpack[index] = _current
	EventBus.backpack_changed.emit()
	_close()
