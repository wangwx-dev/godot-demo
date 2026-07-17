extends Node
## 调试工具（tech-design §6）。OS.is_debug_build() 门控，导出版自动失效。
## 快捷键：F1 角标开关 / F2 +100 金 / F3 跳过当天。
## 里程碑推进中临时需要的开关一律进这里，不散落在业务代码里。

## 校准角标数据源：各系统实装后写这几个字段（M1 敌人数、M2 Heat/间隔）。
var enemy_count: int = 0
var heat: float = -1.0
var spawn_interval: float = -1.0

var _label: Label
var _overlay_visible: bool = true


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	layer.add_child(_label)
	add_child(layer)


func _process(_delta: float) -> void:
	_label.visible = _overlay_visible
	if not _overlay_visible:
		return
	var lines: PackedStringArray = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	lines.append("seed %d" % RunRng.run_seed)
	lines.append("day %d/%d  gold %d  bag %d/%d" % [
		RunState.day, RunState.TOTAL_DAYS, RunState.gold,
		RunState.backpack.size(), RunState.BACKPACK_SIZE,
	])
	lines.append("hp %d/%d  lv %d (%d/%d xp)" % [
		RunState.hp, RunState.max_hp, RunState.level,
		RunState.xp, RunState.xp_needed(RunState.level),
	])
	lines.append("enemies %d" % enemy_count)
	if heat >= 0.0:
		lines.append("heat %.1f  interval %.2fs" % [heat, spawn_interval])
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	match key_event.physical_keycode:
		KEY_F1:
			_overlay_visible = not _overlay_visible
		KEY_F2:
			RunState.add_gold(100)
		KEY_F3:
			RunState.advance_day()
