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
var _shot_frame: int = 0  # --shot=N：第 N 帧存主视口截图后退出（无人值守 QA）
var _frame_count: int = 0


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_unhandled_input(false)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_frame = int(arg.trim_prefix("--shot="))
		elif arg.begins_with("--route-audit="):
			# 路线审计：批量种子模拟整局候选流，验证保底与同种子复现（无头 QA）
			_route_audit.call_deferred(int(arg.trim_prefix("--route-audit=")))
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 100
	_label = Label.new()
	_label.position = Vector2(8, 8)
	_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	layer.add_child(_label)
	add_child(layer)


func _process(_delta: float) -> void:
	_frame_count += 1
	if _shot_frame > 0 and _frame_count >= _shot_frame:
		_shot_frame = 0
		var img: Image = get_viewport().get_texture().get_image()
		var out_path: String = "res://tools/previews/ingame_view.png"
		img.save_png(ProjectSettings.globalize_path(out_path))
		print("[Debug] 截图 -> ", out_path)
		get_tree().quit()
	_label.visible = _overlay_visible
	if not _overlay_visible:
		return
	var lines: PackedStringArray = []
	lines.append("FPS %d" % Engine.get_frames_per_second())
	lines.append("seed %d" % RunRng.run_seed)
	lines.append("day %d/%d  gold %d  bag %d/%d" % [
		RunState.day, RunState.TOTAL_DAYS, RunState.gold,
		RunState.backpack.size(), RunState.backpack_cap,
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


## ---- 路线审计（--route-audit=N）----

## N 个种子各模拟一整局候选流：统计无精英候选的局数、同种子复现失败数。
func _route_audit(runs: int) -> void:
	var no_elite: int = 0
	var no_shop_min: int = 0
	var repro_fail: int = 0
	for i in runs:
		var audit_seed: int = 100003 + i * 7919
		var seq_a: Array = _simulate_route(audit_seed)
		if seq_a != _simulate_route(audit_seed):
			repro_fail += 1
		var elite_hits: int = 0
		var shop_hits: int = 0
		for picks in seq_a:
			if RunState.MapType.ELITE in picks:
				elite_hits += 1
			if RunState.MapType.SHOP in picks:
				shop_hits += 1
		if elite_hits == 0:
			no_elite += 1
		if shop_hits < RunState.SHOP_MIN_OFFERS:
			no_shop_min += 1
	print("[route-audit] 局数=%d  无精英候选局=%d  商店不足2局=%d  复现失败=%d" % [
			runs, no_elite, no_shop_min, repro_fail])
	get_tree().quit(0)


## 单局模拟：滚完 8 天候选直到总攻，出口交替选择覆盖两条访问路径。
func _simulate_route(sim_seed: int) -> Array:
	RunRng.start_run(sim_seed)
	RunState.reset()
	var seq: Array = []
	while true:
		var picks: Array[int] = RunState.roll_candidates()
		seq.append(picks.duplicate())
		if RunState.MapType.ASSAULT in picks:
			break
		RunState.depart(picks[RunState.day % 2])
	return seq
