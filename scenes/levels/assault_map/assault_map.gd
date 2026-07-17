extends Node2D
## 总攻图占位（M6）：真正的总攻（三词缀超级精英+崩溃级涌潮）归 M8。
## 本版直接按"撤离成功"结算——先把 8 天循环串通，Boss 战后补。

func _ready() -> void:
	EventBus.run_ended.emit(true)
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 99
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.02, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var label: Label = Label.new()
	label.text = "接应点到了（总攻占位，M8 实装 Boss 战）

撤离成功！带出 %d 金 · 用了 %d 天
未兑换的物资作废（%d 件）

按 R 开新一局" % [
			RunState.gold, mini(RunState.day, RunState.TOTAL_DAYS), RunState.backpack.size()]
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	layer.add_child(label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode == KEY_R:
		MapFlow.restart_run(get_tree())
